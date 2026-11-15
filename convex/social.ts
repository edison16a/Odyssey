// Posts, likes, friends, saved places, bounties and gift cards.

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib";
import { expiryFor, isBountyActive } from "./bountyRules";

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
    // A friend key is a user id, or a demo explorer's seed id ("nina"): resolve both to user ids.
    const circle = new Set<string>([userId]);
    for (const f of friends) {
      if (f.status !== "friends") continue;
      if (ctx.db.normalizeId("users", f.friendKey)) { circle.add(f.friendKey); continue; }
      const demo = await ctx.db.query("profiles").withIndex("by_demoId", (q) => q.eq("demoId", f.friendKey)).unique();
      if (demo) circle.add(demo.userId);
    }
    const rows = await ctx.db.query("posts").withIndex("by_created").order("desc").take(400);
    const mine = rows.filter((p) => circle.has(p.userId)).slice(0, Math.min(limit ?? 50, 100));
    return await Promise.all(
      mine.map(async (p) => {
        const profile = await ctx.db.query("profiles").withIndex("by_user", (q) => q.eq("userId", p.userId)).unique();
        return {
          ...p,
          by: profile ? { name: profile.name, handle: profile.handle, demoId: profile.demoId ?? null, avatarPath: profile.avatarPath ?? null } : null,
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
    return rows.filter((b) => isBountyActive(b, Date.now())).map((b) => ({
      ...b.data, active: b.active, expiresAt: b.expiresAt ?? b.data.expiresAt ?? expiryFor(b.data, b.createdAt), _owner: b.ownerId ?? null,
    }));
  },
});

/** Canonical owner history also refreshes expiry on bounties saved by older app versions. */
export const myBounties = query({
  args: {},
  handler: async (ctx) => {
    const ownerId = await requireUser(ctx);
    const rows = await ctx.db.query("bounties").withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).collect();
    return rows.map((b) => ({
      ...b.data, mine: true, active: b.active,
      expiresAt: b.expiresAt ?? b.data.expiresAt ?? expiryFor(b.data, b.createdAt),
    }));
  },
});

export const postBounty = mutation({
  args: { bounty: v.any() },
  handler: async (ctx, { bounty }) => {
    await requireUser(ctx);
    throw new Error("Fund your bounty through whop:createBountyCheckout. Only verified payments can publish bounties.");
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

// ── Friends' explorations (the Friends map) ─────────────────────────────

/** Every place each of your friends has explored, for the hexagon map. No posts, no live location. */
export const friendExplorations = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const friends = await ctx.db.query("friendships").withIndex("by_user", (q) => q.eq("userId", userId)).collect();
    const out = [];
    for (const f of friends) {
      if (f.status !== "friends") continue;
      let friendId = ctx.db.normalizeId("users", f.friendKey);
      if (!friendId) {
        const demo = await ctx.db.query("profiles").withIndex("by_demoId", (q) => q.eq("demoId", f.friendKey)).unique();
        friendId = demo?.userId ?? null;
      }
      if (!friendId) continue;
      const profile = await ctx.db.query("profiles").withIndex("by_user", (q) => q.eq("userId", friendId!)).unique();
      const checkins = await ctx.db.query("checkins").withIndex("by_user", (q) => q.eq("userId", friendId!)).collect();
      const places = new Map<string, { placeId: string; name: string; lat?: number; lng?: number; day: string }>();
      for (const c of checkins) {
        if (!places.has(c.placeId)) places.set(c.placeId, { placeId: c.placeId, name: c.placeName, lat: c.lat, lng: c.lng, day: c.day });
      }
      out.push({
        friendKey: f.friendKey,
        userId: friendId,
        name: profile?.name ?? "Explorer",
        handle: profile?.handle ?? "",
        avatarPath: profile?.avatarPath ?? null,
        places: [...places.values()],
      });
    }
    return out;
  },
});
