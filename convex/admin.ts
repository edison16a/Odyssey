// Maintenance, run from the CLI only (internal functions are not callable by the app):
//
//   npx convex run admin:removeUsersByEmailPrefix '{"prefix":"smoketest+"}'

import { internalMutation } from "./_generated/server";
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";

const OWNED = ["profiles", "userState", "checkins", "contributions", "tasteEvents", "taste", "recommendations", "posts",
  "friendships", "savedPlaces", "giftCards"] as const;

/** Delete every trace of the accounts whose email starts with `prefix`, and undo their place credit. */
export const removeUsersByEmailPrefix = internalMutation({
  args: { prefix: v.string() },
  handler: async (ctx, { prefix }) => {
    if (prefix.length < 4) throw new Error("Prefix too short");
    const users = (await ctx.db.query("users").collect()).filter((u) => u.email?.startsWith(prefix));
    const removed: string[] = [];
    for (const user of users) {
      const userId = user._id as Id<"users">;
      const checkins = await ctx.db.query("checkins").withIndex("by_user", (q) => q.eq("userId", userId)).collect();
      for (const placeId of new Set(checkins.map((c) => c.placeId))) {
        const place = await ctx.db.query("places").withIndex("by_placeId", (q) => q.eq("placeId", placeId)).unique();
        if (!place) continue;
        await ctx.db.patch(place._id, {
          explorerCount: Math.max(0, place.explorerCount - 1),
          ...(place.firstExplorerId === userId ? { firstExplorerId: undefined, firstExploredAt: undefined } : {}),
        });
      }
      for (const table of OWNED) {
        const rows = await (ctx.db.query(table as any) as any).withIndex("by_user", (q: any) => q.eq("userId", userId)).collect();
        for (const row of rows) {
          for (const key of ["photoStorageId", "selfieStorageId", "videoStorageId", "avatarStorageId"]) {
            if (row[key]) await ctx.storage.delete(row[key]).catch(() => {});
          }
          await ctx.db.delete(row._id);
        }
      }
      const bounties = await ctx.db.query("bounties").withIndex("by_owner", (q) => q.eq("ownerId", userId)).collect();
      for (const b of bounties) await ctx.db.delete(b._id);
      const likes = await ctx.db.query("likes").withIndex("by_user_post", (q) => q.eq("userId", userId)).collect();
      for (const l of likes) await ctx.db.delete(l._id);
      const media = await ctx.db.query("media").withIndex("by_owner", (q) => q.eq("ownerId", userId)).collect();
      for (const m of media) { await ctx.storage.delete(m.storageId).catch(() => {}); await ctx.db.delete(m._id); }
      for (const table of ["authAccounts", "authSessions"] as const) {
        const rows = await ctx.db.query(table).filter((q) => q.eq(q.field("userId"), userId)).collect();
        for (const row of rows) await ctx.db.delete(row._id);
      }
      await ctx.db.delete(userId);
      removed.push(user.email ?? userId);
    }
    return { removed };
  },
});

/** Delete bounties whose owner account no longer exists. */
export const removeOrphanBounties = internalMutation({
  args: {},
  handler: async (ctx) => {
    let removed = 0;
    for (const b of await ctx.db.query("bounties").collect()) {
      if (b.ownerId && !(await ctx.db.get(b.ownerId))) { await ctx.db.delete(b._id); removed++; }
    }
    return { removed };
  },
});
