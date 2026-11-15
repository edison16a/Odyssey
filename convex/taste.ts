// Taste: every swipe, check-in and walkthrough is a signal.
//
// Each signal does two things:
//  1. Nudges the explorer's feature weights in Convex right away (fast,
//     exact, works offline from Supermemory). Same numbers the phone uses:
//     a vote moves each feature by 0.6, a check-in by 0.18, capped at ±4.
//  2. Is written to the explorer's Supermemory namespace as a plain-English
//     memory, so Supermemory can build a profile ("loves quiet indie cafés,
//     avoids big chains") that the recommender reads back.

import { internalMutation, internalQuery, mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { requireProfile, requireUser } from "./lib";

const STEP = 0.6;
const CAP = 4;
const KIND_STRENGTH: Record<string, number> = { vote: 1, star: 0.6, checkin: 0.3, walkthrough: 0.3, interests: 0 };

async function tasteRow(ctx: MutationCtx, userId: Id<"users">) {
  const row = await ctx.db.query("taste").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
  if (row) return row;
  const id = await ctx.db.insert("taste", { userId, weights: {}, votes: [], updatedAt: Date.now() });
  return (await ctx.db.get(id))!;
}

/** Shared by votes, check-ins and walkthroughs. */
export async function recordTaste(
  ctx: MutationCtx,
  e: {
    userId: Id<"users">;
    placeId: string;
    placeName: string;
    kind: string;
    value: number;
    features: string[];
    city?: string;
    extra?: string;
  },
) {
  const row = await tasteRow(ctx, e.userId);
  const weights = { ...row.weights };
  let votes = row.votes;
  let delta = e.value * (KIND_STRENGTH[e.kind] ?? 0.3);

  if (e.kind === "vote") {
    // A vote replaces the previous vote on the same place (and 0 undoes it).
    const previous = votes.find((x) => x.placeId === e.placeId)?.v ?? 0;
    delta = e.value - previous;
    votes = votes.filter((x) => x.placeId !== e.placeId);
    if (e.value !== 0) {
      votes = [...votes, { placeId: e.placeId, name: e.placeName, v: e.value, features: e.features, at: Date.now() }].slice(-300);
    }
  }
  for (const f of e.features) {
    const key = f.replace(/^[$_]/, "");
    weights[key] = Math.max(-CAP, Math.min(CAP, (weights[key] ?? 0) + STEP * delta));
  }
  await ctx.db.patch(row._id, { weights, votes, updatedAt: Date.now() });

  const eventId = await ctx.db.insert("tasteEvents", {
    userId: e.userId,
    placeId: e.placeId,
    placeName: e.placeName,
    kind: e.kind,
    value: e.value,
    features: e.features,
    city: e.city,
    memoryStatus: "pending",
    createdAt: Date.now(),
  });
  await ctx.scheduler.runAfter(0, internal.memory.rememberEvent, { eventId, extra: e.extra });
  return eventId;
}

/** Thumbs up (1), thumbs down (-1) or undo (0) on a place. */
export const vote = mutation({
  args: {
    placeId: v.string(),
    placeName: v.string(),
    value: v.number(),
    features: v.array(v.string()),
    city: v.optional(v.string()),
  },
  handler: async (ctx, a) => {
    const userId = await requireUser(ctx);
    const profile = await requireProfile(ctx, userId);
    if (![1, 0, -1].includes(a.value)) throw new Error("value must be 1, 0 or -1");
    await recordTaste(ctx, { userId, ...a, kind: "vote", city: a.city ?? profile.city });
  },
});

/** Starring a place is a softer like. */
export const star = mutation({
  args: { placeId: v.string(), placeName: v.string(), on: v.boolean(), features: v.array(v.string()), place: v.optional(v.any()) },
  handler: async (ctx, a) => {
    const userId = await requireUser(ctx);
    const profile = await requireProfile(ctx, userId);
    const existing = await ctx.db
      .query("savedPlaces")
      .withIndex("by_user_place_kind", (q) => q.eq("userId", userId).eq("placeId", a.placeId).eq("kind", "starred"))
      .unique();
    if (a.on && !existing) {
      await ctx.db.insert("savedPlaces", { userId, placeId: a.placeId, kind: "starred", place: a.place ?? null, createdAt: Date.now() });
      await recordTaste(ctx, { userId, placeId: a.placeId, placeName: a.placeName, kind: "star", value: 1, features: a.features, city: profile.city });
    } else if (!a.on && existing) {
      await ctx.db.delete(existing._id);
    }
  },
});

/** What Odyssey has learned, for the "What Odyssey knows about you" page. */
export const mine = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const row = await ctx.db.query("taste").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
    const events = await ctx.db.query("tasteEvents").withIndex("by_user", (q) => q.eq("userId", userId)).order("desc").take(30);
    const lastRec = await ctx.db.query("recommendations").withIndex("by_user", (q) => q.eq("userId", userId)).order("desc").first();
    return {
      weights: row?.weights ?? {},
      votes: row?.votes ?? [],
      recentEvents: events.map((e) => ({ kind: e.kind, value: e.value, placeName: e.placeName, memoryStatus: e.memoryStatus, at: e.createdAt })),
      profileFacts: lastRec?.profileFacts ?? [],
    };
  },
});

/** Start over: clears weights and votes here, and forgets the taste memories in Supermemory. */
export const reset = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const row = await ctx.db.query("taste").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
    if (row) await ctx.db.patch(row._id, { weights: {}, votes: [], updatedAt: Date.now() });
    await ctx.scheduler.runAfter(0, internal.memory.forgetTaste, { userId });
  },
});

// ── Internal, used by memory.ts and recommend.ts ──────────────────────

export const eventById = internalQuery({
  args: { eventId: v.id("tasteEvents") },
  handler: async (ctx, { eventId }) => await ctx.db.get(eventId),
});

export const markEvent = internalMutation({
  args: { eventId: v.id("tasteEvents"), status: v.string(), error: v.optional(v.string()) },
  handler: async (ctx, { eventId, status, error }) => {
    await ctx.db.patch(eventId, { memoryStatus: status, memoryError: error });
  },
});

/** Everything the recommender needs from Convex about one explorer. */
export const contextFor = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const profile = await ctx.db.query("profiles").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
    const row = await ctx.db.query("taste").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
    const checkins = await ctx.db.query("checkins").withIndex("by_user", (q) => q.eq("userId", userId)).order("desc").take(300);
    const recent = await ctx.db.query("recommendations").withIndex("by_user", (q) => q.eq("userId", userId)).order("desc").take(5);
    const shown: Record<string, number> = {};
    for (const r of recent) for (const p of r.picks.slice(0, 6)) shown[p.placeId] = (shown[p.placeId] ?? 0) + 1;
    return {
      city: profile?.city,
      interests: profile?.interests ?? [],
      weights: row?.weights ?? {},
      votes: row?.votes ?? [],
      visited: [...new Set(checkins.map((c) => c.placeId))],
      recentlyShown: shown,
    };
  },
});

export const saveRecommendation = internalMutation({
  args: {
    userId: v.id("users"),
    city: v.optional(v.string()),
    picks: v.array(v.object({ placeId: v.string(), score: v.number(), reason: v.string() })),
    memoriesUsed: v.number(),
    profileFacts: v.array(v.string()),
    usedSupermemory: v.boolean(),
  },
  handler: async (ctx, a) => {
    await ctx.db.insert("recommendations", { ...a, createdAt: Date.now() });
    // Keep the last 20 per explorer.
    const old = await ctx.db.query("recommendations").withIndex("by_user", (q) => q.eq("userId", a.userId)).order("desc").collect();
    for (const r of old.slice(20)) await ctx.db.delete(r._id);
  },
});
