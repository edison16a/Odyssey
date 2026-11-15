// Find friends from your contacts, without ever sending the address book.
//
// The phone normalizes each contact's phone numbers (digits only, last 10)
// and emails (trimmed, lowercased), hashes them with SHA-256 on device and
// sends only the hashes. Each explorer's own phone and email are hashed the
// same way into `contactKeys`, so a lookup is an index hit on the hash.
// Nothing the phone sends is stored.

import { internalMutation, mutation, query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { v } from "convex/values";
import { requireUser } from "./lib";

const MAX_HASHES = 1000;

function normalizePhone(raw: string): string | null {
  const digits = raw.replace(/\D/g, "");
  if (digits.length < 7) return null;
  return digits.length > 10 ? digits.slice(-10) : digits;
}

function normalizeEmail(raw: string): string | null {
  const email = raw.trim().toLowerCase();
  return email.includes("@") ? email : null;
}

async function sha256(text: string): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** Rewrite one explorer's keys from their account and profile. Returns how many keys they have. */
async function refreshKeys(ctx: MutationCtx, userId: Id<"users">): Promise<number> {
  const user = await ctx.db.get(userId);
  const profile = await ctx.db.query("profiles").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
  const wanted = new Map<string, string>();
  for (const raw of [user?.phone, user?.email, profile?.email]) {
    if (!raw) continue;
    // Text-in sign-ins from a sender that is not a "+" number keep it in `email`.
    const email = raw.includes("@") ? normalizeEmail(raw) : null;
    const phone = email ? null : normalizePhone(raw);
    if (email) wanted.set(await sha256(email), "email");
    if (phone) wanted.set(await sha256(phone), "phone");
  }
  const existing = await ctx.db.query("contactKeys").withIndex("by_user", (q) => q.eq("userId", userId)).collect();
  let kept = 0;
  for (const row of existing) {
    if (wanted.has(row.hash)) {
      wanted.delete(row.hash);
      kept++;
    } else {
      await ctx.db.delete(row._id);
    }
  }
  for (const [hash, kind] of wanted) await ctx.db.insert("contactKeys", { userId, hash, kind });
  return kept + wanted.size;
}

/** Make the signed-in explorer findable by friends who have their phone or email. */
export const registerMine = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    return { keys: await refreshKeys(ctx, userId) };
  },
});

/** Fill keys for every explorer with a profile (run once after deploying). */
export const backfill = internalMutation({
  args: {},
  handler: async (ctx) => {
    let explorers = 0;
    let keys = 0;
    for (const p of await ctx.db.query("profiles").collect()) {
      const n = await refreshKeys(ctx, p.userId);
      if (n > 0) explorers++;
      keys += n;
    }
    return { explorers, keys };
  },
});

/**
 * Which of these hashed contacts are on Odyssey. Returns one entry per
 * explorer (never yourself) with the hashes that matched, so the phone can
 * tell which contact it was.
 */
export const match = query({
  args: { hashes: v.array(v.string()) },
  handler: async (ctx, { hashes }) => {
    const me = await requireUser(ctx);
    const unique = [...new Set(hashes.map((h) => h.toLowerCase()).filter((h) => /^[0-9a-f]{64}$/.test(h)))].slice(0, MAX_HASHES);
    const byUser = new Map<Id<"users">, string[]>();
    for (const hash of unique) {
      const rows = await ctx.db.query("contactKeys").withIndex("by_hash", (q) => q.eq("hash", hash)).collect();
      for (const row of rows) {
        if (row.userId === me) continue;
        byUser.set(row.userId, [...(byUser.get(row.userId) ?? []), hash]);
      }
    }
    const out = [];
    for (const [userId, matched] of byUser) {
      const profile = await ctx.db.query("profiles").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
      if (!profile) continue;
      out.push({
        userId,
        demoId: profile.demoId ?? null,
        name: profile.name,
        handle: profile.handle,
        city: profile.city,
        avatarPath: profile.avatarPath ?? null,
        avatarUrl: profile.avatarStorageId ? await ctx.storage.getUrl(profile.avatarStorageId) : null,
        hashes: matched,
      });
    }
    return out;
  },
});
