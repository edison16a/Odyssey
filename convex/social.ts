// Posts, likes, friends, saved places, bounties and gift cards.

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib";

export const createPost = mutation({
  args: {
    clientId: v.string(),
    placeId: v.string(),
    kind: v.string(),
    caption: v.string(),
    first: v.optional(v.boolean()),
    seconds: v.optional(v.number()),
    photoStorageId: v.optional(v.id("_storage")),
    selfieStorageId: v.optional(v.id("_storage")),
    extra: v.optional(v.any()),
  },
  handler: async (ctx, a) => {
    const userId = await requireUser(ctx);
    const existing = await ctx.db
      .query("posts")
      .withIndex("by_client", (q) => q.eq("userId", userId).eq("clientId", a.clientId))
      .unique();
    if (existing) return existing._id;
    return await ctx.db.insert("posts", {
      userId,
      clientId: a.clientId,
      placeId: a.placeId,
      kind: a.kind,
      caption: a.caption,
      first: a.first ?? false,
      seconds: a.seconds,
      photoStorageId: a.photoStorageId,
      selfieStorageId: a.selfieStorageId,
      likes: 0,
      comments: 0,
      extra: a.extra,
      createdAt: Date.now(),
    });
  },
});

/** Recent posts from you and the explorers you are friends with. */
export const feed = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, { limit }) => {
    const userId = await requireUser(ctx);
    const friends = await ctx.db.query("friendships").withIndex("by_user", (q) => q.eq("userId", userId)).collect();
    const circle = new Set<string>([userId, ...friends.filter((f) => f.status === "friends").map((f) => f.friendKey)]);
    const rows = await ctx.db.query("posts").withIndex("by_created").order("desc").take(400);
    const mine = rows.filter((p) => circle.has(p.userId)).slice(0, Math.min(limit ?? 50, 100));
    return await Promise.all(
      mine.map(async (p) => {
        const profile = await ctx.db.query("profiles").withIndex("by_user", (q) => q.eq("userId", p.userId)).unique();
        return {
          ...p,
          by: profile ? { name: profile.name, handle: profile.handle } : null,
          photoUrl: p.photoStorageId ? await ctx.storage.getUrl(p.photoStorageId) : null,
          selfieUrl: p.selfieStorageId ? await ctx.storage.getUrl(p.selfieStorageId) : null,
        };
      }),
    );
  },
});

/** Like or unlike a post (seed posts are keyed by their seed id). */
export const setLike = mutation({
  args: { postKey: v.string(), on: v.boolean() },
  handler: async (ctx, { postKey, on }) => {
    const userId = await requireUser(ctx);
    const row = await ctx.db
      .query("likes")
      .withIndex("by_user_post", (q) => q.eq("userId", userId).eq("postKey", postKey))
      .unique();
    if (on && !row) await ctx.db.insert("likes", { userId, postKey, createdAt: Date.now() });
    if (!on && row) await ctx.db.delete(row._id);
    const postId = ctx.db.normalizeId("posts", postKey);
    if (postId) {
      const count = (await ctx.db.query("likes").withIndex("by_post", (q) => q.eq("postKey", postKey)).collect()).length;
      await ctx.db.patch(postId, { likes: count });
    }
  },
});

export const setFriend = mutation({
  args: { friendKey: v.string(), status: v.union(v.literal("friends"), v.literal("requested"), v.literal("incoming"), v.literal("none")) },
  handler: async (ctx, { friendKey, status }) => {
    const userId = await requireUser(ctx);
    const row = await ctx.db
      .query("friendships")
      .withIndex("by_user_friend", (q) => q.eq("userId", userId).eq("friendKey", friendKey))
      .unique();
    if (status === "none") {
      if (row) await ctx.db.delete(row._id);
      return;
    }
    if (row) await ctx.db.patch(row._id, { status });
    else await ctx.db.insert("friendships", { userId, friendKey, status, createdAt: Date.now() });
  },
});

export const myFriends = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    return await ctx.db.query("friendships").withIndex("by_user", (q) => q.eq("userId", userId)).collect();
  },
});

export const setSaved = mutation({
  args: { placeId: v.string(), kind: v.string(), on: v.boolean(), place: v.optional(v.any()) },
  handler: async (ctx, { placeId, kind, on, place }) => {
    const userId = await requireUser(ctx);
    const row = await ctx.db
      .query("savedPlaces")
      .withIndex("by_user_place_kind", (q) => q.eq("userId", userId).eq("placeId", placeId).eq("kind", kind))
      .unique();
    if (on && !row) await ctx.db.insert("savedPlaces", { userId, placeId, kind, place: place ?? null, createdAt: Date.now() });
    if (!on && row) await ctx.db.delete(row._id);
  },
});

export const mySaved = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    return await ctx.db.query("savedPlaces").withIndex("by_user", (q) => q.eq("userId", userId)).collect();
  },
});

// ── Bounties ──────────────────────────────────────────────────────────

export const bounties = query({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.db.query("bounties").collect();
    return rows.filter((b) => b.active).map((b) => ({ ...b.data, _owner: b.ownerId ?? null }));
  },
});

export const postBounty = mutation({
  args: { bounty: v.any() },
  handler: async (ctx, { bounty }) => {
    const userId = await requireUser(ctx);
    const bountyId = String(bounty?.id ?? `b-${Date.now()}`);
    const row = await ctx.db.query("bounties").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique();
    if (row) {
      if (row.ownerId !== userId) throw new Error("Not your bounty");
      await ctx.db.patch(row._id, { data: bounty });
      return row._id;
    }
    return await ctx.db.insert("bounties", { ownerId: userId, bountyId, data: bounty, active: true, createdAt: Date.now() });
  },
});

// ── Gift cards ────────────────────────────────────────────────────────

export const redeemGiftCard = mutation({
  args: { brand: v.string(), amount: v.number(), code: v.string(), day: v.string() },
  handler: async (ctx, a) => {
    const userId = await requireUser(ctx);
    return await ctx.db.insert("giftCards", { userId, ...a, createdAt: Date.now() });
  },
});

export const myGiftCards = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    return await ctx.db.query("giftCards").withIndex("by_user", (q) => q.eq("userId", userId)).order("desc").collect();
  },
});
