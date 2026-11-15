// Loading the bundled seed (places, photos, demo explorers, quests...) into
// Convex. Run by `npm run seed` (tools/convex-seed.mjs). Every function here
// needs the SEED_SECRET set on the deployment, so the app cannot call them.

import { mutation } from "./_generated/server";
import { v } from "convex/values";
import { placeByPlaceId } from "./lib";
import { ensurePlace, placeInput, sanitizeTags } from "./places";

function guard(secret: string) {
  const expected = process.env.SEED_SECRET;
  if (!expected || secret !== expected) throw new Error("Seeding is locked: wrong or missing SEED_SECRET");
}

export const uploadUrl = mutation({
  args: { secret: v.string() },
  handler: async (ctx, { secret }) => {
    guard(secret);
    return await ctx.storage.generateUploadUrl();
  },
});

export const mediaPaths = mutation({
  args: { secret: v.string() },
  handler: async (ctx, { secret }) => {
    guard(secret);
    const out: Record<string, number> = {};
    for (const kind of ["seed-image", "seed-video"]) {
      const rows = await ctx.db.query("media").withIndex("by_kind", (q) => q.eq("kind", kind)).collect();
      for (const r of rows) out[r.path] = r.bytes;
    }
    return out;
  },
});

export const registerMedia = mutation({
  args: { secret: v.string(), path: v.string(), storageId: v.id("_storage"), kind: v.string() },
  handler: async (ctx, { secret, path, storageId, kind }) => {
    guard(secret);
    const meta = await ctx.db.system.get(storageId);
    const existing = await ctx.db.query("media").withIndex("by_path", (q) => q.eq("path", path)).unique();
    if (existing) {
      if (existing.storageId !== storageId) await ctx.storage.delete(existing.storageId);
      await ctx.db.patch(existing._id, { storageId, kind, bytes: meta?.size ?? 0, contentType: meta?.contentType ?? "" });
      return;
    }
    await ctx.db.insert("media", {
      path,
      storageId,
      kind,
      contentType: meta?.contentType ?? "application/octet-stream",
      bytes: meta?.size ?? 0,
      createdAt: Date.now(),
    });
  },
});

export const places = mutation({
  args: { secret: v.string(), places: v.array(placeInput) },
  handler: async (ctx, { secret, places }) => {
    guard(secret);
    let inserted = 0;
    let updated = 0;
    for (const p of places) {
      const existing = await placeByPlaceId(ctx, p.placeId);
      const media = p.photoPath
        ? await ctx.db.query("media").withIndex("by_path", (q) => q.eq("path", p.photoPath!)).unique()
        : null;
      if (existing) {
        await ctx.db.patch(existing._id, {
          name: p.name,
          category: p.category,
          cats: p.cats ?? [],
          lat: p.lat,
          lng: p.lng,
          area: p.area,
          address: p.address,
          blurb: p.blurb,
          hours: p.hours,
          rating: p.rating,
          reviews: p.reviews,
          website: p.website,
          tags: sanitizeTags(p.tags),
          photoPath: p.photoPath,
          photoStorageId: media?.storageId,
          updatedAt: Date.now(),
        });
        updated++;
      } else {
        const row = await ensurePlace(ctx, { ...p, source: p.source ?? "seed" });
        if (media) await ctx.db.patch(row._id, { photoStorageId: media.storageId });
        inserted++;
      }
    }
    return { inserted, updated };
  },
});

export const content = mutation({
  args: { secret: v.string(), entries: v.array(v.object({ key: v.string(), value: v.any() })) },
  handler: async (ctx, { secret, entries }) => {
    guard(secret);
    for (const { key, value } of entries) {
      const row = await ctx.db.query("seedContent").withIndex("by_key", (q) => q.eq("key", key)).unique();
      if (row) await ctx.db.patch(row._id, { value, updatedAt: Date.now() });
      else await ctx.db.insert("seedContent", { key, value, updatedAt: Date.now() });
    }
  },
});

export const bounties = mutation({
  args: { secret: v.string(), bounties: v.array(v.any()) },
  handler: async (ctx, { secret, bounties }) => {
    guard(secret);
    for (const data of bounties) {
      const bountyId = String(data.id);
      const row = await ctx.db.query("bounties").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique();
      if (row) await ctx.db.patch(row._id, { data });
      else await ctx.db.insert("bounties", { bountyId, data, active: true, createdAt: Date.now() });
    }
  },
});
