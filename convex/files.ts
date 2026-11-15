// Uploads: the app asks for a one-time upload URL, POSTs the bytes there,
// gets a storageId back, then registers it here so it can be found by path.

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib";

export const generateUploadUrl = mutation({
  args: {},
  handler: async (ctx) => {
    await requireUser(ctx);
    return await ctx.storage.generateUploadUrl();
  },
});

/** Remember an explorer's upload (check-in photo, selfie, avatar, walkthrough). */
export const registerUpload = mutation({
  args: {
    storageId: v.id("_storage"),
    kind: v.string(),
    fileName: v.string(),
    placeId: v.optional(v.string()),
  },
  handler: async (ctx, { storageId, kind, fileName, placeId }) => {
    const userId = await requireUser(ctx);
    const meta = await ctx.db.system.get(storageId);
    if (!meta) throw new Error("Upload not found");
    const path = `user/${userId}/${fileName}`;
    const existing = await ctx.db.query("media").withIndex("by_path", (q) => q.eq("path", path)).unique();
    if (existing) return { path, url: await ctx.storage.getUrl(existing.storageId) };
    await ctx.db.insert("media", {
      path,
      storageId,
      kind,
      contentType: meta.contentType ?? "application/octet-stream",
      bytes: meta.size,
      ownerId: userId,
      placeId,
      createdAt: Date.now(),
    });
    return { path, url: await ctx.storage.getUrl(storageId) };
  },
});

/** URLs for a batch of media paths (seed or uploads). Missing paths are left out. */
export const urls = query({
  args: { paths: v.array(v.string()) },
  handler: async (ctx, { paths }) => {
    const out: Record<string, string> = {};
    for (const path of paths.slice(0, 200)) {
      const row = await ctx.db.query("media").withIndex("by_path", (q) => q.eq("path", path)).unique();
      if (!row) continue;
      const url = await ctx.storage.getUrl(row.storageId);
      if (url) out[path] = url;
    }
    return out;
  },
});

/** Everything the explorer has uploaded, newest first. */
export const myUploads = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const rows = await ctx.db.query("media").withIndex("by_owner", (q) => q.eq("ownerId", userId)).order("desc").take(200);
    return await Promise.all(rows.map(async (r) => ({ ...r, url: await ctx.storage.getUrl(r.storageId) })));
  },
});
