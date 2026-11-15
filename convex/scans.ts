// 3D scans: a walkthrough video becomes a space you can walk around in.
//
// The phone uploads the video and creates a scan row. A render worker (a
// laptop running tools/scan-worker) claims the row, builds the 3D model and
// uploads it back. The phone reads the row to show progress and, once it is
// ready, opens the 3D view. Everything goes through Convex.

import { mutation, query } from "./_generated/server";
import type { QueryCtx } from "./_generated/server";
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

async function present(ctx: QueryCtx, scan: Doc<"scans">) {
  return {
    id: scan._id,
    placeId: scan.placeId,
    placeName: scan.placeName,
    status: scan.status,
    message: scan.message,
    progress: scan.progress,
    seconds: scan.seconds,
    createdAt: scan.createdAt,
    updatedAt: scan.updatedAt,
    splats: scan.splats,
    meta: scan.meta,
    modelUrl: scan.modelId ? await ctx.storage.getUrl(scan.modelId) : null,
  };
}

// ── The phone ──────────────────────────────────────────────────────────

/** A one-time URL to upload the walkthrough video to. */
export const generateUploadUrl = mutation({
  args: {},
  handler: async (ctx) => await ctx.storage.generateUploadUrl(),
});

/** Queue a scan of a place from an uploaded video. */
export const create = mutation({
  args: {
    placeId: v.string(),
    placeName: v.string(),
    lat: v.number(),
    lng: v.number(),
    videoId: v.id("_storage"),
    seconds: v.number(),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    const now = Date.now();
    return await ctx.db.insert("scans", {
      ...args,
      userId: userId ?? undefined,
      status: "queued",
      message: "Waiting for a render computer",
      progress: 0,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const get = query({
  args: { id: v.id("scans") },
  handler: async (ctx, { id }) => {
    const scan = await ctx.db.get(id);
    return scan ? await present(ctx, scan) : null;
  },
});

/** The scans of one place, newest first. */
export const forPlace = query({
  args: { placeId: v.string() },
  handler: async (ctx, { placeId }) => {
    const rows = await ctx.db
      .query("scans")
      .withIndex("by_place", (q) => q.eq("placeId", placeId))
      .order("desc")
      .take(10);
    return await Promise.all(rows.map((r) => present(ctx, r)));
  },
});

/** The latest scans anywhere, so the map can show which places have a 3D view. */
export const recent = query({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.db.query("scans").order("desc").take(50);
    return await Promise.all(rows.map((r) => present(ctx, r)));
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
    await ctx.db.patch(id, { status: "processing", message, progress, updatedAt: Date.now() });
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
    await ctx.db.patch(id, {
      status: "ready",
      message: "Ready to explore",
      progress: 1,
      modelId,
      meta,
      splats,
      updatedAt: Date.now(),
    });
  },
});

export const fail = mutation({
  args: { key: v.string(), id: v.id("scans"), message: v.string() },
  handler: async (ctx, { key, id, message }) => {
    checkWorker(key);
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
