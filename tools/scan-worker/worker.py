#!/usr/bin/env python3
"""The Odyssey render worker: turns walkthrough videos into 3D spaces.

Run it on a Mac with Apple silicon and leave it running:

    python3 tools/scan-worker/worker.py

It asks Convex for the next waiting scan, downloads the video, builds the 3D
model, uploads it back to Convex and marks the scan ready. The phone shows
each step while it happens. Nothing talks to the phone directly.

Needs: ffmpeg and colmap (brew install ffmpeg colmap) and Xcode's command
line tools. Brush, the trainer, is downloaded on first run.

Try the pipeline on a video without Convex:

    python3 tools/scan-worker/worker.py --local video.mov --out /tmp/scan

Settings (environment variables):
    CONVEX_URL        the deployment to work for
    SCAN_WORKER_KEY   must match the key on the deployment
    SCAN_FPS          frames per second taken from the video (default 6)
    SCAN_STEPS        training steps (default 10000; more is sharper and slower)
    SCAN_MAX_SPLATS   splats sent to the phone (default 300000)
    SCAN_REMOVE_PEOPLE  set to 1 to leave people out of the 3D space (default: keep them)
"""
import argparse, json, os, shutil, socket, struct, subprocess, sys, tempfile, threading, time, traceback
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CONVEX_URL = os.environ.get("CONVEX_URL", "https://valiant-jay-880.convex.cloud").rstrip("/")
KEY = os.environ.get("SCAN_WORKER_KEY", "odyssey-scan-worker")
FPS = float(os.environ.get("SCAN_FPS", "6"))
STEPS = int(os.environ.get("SCAN_STEPS", "10000"))
MAX_SPLATS = int(os.environ.get("SCAN_MAX_SPLATS", "300000"))
# People are always ignored when working out where the camera was (they move, the room does not).
# Leaving them out of the 3D space as well is optional: it leaves smudges where they stood.
REMOVE_PEOPLE = os.environ.get("SCAN_REMOVE_PEOPLE", "0") == "1"
CACHE = os.path.expanduser("~/.odyssey-scan")
BRUSH_URL = "https://github.com/ArthurBrussee/brush/releases/download/v0.3.0/brush-app-aarch64-apple-darwin.tar.xz"


class ScanError(Exception):
    """A problem worth showing on the phone as is."""


# ── Convex ───────────────────────────────────────────────────────────────

def convex(kind, path, args):
    body = json.dumps({"path": path, "args": args, "format": "json"}).encode()
    req = urllib.request.Request(f"{CONVEX_URL}/api/{kind}", data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as res:
        out = json.loads(res.read())
    if out.get("status") != "success":
        raise RuntimeError(out.get("errorMessage") or str(out))
    return out.get("value")


def upload(file_path):
    url = convex("mutation", "scans:workerUploadUrl", {"key": KEY})
    data = open(file_path, "rb").read()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/octet-stream"})
    with urllib.request.urlopen(req, timeout=600) as res:
        return json.loads(res.read())["storageId"]


class Reporter:
    """Tells the phone what is happening, and keeps saying it so the scan is not handed to another worker."""

    def __init__(self, scan_id):
        self.scan_id, self.message, self.progress = scan_id, "Starting", 0.02
        self.done = threading.Event()
        self.deleted = False  # the explorer deleted the scan while it was being built
        if scan_id:
            threading.Thread(target=self._beat, daemon=True).start()

    def __call__(self, message, progress):
        self.message, self.progress = message, progress
        print(f"  [{progress * 100:3.0f}%] {message}", flush=True)
        self._send()
        if self.deleted:
            raise ScanError("This scan was deleted.")

    def _send(self):
        if not self.scan_id:
            return
        try:
            alive = convex("mutation", "scans:report", {"key": KEY, "id": self.scan_id, "message": self.message, "progress": self.progress})
            if alive is False:
                self.deleted = True
        except Exception as e:  # a dropped report must never stop a render
            print(f"  (could not report: {e})", flush=True)

    def _beat(self):
        while not self.done.wait(45):
            self._send()


# ── Tools ────────────────────────────────────────────────────────────────

def need(tool):
    path = shutil.which(tool)
    if not path:
        sys.exit(f"{tool} is missing. Install it with: brew install {tool}")
    return path


def brush_bin():
    custom = os.environ.get("BRUSH_BIN")
    if custom:
        return custom
    path = os.path.join(CACHE, "brush_app")
    if not os.path.exists(path):
        print("Downloading Brush (one time)...", flush=True)
        os.makedirs(CACHE, exist_ok=True)
        archive = os.path.join(CACHE, "brush.tar.xz")
        subprocess.run(["curl", "-fsSL", "-o", archive, BRUSH_URL], check=True)
        subprocess.run(["tar", "-xf", archive, "-C", CACHE], check=True)
        shutil.move(os.path.join(CACHE, "brush-app-aarch64-apple-darwin", "brush_app"), path)
    return path


def masks_bin():
    """The people finder, compiled once from people_masks.swift."""
    src = os.path.join(HERE, "people_masks.swift")
    path = os.path.join(CACHE, "people_masks")
    if not os.path.exists(path) or os.path.getmtime(path) < os.path.getmtime(src):
        os.makedirs(CACHE, exist_ok=True)
        subprocess.run(["xcrun", "swiftc", "-O", "-o", path, src], check=True, stderr=subprocess.DEVNULL)
    return path


def run(cmd, log, **kw):
    with open(log, "ab") as f:
        f.write((" ".join(map(str, cmd)) + "\n").encode())
        f.flush()
        return subprocess.run(list(map(str, cmd)), stdout=f, stderr=subprocess.STDOUT, **kw)


def registered(model_dir):
    """How many frames a COLMAP model placed."""
    try:
        with open(os.path.join(model_dir, "images.bin"), "rb") as f:
            return struct.unpack("<Q", f.read(8))[0]
    except OSError:
        return 0


# ── The pipeline ─────────────────────────────────────────────────────────

def build(video, work, say):
    """Video in, (model.bin, meta.json text, splat count) out."""
    log = os.path.join(work, "log.txt")
    images = os.path.join(work, "images")
    os.makedirs(images)

    say("Picking frames from your video", 0.06)
    # Videos from the app are 1080p; anything bigger is scaled so the long side is 1600.
    scale = "scale='if(gt(iw,ih),min(1600,iw),-2)':'if(gt(iw,ih),-2,min(1600,ih))'"
    r = run([need("ffmpeg"), "-v", "error", "-y", "-i", video, "-vf", f"fps={FPS},{scale}", "-q:v", "2",
             os.path.join(images, "f_%04d.jpg")], log)
    frames = len(os.listdir(images))
    if r.returncode != 0 or frames < 20:
        raise ScanError("The video was too short to build a space from. Record at least 20 seconds.")

    say("Removing people from the scene" if REMOVE_PEOPLE else "Finding the people so the camera can ignore them", 0.12)
    colmap_masks, brush_masks = os.path.join(work, "colmap_masks"), os.path.join(work, "ds", "masks")
    os.makedirs(os.path.join(work, "ds"))
    have_masks = run([masks_bin(), images, colmap_masks, brush_masks], log).returncode == 0

    colmap = need("colmap")
    db, sparse = os.path.join(work, "database.db"), os.path.join(work, "sparse")
    say(f"Finding landmarks in {frames} frames", 0.18)
    extract = [colmap, "feature_extractor", "--database_path", db, "--image_path", images,
               "--ImageReader.single_camera", "1", "--ImageReader.camera_model", "SIMPLE_PINHOLE",
               "--FeatureExtraction.use_gpu", "0", "--SiftExtraction.max_num_features", "8000"]
    if have_masks:
        extract += ["--ImageReader.mask_path", colmap_masks]
    if run(extract, log).returncode != 0:
        raise ScanError("Could not read the video frames.")

    say("Matching landmarks between frames", 0.26)
    run([colmap, "sequential_matcher", "--database_path", db, "--FeatureMatching.use_gpu", "0",
         "--FeatureMatching.guided_matching", "1", "--SequentialMatching.overlap", "30",
         "--SequentialMatching.loop_detection", "1"], log)

    def solve(out_dir):
        """Place the frames. Forgiving settings, so a blurry stretch does not cut the walk in two."""
        os.makedirs(out_dir)
        solve_log = out_dir + ".log"
        proc = subprocess.Popen([colmap, "mapper", "--database_path", db, "--image_path", images, "--output_path", out_dir,
                                 "--Mapper.ba_refine_principal_point", "0", "--Mapper.abs_pose_min_num_inliers", "12",
                                 "--Mapper.abs_pose_min_inlier_ratio", "0.12", "--Mapper.max_reg_trials", "6"],
                                stdout=open(solve_log, "wb"), stderr=subprocess.STDOUT)
        # This is the longest quiet step, so count the frames as they are placed and say so.
        told = 0
        try:
            while proc.poll() is None:
                time.sleep(4)
                placed_now = min(frames, open(solve_log, errors="ignore").read().count("Registering image"))
                if placed_now - told >= 10:
                    told = placed_now
                    say(f"Working out where the camera was, {placed_now} of {frames} frames",
                        say.progress if say.progress > 0.39 else 0.34 + 0.05 * placed_now / frames)
        finally:
            if proc.poll() is None:
                proc.kill()
        return sorted(((registered(os.path.join(out_dir, d)), d) for d in os.listdir(out_dir)), reverse=True)

    say("Working out where the camera was", 0.34)
    models = solve(sparse)
    if models and models[0][0] < 0.7 * frames:
        # The solve has some luck in it. When it lost a large part of the walk, a second go often keeps it.
        say("Working out where the camera was, second pass", 0.39)
        again_dir = os.path.join(work, "sparse_again")
        again = solve(again_dir)
        if again and again[0][0] > models[0][0]:
            models, sparse = again, again_dir
    if not models or models[0][0] < 15:
        raise ScanError("Could not follow the camera through this video. Move slower and avoid quick turns.")
    placed, best = models[0][0], os.path.join(sparse, models[0][1])
    # A hard moment in the video splits the walk into pieces. Pieces that share frames can be joined.
    joined = False
    for count, name in models[1:]:
        if count < 15:
            continue
        merged = os.path.join(sparse, f"joined_{name}")
        os.makedirs(merged)
        r = run([colmap, "model_merger", "--input_path1", best, "--input_path2", os.path.join(sparse, name),
                 "--output_path", merged], log)
        if r.returncode == 0 and registered(merged) > placed:
            placed, best, joined = registered(merged), merged, True
    if joined:
        say("Joining the parts of your walk", 0.42)
        run([colmap, "bundle_adjuster", "--input_path", best, "--output_path", best], log)
    print(f"  placed {placed} of {frames} frames ({len(models)} piece{'s' if len(models) > 1 else ''}"
          f"{', joined' if joined else ''})", flush=True)

    ds = os.path.join(work, "ds")
    os.makedirs(os.path.join(ds, "sparse", "0"))
    os.symlink(images, os.path.join(ds, "images"))
    for name in ("cameras.bin", "images.bin", "points3D.bin"):
        shutil.copy(os.path.join(best, name), os.path.join(ds, "sparse", "0", name))
    if not have_masks or not REMOVE_PEOPLE:
        shutil.rmtree(brush_masks, ignore_errors=True)

    out = os.path.join(work, "out")
    os.makedirs(out)
    say("Building the 3D space", 0.45)
    every = max(250, STEPS // 14)
    proc = subprocess.Popen([brush_bin(), ds, "--total-steps", str(STEPS), "--export-every", str(every),
                             "--eval-every", str(STEPS * 10), "--export-path", out, "--max-resolution", "1280",
                             "--max-splats", "1500000"], cwd=work, stdout=open(log, "ab"), stderr=subprocess.STDOUT)
    def exports():
        """Brush's exports so far as (step, file), oldest first. It zero-pads the step in the name."""
        found = [(int(n[7:-4]), os.path.join(out, n)) for n in os.listdir(out)
                 if n.startswith("export_") and n.endswith(".ply") and n[7:-4].isdigit()]
        return sorted(found)

    seen = 0
    try:
        while proc.poll() is None:
            time.sleep(5)
            done = exports()
            if done and done[-1][0] != seen:
                seen = done[-1][0]
                say(f"Building the 3D space, {round(seen / STEPS * 100)}% trained", 0.45 + 0.47 * seen / STEPS)
                for _, old in done[:-1]:  # each export is big; keep only the newest
                    try:
                        os.remove(old)
                    except OSError:
                        pass
    finally:
        if proc.poll() is None:  # never leave the trainer running after a failure or Ctrl+C
            proc.kill()
    done = exports()
    if not done or done[-1][0] < STEPS:
        raise ScanError("The 3D build stopped early on the render computer.")
    final = done[-1][1]

    say("Levelling the floor and packing it for the phone", 0.94)
    txt, phone = os.path.join(work, "txt"), os.path.join(work, "phone")
    os.makedirs(txt)
    run([colmap, "model_converter", "--input_path", os.path.join(ds, "sparse", "0"), "--output_path", txt,
         "--output_type", "TXT"], log)
    r = run([sys.executable, os.path.join(HERE, "build_model.py"), final, txt, phone, str(MAX_SPLATS)], log)
    if r.returncode != 0:
        raise ScanError("Could not pack the 3D space for the phone.")
    meta = open(os.path.join(phone, "meta.json")).read()
    # Keep the trained splat and the cameras, so a scan can be repacked later without training again.
    keep = os.path.join(CACHE, "scans", os.path.basename(work))
    shutil.copytree(txt, os.path.join(keep, "txt"))
    shutil.copy(final, os.path.join(keep, "splat.ply"))
    return os.path.join(phone, "model.bin"), meta, json.loads(meta)["count"]


def work_on(job):
    scan_id = job["id"]
    print(f"\nScan {scan_id}: {job.get('name') or job['placeName']} at {job['placeName']} ({job['seconds']:.0f} s)", flush=True)
    say = Reporter(scan_id)
    work = tempfile.mkdtemp(prefix="odyssey-scan-")
    try:
        say("Downloading your video", 0.03)
        video = os.path.join(work, "video.mov")
        urllib.request.urlretrieve(job["videoUrl"], video)
        model, meta, count = build(video, work, say)
        say("Uploading the 3D space", 0.97)
        model_id = upload(model)
        say.done.set()
        convex("mutation", "scans:complete", {"key": KEY, "id": scan_id, "modelId": model_id, "meta": meta, "splats": count})
        print(f"  ready: {count} splats", flush=True)
        shutil.rmtree(work, ignore_errors=True)
    except Exception as e:
        say.done.set()
        traceback.print_exc()
        message = str(e) if isinstance(e, ScanError) else "Something went wrong while building this space."
        print(f"  failed; files kept in {work}", flush=True)
        try:
            convex("mutation", "scans:fail", {"key": KEY, "id": scan_id, "message": message})
        except Exception:
            pass


def main():
    parser = argparse.ArgumentParser(description="Odyssey 3D scan render worker")
    parser.add_argument("--local", help="build one video file without Convex")
    parser.add_argument("--out", help="where --local puts model.bin and meta.json")
    opts = parser.parse_args()
    for tool in ("ffmpeg", "colmap"):
        need(tool)
    brush_bin()
    masks_bin()

    if opts.local:
        work = tempfile.mkdtemp(prefix="odyssey-scan-")
        model, meta, count = build(os.path.abspath(opts.local), work, Reporter(None))
        out = opts.out or os.path.join(work, "phone")
        os.makedirs(out, exist_ok=True)
        if os.path.dirname(model) != os.path.abspath(out):
            shutil.copy(model, os.path.join(out, "model.bin"))
            open(os.path.join(out, "meta.json"), "w").write(meta)
        print(f"Done: {count} splats in {out} (working files in {work})")
        return

    name = socket.gethostname()
    print(f"Render worker {name} watching {CONVEX_URL}. Ctrl+C to stop.", flush=True)
    while True:
        try:
            job = convex("mutation", "scans:claim", {"key": KEY, "worker": name})
        except Exception as e:
            print(f"Convex is not answering ({e}); trying again shortly.", flush=True)
            time.sleep(10)
            continue
        if job:
            work_on(job)
        else:
            time.sleep(4)


if __name__ == "__main__":
    main()
