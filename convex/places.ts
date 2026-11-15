// Places: the curated seed places, OpenStreetMap places explorers have
// checked in at, and what the community has learned about each.

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import type { MutationCtx } from "./_generated/server";
import { placeByPlaceId, requireUser } from "./lib";

export const placeInput = v.object({
  placeId: v.string(),
  name: v.string(),
  category: v.optional(v.string()),
  cats: v.optional(v.array(v.string())),
  lat: v.number(),
  lng: v.number(),
  area: v.optional(v.string()),
  address: v.optional(v.string()),
  blurb: v.optional(v.string()),
  hours: v.optional(v.string()),
  rating: v.optional(v.number()),
  reviews: v.optional(v.number()),
  website: v.optional(v.string()),
  tags: v.optional(v.record(v.string(), v.string())),
  source: v.optional(v.string()),
  photoPath: v.optional(v.string()),
});

/** Insert a place the first time anyone touches it, and return its row id. */
export async function ensurePlace(ctx: MutationCtx, p: typeof placeInput.type) {
  const existing = await placeByPlaceId(ctx, p.placeId);
  if (existing) return existing;
  const id = await ctx.db.insert("places", {
    placeId: p.placeId,
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
    source: p.source ?? "osm",
    photoPath: p.photoPath,
    explorerCount: 0,
    contributionCount: 0,
    updatedAt: Date.now(),
  });
  return (await ctx.db.get(id))!;
}

/** Convex field names cannot start with "$" or "_"; OSM keys never do, but be safe. */
export function sanitizeTags(tags?: Record<string, string>) {
  if (!tags) return undefined;
  const out: Record<string, string> = {};
  for (const [k, val] of Object.entries(tags)) {
    if (!k || k.startsWith("$") || k.startsWith("_")) continue;
    out[k] = String(val).slice(0, 500);
  }
  return out;
}

export const get = query({
  args: { placeId: v.string() },
  handler: async (ctx, { placeId }) => {
    const place = await placeByPlaceId(ctx, placeId);
    if (!place) return null;
    const photoUrl = place.photoStorageId ? await ctx.storage.getUrl(place.photoStorageId) : null;
    const first = place.firstExplorerId
      ? await ctx.db.query("profiles").withIndex("by_user", (q) => q.eq("userId", place.firstExplorerId!)).unique()
      : null;
    return { ...place, photoUrl, firstExplorer: first ? { name: first.name, handle: first.handle } : null };
  },
});

export const byArea = query({
  args: { area: v.string() },
  handler: async (ctx, { area }) => {
    const rows = await ctx.db.query("places").withIndex("by_area", (q) => q.eq("area", area)).take(500);
    return await Promise.all(
      rows.map(async (p) => ({ ...p, photoUrl: p.photoStorageId ? await ctx.storage.getUrl(p.photoStorageId) : null })),
    );
  },
});

export const search = query({
  args: { text: v.string(), area: v.optional(v.string()) },
  handler: async (ctx, { text, area }) => {
    return await ctx.db
      .query("places")
      .withSearchIndex("search_name", (q) => (area ? q.search("name", text).eq("area", area) : q.search("name", text)))
      .take(20);
  },
});

/** Who has explored and documented a place, with their share of verified walkthroughs. */
export const contributors = query({
  args: { placeId: v.string() },
  handler: async (ctx, { placeId }) => {
    const rows = await ctx.db.query("contributions").withIndex("by_place", (q) => q.eq("placeId", placeId)).collect();
    const verified = rows.filter((r) => r.status === "verified");
    const counted = verified.length > 0 ? verified : rows;
    const byUser = new Map<string, number>();
    for (const r of counted) byUser.set(r.userId, (byUser.get(r.userId) ?? 0) + r.seconds);
    const total = [...byUser.values()].reduce((a, b) => a + b, 0) || 1;
    const out = [];
    for (const [userId, seconds] of byUser) {
      const profile = await ctx.db
        .query("profiles")
        .withIndex("by_user", (q) => q.eq("userId", userId as any))
        .unique();
      out.push({ userId, name: profile?.name ?? "Explorer", handle: profile?.handle ?? "", share: seconds / total });
    }
    return out.sort((a, b) => b.share - a.share);
  },
});

/** Save a place someone found (an OSM place, say) so others can open it later. */
export const upsert = mutation({
  args: { place: placeInput },
  handler: async (ctx, { place }) => {
    await requireUser(ctx);
    const row = await ensurePlace(ctx, place);
    return row._id;
  },
});

export const content = query({
  args: { key: v.string() },
  handler: async (ctx, { key }) => {
    const row = await ctx.db.query("seedContent").withIndex("by_key", (q) => q.eq("key", key)).unique();
    return row?.value ?? null;
  },
});
