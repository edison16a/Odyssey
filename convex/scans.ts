// 3D scans: a walkthrough video becomes a space you can walk around in.
//
// The phone uploads the video and creates a scan row. A render worker (a
// laptop running tools/scan-worker) claims the row, builds the 3D model and
// uploads it back. The phone reads the row to show progress and, once it is
// ready, opens the 3D view. Everything goes through Convex.

import { internalMutation, internalQuery, mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import type { Doc } from "./_generated/dataModel";
import { v } from "convex/values";
import { getAuthUserId } from "@convex-dev/auth/server";

/** The worker's shared key. Set SCAN_WORKER_KEY in the Convex dashboard to change it. */
function checkWorker(key: string) {
  const expected = process.env.SCAN_WORKER_KEY ?? "odyssey-scan-worker";
  if (key !== expected) throw new Error("Wrong worker key");
}

/** A claimed scan that has not reported for this long goes back in the queue. */
const STALE_MS = 10 * 60 * 1000;

/** Whether this phone may delete the scan. Scans from before owners were recorded belong to nobody, so anyone may. */
function ownedBy(scan: Doc<"scans">, owner: string | undefined) {
  return scan.ownerKey === undefined || (owner !== undefined && scan.ownerKey === owner);
}

async function present(ctx: QueryCtx, scan: Doc<"scans">, owner?: string) {
  return {
    id: scan._id,
    placeId: scan.placeId,
    placeName: scan.placeName,
    name: scan.name ?? scan.placeName,
    creatorName: scan.creatorName,
    mine: ownedBy(scan, owner),
    replaces: scan.replaces,
    status: scan.status,
    message: scan.message,
    progress: scan.progress,
    seconds: scan.seconds,
    createdAt: scan.createdAt,
    updatedAt: scan.updatedAt,
    splats: scan.splats,
    meta: scan.meta,
    modelUrl: scan.modelId ? await ctx.storage.getUrl(scan.modelId) : null,
    analysis: scan.analysis,
    summary: scan.summary,
    features: scan.features ?? [],
    access: scan.access,
  };
}

/** Delete a scan and its files. The video is kept while another scan was built from it. */
async function erase(ctx: MutationCtx, scan: Doc<"scans">) {
  await ctx.db.delete(scan._id);
  if (scan.modelId) await ctx.storage.delete(scan.modelId);
  for (const f of scan.frames ?? []) await ctx.storage.delete(f.storageId);
  const siblings = await ctx.db
    .query("scans")
    .withIndex("by_place", (q) => q.eq("placeId", scan.placeId))
    .collect();
  if (!siblings.some((other) => other.videoId === scan.videoId)) await ctx.storage.delete(scan.videoId);
}

// ── The phone ──────────────────────────────────────────────────────────

/** A one-time URL to upload the walkthrough video to. */
export const generateUploadUrl = mutation({
  args: {},
  handler: async (ctx) => await ctx.storage.generateUploadUrl(),
});

/** Queue a scan of a place from an uploaded video. A place can have many: one per room or floor. */
export const create = mutation({
  args: {
    placeId: v.string(),
    placeName: v.string(),
    name: v.optional(v.string()),
    creatorName: v.optional(v.string()),
    owner: v.optional(v.string()),
    lat: v.number(),
    lng: v.number(),
    videoId: v.id("_storage"),
    seconds: v.number(),
  },
  handler: async (ctx, { owner, name, ...args }) => {
    const userId = await getAuthUserId(ctx);
    const now = Date.now();
    return await ctx.db.insert("scans", {
      ...args,
      name: name?.trim().slice(0, 40) || undefined,
      ownerKey: owner,
      userId: userId ?? undefined,
      status: "queued",
      message: "Waiting for a render computer",
      progress: 0,
      createdAt: now,
      updatedAt: now,
    });
  },
});

/** Delete a scan. Only the phone that made it may. */
export const remove = mutation({
  args: { id: v.id("scans"), owner: v.string() },
  handler: async (ctx, { id, owner }) => {
    const scan = await ctx.db.get(id);
    if (!scan) return;
    if (!ownedBy(scan, owner)) throw new Error("Only the explorer who made this scan can delete it");
    await erase(ctx, scan);
  },
});

/** Rename a scan. Only the phone that made it may. */
export const rename = mutation({
  args: { id: v.id("scans"), owner: v.string(), name: v.string() },
  handler: async (ctx, { id, owner, name }) => {
    const scan = await ctx.db.get(id);
    if (!scan) return;
    if (!ownedBy(scan, owner)) throw new Error("Only the explorer who made this scan can rename it");
    const clean = name.trim().slice(0, 40);
    if (clean) await ctx.db.patch(id, { name: clean });
  },
});

export const get = query({
  args: { id: v.id("scans"), owner: v.optional(v.string()) },
  handler: async (ctx, { id, owner }) => {
    const scan = await ctx.db.get(id);
    return scan ? await present(ctx, scan, owner) : null;
  },
});

/** The scans of one place, newest first. */
export const forPlace = query({
  args: { placeId: v.string(), owner: v.optional(v.string()) },
  handler: async (ctx, { placeId, owner }) => {
    const rows = await ctx.db
      .query("scans")
      .withIndex("by_place", (q) => q.eq("placeId", placeId))
      .order("desc")
      .take(30);
    return await Promise.all(rows.map((r) => present(ctx, r, owner)));
  },
});

/** The latest scans anywhere, so the map can show which places have a 3D view. */
export const recent = query({
  args: { owner: v.optional(v.string()) },
  handler: async (ctx, { owner }) => {
    const rows = await ctx.db.query("scans").order("desc").take(100);
    return await Promise.all(rows.map((r) => present(ctx, r, owner)));
  },
});

// ── The render worker ──────────────────────────────────────────────────

/** Take the oldest waiting scan, or one whose worker went quiet. */
export const claim = mutation({
  args: { key: v.string(), worker: v.string() },
  handler: async (ctx, { key, worker }) => {
    checkWorker(key);
    const now = Date.now();
    let scan = await ctx.db
      .query("scans")
      .withIndex("by_status", (q) => q.eq("status", "queued"))
      .order("asc")
      .first();
    if (!scan) {
      const running = await ctx.db
        .query("scans")
        .withIndex("by_status", (q) => q.eq("status", "processing"))
        .collect();
      scan = running.find((r) => now - r.updatedAt > STALE_MS) ?? null;
    }
    if (!scan) return null;
    await ctx.db.patch(scan._id, {
      status: "processing",
      message: "Starting",
      progress: 0.02,
      worker,
      updatedAt: now,
    });
    return {
      id: scan._id,
      placeName: scan.placeName,
      name: scan.name ?? scan.placeName,
      seconds: scan.seconds,
      videoUrl: await ctx.storage.getUrl(scan.videoId),
    };
  },
});

/** What the worker is doing right now, shown on the phone. */
export const report = mutation({
  args: { key: v.string(), id: v.id("scans"), message: v.string(), progress: v.number() },
  handler: async (ctx, { key, id, message, progress }) => {
    checkWorker(key);
    if (!(await ctx.db.get(id))) return false; // deleted: the worker can stop
    await ctx.db.patch(id, { status: "processing", message, progress, updatedAt: Date.now() });
    return true;
  },
});

export const workerUploadUrl = mutation({
  args: { key: v.string() },
  handler: async (ctx, { key }) => {
    checkWorker(key);
    return await ctx.storage.generateUploadUrl();
  },
});

/** The model is built: attach it and mark the scan ready. */
export const complete = mutation({
  args: {
    key: v.string(),
    id: v.id("scans"),
    modelId: v.id("_storage"),
    meta: v.string(),
    splats: v.number(),
  },
  handler: async (ctx, { key, id, modelId, meta, splats }) => {
    checkWorker(key);
    const scan = await ctx.db.get(id);
    if (!scan) return; // deleted while it was being built
    await ctx.db.patch(id, {
      status: "ready",
      message: "Ready to explore",
      progress: 1,
      modelId,
      meta,
      splats,
      updatedAt: Date.now(),
    });
    // A re-render takes the place of the scan it was made from.
    const older = scan.replaces ? await ctx.db.get(scan.replaces) : null;
    if (older) await erase(ctx, older);
  },
});

export const fail = mutation({
  args: { key: v.string(), id: v.id("scans"), message: v.string() },
  handler: async (ctx, { key, id, message }) => {
    checkWorker(key);
    if (!(await ctx.db.get(id))) return;
    await ctx.db.patch(id, { status: "failed", message, updatedAt: Date.now() });
  },
});

/** Build a scan again from its video. The old one stays available until the new one is ready. */
export const rerender = mutation({
  args: { key: v.string(), id: v.id("scans") },
  handler: async (ctx, { key, id }) => {
    checkWorker(key);
    const old = await ctx.db.get(id);
    if (!old) throw new Error("Scan not found");
    const now = Date.now();
    return await ctx.db.insert("scans", {
      userId: old.userId,
      placeId: old.placeId,
      placeName: old.placeName,
      name: old.name,
      creatorName: old.creatorName,
      ownerKey: old.ownerKey,
      replaces: old._id,
      lat: old.lat,
      lng: old.lng,
      videoId: old.videoId,
      seconds: old.seconds,
      status: "queued",
      message: "Waiting for a render computer",
      progress: 0,
      createdAt: now,
      updatedAt: now,
    });
  },
});

/** Put a failed scan back in the queue. */
export const retry = mutation({
  args: { key: v.string(), id: v.id("scans") },
  handler: async (ctx, { key, id }) => {
    checkWorker(key);
    await ctx.db.patch(id, { status: "queued", message: "Waiting for a render computer", progress: 0, updatedAt: Date.now() });
  },
});

// ── What the video shows of the building ───────────────────────────────

/** The worker hands over a few frames of the video; Claude then reads them for stairs, doors and the rest. */
export const addFrames = mutation({
  args: {
    key: v.string(),
    id: v.id("scans"),
    frames: v.array(v.object({ frame: v.number(), storageId: v.id("_storage") })),
  },
  handler: async (ctx, { key, id, frames }) => {
    checkWorker(key);
    const scan = await ctx.db.get(id);
    if (!scan) return;
    for (const f of scan.frames ?? []) await ctx.storage.delete(f.storageId);
    await ctx.db.patch(id, { frames, analysis: "pending" });
    await ctx.scheduler.runAfter(0, internal.scanAnalysis.analyze, { id });
  },
});

/** Read the frames a scan already has again, for instance after the instructions changed. */
export const reanalyze = mutation({
  args: { key: v.string(), id: v.id("scans") },
  handler: async (ctx, { key, id }) => {
    checkWorker(key);
    const scan = await ctx.db.get(id);
    if (!scan?.frames?.length) throw new Error("This scan has no frames to read");
    await ctx.db.patch(id, { analysis: "pending" });
    await ctx.scheduler.runAfter(0, internal.scanAnalysis.analyze, { id });
  },
});

/** The video of a scan, so a worker can pick frames from one that was rendered before frames existed. */
export const videoFor = mutation({
  args: { key: v.string(), id: v.id("scans") },
  handler: async (ctx, { key, id }) => {
    checkWorker(key);
    const scan = await ctx.db.get(id);
    return scan ? { name: scan.name ?? scan.placeName, videoUrl: await ctx.storage.getUrl(scan.videoId) } : null;
  },
});

export const framesFor = internalQuery({
  args: { id: v.id("scans") },
  handler: async (ctx, { id }) => {
    const scan = await ctx.db.get(id);
    if (!scan) return null;
    const frames = [];
    for (const f of scan.frames ?? []) {
      const url = await ctx.storage.getUrl(f.storageId);
      if (url) frames.push({ frame: f.frame, url });
    }
    return { placeName: scan.placeName, name: scan.name ?? scan.placeName, frames };
  },
});

export const saveAnalysis = internalMutation({
  args: {
    id: v.id("scans"),
    summary: v.string(),
    access: v.object({ wheelchair: v.string(), reason: v.string() }),
    features: v.array(
      v.object({
        kind: v.string(),
        label: v.string(),
        detail: v.string(),
        wheelchair: v.string(),
        certainty: v.string(),
        frame: v.number(),
      }),
    ),
  },
  handler: async (ctx, { id, ...found }) => {
    if (!(await ctx.db.get(id))) return;
    await ctx.db.patch(id, { ...found, analysis: "done" });
  },
});

export const failAnalysis = internalMutation({
  args: { id: v.id("scans") },
  handler: async (ctx, { id }) => {
    if (await ctx.db.get(id)) await ctx.db.patch(id, { analysis: "failed" });
  },
});
