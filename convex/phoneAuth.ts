// Sign in by texting a code to Odyssey's iMessage line (run by Keiki).
//
// 1. The app calls phoneAuth:start and gets a short code ("482913") plus a
//    secret nonce that only the app knows.
// 2. The user texts the code to the line. Keiki's agent calls its
//    confirm_odyssey_signin tool, which POSTs { code, phone } to
//    /phone-auth/confirm with a shared secret. The phone number comes from
//    Keiki (who actually sent the text), never from the model.
// 3. The app polls phoneAuth:status with its nonce. Once confirmed it calls
//    auth:signIn with { provider: "phone-text", params: { nonce } }, which
//    signs in (or creates) the account for that phone number.
//
// The code alone is useless without the nonce, and each login can be used once.

import { httpAction, internalMutation, mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

const TTL_MS = 10 * 60_000;

function randomDigits(n: number): string {
  const bytes = new Uint32Array(n);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => (b % 10).toString()).join("");
}

function randomHex(bytes: number): string {
  const a = new Uint8Array(bytes);
  crypto.getRandomValues(a);
  return Array.from(a, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** Start a text-in sign-in: returns the code to text and the nonce to keep. */
export const start = mutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    let code = randomDigits(6);
    for (let i = 0; i < 5; i++) {
      const clash = await ctx.db.query("phoneLogins").withIndex("by_code", (q) => q.eq("code", code)).first();
      if (!clash || clash.expiresAt < now) break;
      code = randomDigits(6);
    }
    const nonce = randomHex(24);
    const expiresAt = now + TTL_MS;
    await ctx.db.insert("phoneLogins", { code, nonce, status: "pending", expiresAt, createdAt: now });
    return { code, nonce, expiresAt, line: process.env.ODYSSEY_TEXT_LINE ?? null };
  },
});

/** Where a text-in sign-in stands: pending, confirmed, used or expired. */
export const status = query({
  args: { nonce: v.string() },
  handler: async (ctx, { nonce }) => {
    const row = await ctx.db.query("phoneLogins").withIndex("by_nonce", (q) => q.eq("nonce", nonce)).unique();
    if (!row) return { state: "expired" as const };
    if (row.status === "pending" && row.expiresAt < Date.now()) return { state: "expired" as const };
    return { state: row.status as "pending" | "confirmed" | "used" };
  },
});

/** Mark a pending code as texted from `phone`. */
export const confirm = internalMutation({
  args: { code: v.string(), phone: v.string() },
  handler: async (ctx, { code, phone }) => {
    const now = Date.now();
    const rows = await ctx.db.query("phoneLogins").withIndex("by_code", (q) => q.eq("code", code)).collect();
    const row = rows.find((r) => r.status === "pending" && r.expiresAt >= now);
    if (!row) return { ok: false, message: "That code is not valid or has expired. Start again in the Odyssey app." };
    await ctx.db.patch(row._id, { status: "confirmed", phone, confirmedAt: now });
    return { ok: true, message: "Signed in. Head back to the Odyssey app." };
  },
});

/** Used by the phone-text provider: trade a confirmed nonce for its phone number, once. */
export const consume = internalMutation({
  args: { nonce: v.string() },
  handler: async (ctx, { nonce }) => {
    const row = await ctx.db.query("phoneLogins").withIndex("by_nonce", (q) => q.eq("nonce", nonce)).unique();
    if (!row || row.status !== "confirmed" || !row.phone) return null;
    if (row.expiresAt + TTL_MS < Date.now()) return null;
    await ctx.db.patch(row._id, { status: "used" });
    return row.phone;
  },
});

/** Keiki's tool calls this. Needs `Authorization: Bearer <KEIKI_TOOL_SECRET>`. */
export const confirmHttp = httpAction(async (ctx, req) => {
  const secret = process.env.KEIKI_TOOL_SECRET;
  const auth = req.headers.get("Authorization") ?? "";
  if (!secret || auth !== `Bearer ${secret}`) return new Response("Unauthorized", { status: 401 });
  let body: { code?: unknown; phone?: unknown };
  try { body = await req.json(); } catch { return new Response("Bad JSON", { status: 400 }); }
  const code = String(body.code ?? "").replace(/\D/g, "");
  const phone = String(body.phone ?? "").trim();
  if (code.length !== 6 || !phone) {
    return Response.json({ ok: false, message: "Send the 6 digit code shown in the Odyssey app." });
  }
  const result = await ctx.runMutation(internal.phoneAuth.confirm, { code, phone });
  return Response.json(result);
});


