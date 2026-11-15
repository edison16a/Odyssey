// Explorer profiles and the synced app state.

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { getAuthUserId } from "@convex-dev/auth/server";
import { profileOf, requireProfile, requireUser } from "./lib";

/** The signed-in explorer's profile with photo URL, or null when signed out. */
export const me = query({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) return null;
    const profile = await profileOf(ctx, userId);
    if (!profile) return { userId, profile: null, avatarUrl: null };
    const avatarUrl = profile.avatarStorageId ? await ctx.storage.getUrl(profile.avatarStorageId) : null;
    return { userId, profile, avatarUrl };
  },
});

/**
 * Called right after sign-in. Creates the profile the first time, seeded from
 * what the phone already knows (name, handle, wallet...), and returns it.
 */
export const bootstrap = mutation({
  args: {
    name: v.optional(v.string()),
    handle: v.optional(v.string()),
    city: v.optional(v.string()),
    interests: v.optional(v.array(v.string())),
    onboarded: v.optional(v.boolean()),
    coins: v.optional(v.number()),
    xp: v.optional(v.number()),
    points: v.optional(v.number()),
    cash: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const existing = await profileOf(ctx, userId);
    if (existing) return { created: false, profile: existing };
    const user = await ctx.db.get(userId);
    const email = user?.email;
    const base = (args.handle ?? email?.split("@")[0] ?? "explorer").toLowerCase().replace(/[^a-z0-9_]/g, "");
    let handle = base || "explorer";
    for (let i = 2; await ctx.db.query("profiles").withIndex("by_handle", (q) => q.eq("handle", handle)).first(); i++) {
      handle = `${base}${i}`;
    }
    const id = await ctx.db.insert("profiles", {
      userId,
      email,
      name: args.name ?? (email ? email.split("@")[0] : "Explorer"),
      handle,
      bio: "",
      city: args.city ?? "Berkeley",
      avatarKind: "none",
      interests: args.interests ?? [],
      onboarded: args.onboarded ?? false,
      coins: args.coins ?? 0,
      xp: args.xp ?? 0,
      points: args.points ?? 0,
      cash: args.cash ?? 0,
      streakDays: 0,
      streakBest: 0,
      explored: 0,
      contributions: 0,
      firsts: 0,
      km: 0,
      updatedAt: Date.now(),
    });
    // New explorers start out friends with the demo explorers marked as friends,
    // matching the friend list the app ships with.
    const demo = (await ctx.db.query("profiles").collect()).filter((p) => p.demoId && p.extra?.friend);
    for (const d of demo) {
      await ctx.db.insert("friendships", { userId, friendKey: d.demoId!, status: "friends", createdAt: Date.now() });
    }
    if (args.interests && args.interests.length > 0) {
      await ctx.scheduler.runAfter(0, internal.memory.rememberInterests, { userId, interests: args.interests });
    }
    return { created: true, profile: await ctx.db.get(id) };
  },
});

/** Edit profile fields. Interests also go to Supermemory, so recommendations pick them up. */
export const updateProfile = mutation({
  args: {
    name: v.optional(v.string()),
    handle: v.optional(v.string()),
    bio: v.optional(v.string()),
    city: v.optional(v.string()),
    interests: v.optional(v.array(v.string())),
    onboarded: v.optional(v.boolean()),
    avatarKind: v.optional(v.string()),
    avatarPath: v.optional(v.string()),
    avatarStorageId: v.optional(v.id("_storage")),
  },
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const profile = await requireProfile(ctx, userId);
    const patch: Record<string, unknown> = { updatedAt: Date.now() };
    for (const [key, value] of Object.entries(args)) if (value !== undefined) patch[key] = value;
    if (args.handle && args.handle !== profile.handle) {
      const taken = await ctx.db.query("profiles").withIndex("by_handle", (q) => q.eq("handle", args.handle!)).first();
      if (taken && taken.userId !== userId) throw new Error("That handle is taken");
    }
    await ctx.db.patch(profile._id, patch);
    if (args.interests && args.interests.join() !== profile.interests.join()) {
      await ctx.scheduler.runAfter(0, internal.memory.rememberInterests, { userId, interests: args.interests });
    }
    return await ctx.db.get(profile._id);
  },
});

/**
 * Mirror the phone's wallet, streak and stats onto the profile, so
 * leaderboards and friends see the same numbers the phone shows.
 */
export const syncStats = mutation({
  args: {
    coins: v.number(),
    xp: v.number(),
    points: v.number(),
    cash: v.number(),
    streakDays: v.number(),
    streakBest: v.number(),
    streakLastDay: v.optional(v.string()),
    explored: v.number(),
    contributions: v.number(),
    firsts: v.number(),
    km: v.number(),
  },
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const profile = await requireProfile(ctx, userId);
    await ctx.db.patch(profile._id, { ...args, updatedAt: Date.now() });
  },
});

/** The app's full state snapshot, for restoring on a new phone. */
export const getState = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const row = await ctx.db.query("userState").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
    return row ? { version: row.version, state: row.state, updatedAt: row.updatedAt } : null;
  },
});

export const saveState = mutation({
  args: { version: v.number(), state: v.any() },
  handler: async (ctx, { version, state }) => {
    const userId = await requireUser(ctx);
    const row = await ctx.db.query("userState").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
    const updatedAt = Date.now();
    if (row) await ctx.db.patch(row._id, { version, state, updatedAt });
    else await ctx.db.insert("userState", { userId, version, state, updatedAt });
    return updatedAt;
  },
});

/** Top explorers overall or in one city. */
export const leaderboard = query({
  args: { city: v.optional(v.string()), limit: v.optional(v.number()) },
  handler: async (ctx, { city, limit }) => {
    const n = Math.min(limit ?? 50, 100);
    const rows = city
      ? await ctx.db.query("profiles").withIndex("by_city_xp", (q) => q.eq("city", city)).order("desc").take(n)
      : await ctx.db.query("profiles").withIndex("by_xp").order("desc").take(n);
    return rows.map((p) => ({
      userId: p.userId,
      name: p.name,
      handle: p.handle,
      city: p.city,
      xp: p.xp,
      explored: p.explored,
      contributions: p.contributions,
      firsts: p.firsts,
    }));
  },
});
