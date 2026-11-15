// Check-ins and walkthrough contributions: the explorer's own record of
// where they have been and what they documented. Both also feed taste.

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import { ensurePlace, placeInput } from "./places";
import { requireProfile, requireUser } from "./lib";
import { recordTaste } from "./taste";

const insights = v.object({
  vibe: v.optional(v.string()),
  summary: v.optional(v.string()),
  tags: v.optional(v.array(v.string())),
  source: v.optional(v.string()),
});

export const checkIn = mutation({
  args: {
    place: placeInput,
    day: v.string(),
    caption: v.string(),
    photoStorageId: v.optional(v.id("_storage")),
    selfieStorageId: v.optional(v.id("_storage")),
    first: v.boolean(),
    recommended: v.boolean(),
    coins: v.number(),
    xp: v.number(),
    points: v.number(),
    questId: v.optional(v.string()),
    features: v.array(v.string()),
    city: v.optional(v.string()),
    clientPostId: v.optional(v.string()),
  },
  handler: async (ctx, a) => {
    const userId = await requireUser(ctx);
    const profile = await requireProfile(ctx, userId);
    const place = await ensurePlace(ctx, a.place);

    const already = await ctx.db
      .query("checkins")
      .withIndex("by_user_place_day", (q) => q.eq("userId", userId).eq("placeId", a.place.placeId).eq("day", a.day))
      .first();
    const visitedBefore = await ctx.db
      .query("checkins")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .filter((q) => q.eq(q.field("placeId"), a.place.placeId))
      .first();

    // The first explorer anywhere on Odyssey is decided here, not on the phone.
    const first = a.first && place.firstExplorerId === undefined;
    const now = Date.now();
    const checkinId = await ctx.db.insert("checkins", {
      userId,
      placeId: a.place.placeId,
      placeName: a.place.name,
      day: a.day,
      caption: a.caption,
      photoStorageId: a.photoStorageId,
      selfieStorageId: a.selfieStorageId,
      first,
      recommended: a.recommended,
      coins: already ? 0 : a.coins,
      xp: already ? 0 : a.xp,
      points: already ? 0 : a.points,
      questId: a.questId,
      lat: a.place.lat,
      lng: a.place.lng,
      createdAt: now,
    });

    await ctx.db.patch(place._id, {
      explorerCount: place.explorerCount + (visitedBefore ? 0 : 1),
      ...(first ? { firstExplorerId: userId, firstExploredAt: now } : {}),
      updatedAt: now,
    });
    if (!visitedBefore || first) {
      await ctx.db.patch(profile._id, {
        explored: profile.explored + (visitedBefore ? 0 : 1),
        firsts: profile.firsts + (first ? 1 : 0),
        updatedAt: now,
      });
    }

    await ctx.db.insert("posts", {
      userId,
      clientId: a.clientPostId ?? `checkin-${checkinId}`,
      placeId: a.place.placeId,
      kind: "visit",
      caption: a.caption,
      first,
      photoStorageId: a.photoStorageId,
      selfieStorageId: a.selfieStorageId,
      likes: 0,
      comments: 0,
      createdAt: now,
    });

    if (!already) {
      await recordTaste(ctx, {
        userId,
        placeId: a.place.placeId,
        placeName: a.place.name,
        kind: "checkin",
        value: 1,
        features: a.features,
        city: a.city ?? profile.city,
        extra: a.caption ? `They wrote: "${a.caption.slice(0, 200)}"` : undefined,
      });
    }
    return { checkinId, first, fresh: !already };
  },
});

export const addWalkthrough = mutation({
  args: {
    place: placeInput,
    seconds: v.number(),
    videoStorageId: v.optional(v.id("_storage")),
    insights: v.optional(insights),
    points: v.number(),
    features: v.array(v.string()),
    bountyId: v.optional(v.string()),
    city: v.optional(v.string()),
  },
  handler: async (ctx, a) => {
    const userId = await requireUser(ctx);
    const profile = await requireProfile(ctx, userId);
    const place = await ensurePlace(ctx, a.place);
    const now = Date.now();
    const id = await ctx.db.insert("contributions", {
      userId,
      placeId: a.place.placeId,
      placeName: a.place.name,
      kind: "walkthrough",
      seconds: a.seconds,
      videoStorageId: a.videoStorageId,
      insights: a.insights,
      // On-device analysis is a first pass; a second explorer agreeing verifies it.
      status: "pending",
      bountyId: a.bountyId,
      points: a.points,
      createdAt: now,
    });
    await ctx.db.patch(place._id, { contributionCount: place.contributionCount + 1, updatedAt: now });
    await ctx.db.patch(profile._id, { contributions: profile.contributions + 1, updatedAt: now });
    await maybeVerify(ctx, place._id, a.place.placeId, a.insights);
    if (a.insights?.vibe) {
      await recordTaste(ctx, {
        userId,
        placeId: a.place.placeId,
        placeName: a.place.name,
        kind: "walkthrough",
        value: 1,
        features: a.features,
        city: a.city ?? profile.city,
        extra: `They recorded a walkthrough and it felt ${a.insights.vibe}.${a.insights.summary ? " " + a.insights.summary : ""}`,
      });
    }
    return { contributionId: id };
  },
});

/**
 * Two explorers who saw the same vibe at a place verify each other, and
 * the place page then shows it as confirmed.
 */
async function maybeVerify(ctx: any, placeRowId: Id<"places">, placeId: string, fresh?: typeof insights.type) {
  if (!fresh?.vibe) return;
  const rows = await ctx.db
    .query("contributions")
    .withIndex("by_place", (q: any) => q.eq("placeId", placeId))
    .collect();
  const agreeing = rows.filter((r: any) => r.insights?.vibe === fresh.vibe);
  const people = new Set(agreeing.map((r: any) => r.userId));
  if (people.size < 2) return;
  for (const r of agreeing) if (r.status !== "verified") await ctx.db.patch(r._id, { status: "verified" });
  await ctx.db.patch(placeRowId, { insights: { ...fresh, source: "verified" }, updatedAt: Date.now() });
}

/** The explorer's adventure history, newest first, with photo URLs. */
export const myCheckins = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, { limit }) => {
    const userId = await requireUser(ctx);
    const rows = await ctx.db
      .query("checkins")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .take(Math.min(limit ?? 100, 500));
    return await Promise.all(
      rows.map(async (r) => ({
        ...r,
        photoUrl: r.photoStorageId ? await ctx.storage.getUrl(r.photoStorageId) : null,
        selfieUrl: r.selfieStorageId ? await ctx.storage.getUrl(r.selfieStorageId) : null,
      })),
    );
  },
});

export const myContributions = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    return await ctx.db
      .query("contributions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .take(200);
  },
});
