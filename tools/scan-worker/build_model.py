"""Turn a trained splat (.ply) and its COLMAP cameras into what the phone renders.

Writes two files into <out_dir>:
  model.bin   32 bytes per splat: position, covariance and colour, ready for the GPU
  meta.json   which way is up, and the path the explorer walked (for the tour and floor height)

The scene is scaled to metres and its floor is levelled, so walking stays on the ground.

usage: build_model.py <export.ply> <colmap_txt_dir> <out_dir> [max_splats]
"""
import json, math, os, random, struct, sys

EYE_HEIGHT = 1.4  # metres: roughly where a phone is held while filming


def quat_rows(w, x, y, z):
    n = math.sqrt(w * w + x * x + y * y + z * z) or 1.0
    w, x, y, z = w / n, x / n, y / n, z / n
    return (
        (1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)),
        (2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)),
        (2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)),
    )


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(a):
    n = math.sqrt(dot(a, a)) or 1.0
    return (a[0] / n, a[1] / n, a[2] / n)


def read_cameras(txt_dir):
    """Each registered frame: (frame number, position, forward axis, down axis)."""
    cams = []
    for line in open(os.path.join(txt_dir, "images.txt")):
        line = line.strip()
        if not line.lower().endswith((".jpg", ".png")):
            continue
        p = line.split()
        R = quat_rows(*map(float, p[1:5]))
        t = tuple(map(float, p[5:8]))
        center = tuple(-(R[0][k] * t[0] + R[1][k] * t[1] + R[2][k] * t[2]) for k in range(3))
        frame = int("".join(ch for ch in p[9] if ch.isdigit()) or 0)
        cams.append((frame, center, R[2], R[1]))
    cams.sort()
    return cams


def read_points(txt_dir):
    pts = []
    for line in open(os.path.join(txt_dir, "points3D.txt")):
        if line.startswith("#"):
            continue
        p = line.split()
        pts.append((float(p[1]), float(p[2]), float(p[3])))
    return pts


def find_floor(cams, pts):
    """The floor plane as (up direction, camera height above it), in COLMAP units.

    Start from the average of how the phone was held, find the layer of points
    under the cameras, then fit a plane to that layer so a tilted phone or a
    sloping reconstruction does not tilt the building.
    """
    down = [sum(c[3][k] for c in cams) for k in range(3)]
    up = unit(tuple(-v for v in down))
    cam_h = sum(dot(c[1], up) for c in cams) / len(cams)
    below = sorted(cam_h - dot(p, up) for p in pts if dot(p, up) < cam_h)
    if len(below) < 50:
        return up, (below[len(below) // 2] if below else 1.0)
    lo, hi = below[0], below[int(len(below) * 0.98)]
    bins = [0] * 60
    for h in below:
        if h <= hi:
            bins[min(59, int((h - lo) / ((hi - lo) or 1) * 60))] += 1
    peak = max(bins)
    floor_bin = max(i for i, b in enumerate(bins) if b > 0.5 * peak)
    floor_h = lo + (floor_bin + 0.5) / 60 * (hi - lo)

    layer = [p for p in pts if 0.6 * floor_h < cam_h - dot(p, up) < 1.5 * floor_h]
    if len(layer) < 30:
        return up, floor_h
    rng = random.Random(7)
    sample = layer if len(layer) <= 4000 else rng.sample(layer, 4000)
    tol = 0.05 * floor_h
    best, best_n, best_p = -1, up, None
    for _ in range(400):
        a, b, c = rng.sample(sample, 3)
        n = cross(sub(b, a), sub(c, a))
        if dot(n, n) < 1e-12:
            continue
        n = unit(n)
        if dot(n, up) < 0:
            n = (-n[0], -n[1], -n[2])
        if dot(n, up) < 0.9:  # more than about 25 degrees off: not a floor
            continue
        d = dot(n, a)
        score = sum(1 for p in sample if abs(dot(n, p) - d) < tol)
        if score > best:
            best, best_n, best_p = score, n, d
    if best_p is None:
        return up, floor_h
    heights = sorted(dot(c[1], best_n) - best_p for c in cams)
    return best_n, max(heights[len(heights) // 2], 0.2 * floor_h)


def main():
    ply_path, txt_dir, out_dir = sys.argv[1:4]
    cap = int(sys.argv[4]) if len(sys.argv) > 4 else 300000
    os.makedirs(out_dir, exist_ok=True)

    cams = read_cameras(txt_dir)
    up, cam_height = find_floor(cams, read_points(txt_dir))
    scale = EYE_HEIGHT / cam_height
    path_len = sum(math.dist(a[1], b[1]) for a, b in zip(cams, cams[1:])) * scale
    print(f"cameras {len(cams)}  scale {scale:.3f}  walked {path_len:.1f} m", file=sys.stderr)

    data = open(ply_path, "rb").read()
    end = data.index(b"end_header\n") + len(b"end_header\n")
    names, count = [], 0
    for line in data[:end].decode().splitlines():
        if line.startswith("element vertex"):
            count = int(line.split()[2])
        elif line.startswith("property"):
            names.append(line.split()[2])
    ix = {name: i for i, name in enumerate(names)}
    pick = [ix[k] for k in ("x", "y", "z", "scale_0", "scale_1", "scale_2", "rot_0", "rot_1", "rot_2", "rot_3",
                            "opacity", "f_dc_0", "f_dc_1", "f_dc_2")]
    stride = 4 * len(names)

    # Splats far from where the explorer walked are noise the video never really saw.
    centers = [c[1] for c in cams][::3]
    reach = (12.0 / scale) ** 2

    rows = []
    for rec in struct.iter_unpack(f"<{len(names)}f", data[end:end + count * stride]):
        x, y, z, s0, s1, s2, qw, qx, qy, qz, op, r, g, b = (rec[i] for i in pick)
        alpha = 1 / (1 + math.exp(-max(-30.0, min(30.0, op))))
        if alpha < 0.04:
            continue
        s0, s1, s2 = math.exp(min(s0, 20)), math.exp(min(s1, 20)), math.exp(min(s2, 20))
        if max(s0, s1, s2) * scale > 3.0:
            continue
        if min((x - c[0]) ** 2 + (y - c[1]) ** 2 + (z - c[2]) ** 2 for c in centers) > reach:
            continue
        rows.append((alpha * (s0 * s1 * s2) ** (1 / 3), x, y, z, s0, s1, s2, qw, qx, qy, qz, alpha, r, g, b))
    print(f"splats {count} -> {len(rows)} kept", file=sys.stderr)
    if cap and len(rows) > cap:
        rows.sort(reverse=True)
        rows = rows[:cap]

    SH_C0 = 0.28209479177387814
    clamp = lambda v: max(-65000.0, min(65000.0, v))
    byte = lambda v: max(0, min(255, int(v * 255 + 0.5)))
    out = bytearray()
    for _, x, y, z, s0, s1, s2, qw, qx, qy, qz, alpha, r, g, b in rows:
        R = quat_rows(qw, qx, qy, qz)
        s = (s0 * scale, s1 * scale, s2 * scale)
        M = [[R[i][j] * s[j] for j in range(3)] for i in range(3)]
        cov = lambda i, j: clamp(4 * sum(M[i][k] * M[j][k] for k in range(3)))
        out += struct.pack("<3fI6e4B", x * scale, y * scale, z * scale, 0,
                           cov(0, 0), cov(0, 1), cov(0, 2), cov(1, 1), cov(1, 2), cov(2, 2),
                           byte(0.5 + SH_C0 * r), byte(0.5 + SH_C0 * g), byte(0.5 + SH_C0 * b), byte(alpha))
    open(os.path.join(out_dir, "model.bin"), "wb").write(out)

    path = []
    for i, c in enumerate(cams):
        win = cams[max(0, i - 4):i + 5]
        pos = [sum(w[1][k] for w in win) / len(win) * scale for k in range(3)]
        fw = [sum(w[2][k] for w in win) / len(win) for k in range(3)]
        path.append([c[0]] + [round(v, 4) for v in pos + fw])
    meta = {"up": [round(v, 6) for v in up], "path": path[::2], "count": len(rows), "metres": round(path_len, 1)}
    json.dump(meta, open(os.path.join(out_dir, "meta.json"), "w"), separators=(",", ":"))
    print(f"model.bin {len(out) / 1e6:.1f} MB, {len(rows)} splats", file=sys.stderr)


if __name__ == "__main__":
    main()
