import { getAuthUserId } from "@convex-dev/auth/server";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import type { Doc, Id } from "./_generated/dataModel";

/** The signed-in explorer, or an error for anonymous calls. */
export async function requireUser(ctx: QueryCtx | MutationCtx): Promise<Id<"users">> {
  const userId = await getAuthUserId(ctx);
  if (userId === null) throw new Error("Not signed in");
  return userId;
}

export async function profileOf(ctx: QueryCtx | MutationCtx, userId: Id<"users">): Promise<Doc<"profiles"> | null> {
  return await ctx.db
    .query("profiles")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .unique();
}

export async function requireProfile(ctx: QueryCtx | MutationCtx, userId: Id<"users">): Promise<Doc<"profiles">> {
  const profile = await profileOf(ctx, userId);
  if (!profile) throw new Error("Profile missing: call users:bootstrap after signing in");
  return profile;
}

export async function placeByPlaceId(ctx: QueryCtx | MutationCtx, placeId: string): Promise<Doc<"places"> | null> {
  return await ctx.db
    .query("places")
    .withIndex("by_placeId", (q) => q.eq("placeId", placeId))
    .unique();
}

/** The Supermemory namespace for one explorer. One per user, never shared. */
export function namespaceFor(userId: Id<"users">): string {
  return `odyssey_user_${userId}`;
}

export function today(): string {
  return new Date().toISOString().slice(0, 10);
}
