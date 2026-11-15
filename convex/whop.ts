// Bounties paid through Whop (sandbox).
//
// 1. The app calls whop:createBountyCheckout with the bounty it built. We make
//    a Whop checkout configuration priced at the pool plus Odyssey's 10% fee,
//    with the bountyId in its metadata, and keep the bounty as pending.
// 2. The app opens the checkout's purchase_url. The explorer pays with a
//    sandbox card (4242 4242 4242 4242).
// 3. Whop calls POST /whop with payment.succeeded. We check the Standard
//    Webhooks signature, find the bounty by its metadata and push it live.
// 4. The app watches whop:bountyStatus. If the webhook is slow it can call
//    whop:syncBounty, which asks Whop's API for the payment directly.
//
// Env: WHOP_API_KEY, WHOP_WEBHOOK_SECRET, WHOP_ENVIRONMENT ("sandbox"), WHOP_PLAN_ID.

import { action, httpAction, internalMutation, internalQuery, query } from "./_generated/server";
import { getAuthUserId } from "@convex-dev/auth/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";

const FEE = 0.1;
const API_VERSION = "2026-11-14-1";

function apiBase(): string {
  return process.env.WHOP_ENVIRONMENT === "production" ? "https://api.whop.com/api/v1" : "https://sandbox-api.whop.com/api/v1";
}

async function whop(path: string, init: RequestInit = {}): Promise<any> {
  const key = process.env.WHOP_API_KEY;
  if (!key) throw new Error("Whop is not set up (WHOP_API_KEY missing)");
  const res = await fetch(apiBase() + path, {
    ...init,
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json", "Api-Version-Date": API_VERSION, ...(init.headers ?? {}) },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body?.error?.message ?? `Whop answered ${res.status}`);
  return body;
}

/** The Whop account and product the bounty variants are created under, read from WHOP_PLAN_ID. */
async function accountAndProduct(): Promise<{ account: string; product: string }> {
  const planId = process.env.WHOP_PLAN_ID;
  if (!planId) throw new Error("Whop is not set up (WHOP_PLAN_ID missing)");
  const plan = await whop(`/plans/${planId}`);
  return { account: plan.account?.id ?? plan.company?.id, product: plan.product?.id };
}

export const createBountyCheckout = action({
  args: { bounty: v.any() },
  handler: async (ctx, { bounty }): Promise<{ bountyId: string; checkoutId: string; url: string; amount: number }> => {
    const ownerId = (await getAuthUserId(ctx)) ?? undefined;
    const pool = Number(bounty?.pool ?? 0);
    if (!(pool >= 5 && pool <= 5000)) throw new Error("Pick a bounty between $5 and $5,000");
    const amount = Math.round(pool * (1 + FEE) * 100) / 100;
    const bountyId = `b-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
    const { account, product } = await accountAndProduct();
    const site = process.env.CONVEX_SITE_URL ?? "https://impressive-mosquito-265.convex.site";
    const checkout = await whop("/checkout_configurations", {
      method: "POST",
      body: JSON.stringify({
        account_id: account,
        variant: {
          account_id: account,
          product_id: product,
          initial_price: amount,
          billing_type: "one_time",
          currency: "usd",
          visibility: "hidden",
          title: `$${pool} bounty · ${String(bounty?.sponsor ?? "Odyssey").slice(0, 40)}`,
        },
        metadata: { bountyId, app: "odyssey" },
        redirect_url: `${site}/whop/return?bounty=${bountyId}`,
      }),
    });
    const data = { ...bounty, id: bountyId, recorded: 0, crew: [], mine: undefined };
    await ctx.runMutation(internal.whop.savePending, { bountyId, checkoutId: checkout.id, ownerId, data, amount });
    return { bountyId, checkoutId: checkout.id, url: checkout.purchase_url, amount };
  },
});

export const savePending = internalMutation({
  args: { bountyId: v.string(), checkoutId: v.string(), ownerId: v.optional(v.id("users")), data: v.any(), amount: v.number() },
  handler: async (ctx, a) => {
    await ctx.db.insert("bountyCheckouts", { ...a, status: "pending", createdAt: Date.now() });
  },
});

/** Mark a bounty paid and push it live. Safe to call more than once. */
export const markPaid = internalMutation({
  args: { bountyId: v.string(), paymentId: v.optional(v.string()) },
  handler: async (ctx, { bountyId, paymentId }) => {
    const row = await ctx.db.query("bountyCheckouts").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique();
    if (!row) return { ok: false };
    if (row.status !== "paid") await ctx.db.patch(row._id, { status: "paid", paymentId, paidAt: Date.now() });
    const live = await ctx.db.query("bounties").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique();
    if (!live) {
      await ctx.db.insert("bounties", {
        ownerId: row.ownerId as Id<"users"> | undefined,
        bountyId,
        data: { ...row.data, paidWith: "whop", paymentId },
        active: true,
        createdAt: Date.now(),
      });
    }
    return { ok: true };
  },
});

export const pending = internalQuery({
  args: { bountyId: v.string() },
  handler: async (ctx, { bountyId }) =>
    await ctx.db.query("bountyCheckouts").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique(),
});

/** "pending", "paid" or "missing", for the app to watch while checkout is open. */
export const bountyStatus = query({
  args: { bountyId: v.string() },
  handler: async (ctx, { bountyId }) => {
    const row = await ctx.db.query("bountyCheckouts").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique();
    return { status: row?.status ?? "missing", paymentId: row?.paymentId ?? null };
  },
});

/** Ask Whop directly whether the bounty's checkout was paid (when the webhook has not arrived yet). */
export const syncBounty = action({
  args: { bountyId: v.string() },
  handler: async (ctx, { bountyId }): Promise<{ status: string }> => {
    const row = await ctx.runQuery(internal.whop.pending, { bountyId });
    if (!row) return { status: "missing" };
    if (row.status === "paid") return { status: "paid" };
    const { account } = await accountAndProduct();
    const list = await whop(`/payments?account_id=${account}&first=25`);
    const hit = (list.data ?? []).find((p: any) =>
      p?.metadata?.bountyId === bountyId &&
      ["paid", "succeeded"].includes(String(p?.status ?? p?.substatus ?? "").toLowerCase()));
    if (!hit) return { status: "pending" };
    await ctx.runMutation(internal.whop.markPaid, { bountyId, paymentId: hit.id });
    return { status: "paid" };
  },
});

export const seenEvent = internalMutation({
  args: { webhookId: v.string(), type: v.string() },
  handler: async (ctx, { webhookId, type }) => {
    const prior = await ctx.db.query("whopEvents").withIndex("by_webhookId", (q) => q.eq("webhookId", webhookId)).first();
    if (prior) return true;
    await ctx.db.insert("whopEvents", { webhookId, type, at: Date.now() });
    return false;
  },
});

// ── Webhook ─────────────────────────────────────────────────────────────

function b64(bytes: ArrayBuffer): string {
  let s = "";
  for (const b of new Uint8Array(bytes)) s += String.fromCharCode(b);
  return btoa(s);
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Key candidates for the ws_ secret: the string itself, and its body as raw bytes. */
function keyCandidates(secret: string): Uint8Array[] {
  const enc = new TextEncoder();
  const out: Uint8Array[] = [enc.encode(secret)];
  const body = secret.replace(/^(ws|whsec)_/, "");
  out.push(enc.encode(body));
  if (/^[0-9a-f]+$/i.test(body) && body.length % 2 === 0) {
    out.push(new Uint8Array(body.match(/../g)!.map((h) => parseInt(h, 16))));
  }
  try {
    out.push(Uint8Array.from(atob(body), (c) => c.charCodeAt(0)));
  } catch {}
  return out;
}

async function verify(req: Request, raw: string): Promise<boolean> {
  const secret = process.env.WHOP_WEBHOOK_SECRET;
  const id = req.headers.get("webhook-id");
  const ts = req.headers.get("webhook-timestamp");
  const sigs = (req.headers.get("webhook-signature") ?? "").split(" ").map((s) => s.split(",")[1]).filter(Boolean);
  if (!secret || !id || !ts || sigs.length === 0) return false;
  if (Math.abs(Date.now() / 1000 - Number(ts)) > 300) return false;
  const signed = new TextEncoder().encode(`${id}.${ts}.${raw}`);
  for (const keyBytes of keyCandidates(secret)) {
    const key = await crypto.subtle.importKey("raw", keyBytes as BufferSource, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    const mac = b64(await crypto.subtle.sign("HMAC", key, signed));
    if (sigs.some((s) => safeEqual(s, mac))) return true;
  }
  return false;
}

export const webhook = httpAction(async (ctx, req) => {
  const raw = await req.text();
  if (!(await verify(req, raw))) return new Response("Bad signature", { status: 401 });
  let event: any;
  try { event = JSON.parse(raw); } catch { return new Response("Bad JSON", { status: 400 }); }
  const webhookId = req.headers.get("webhook-id")!;
  if (await ctx.runMutation(internal.whop.seenEvent, { webhookId, type: String(event?.type ?? "") })) {
    return new Response("ok");
  }
  if (event?.type === "payment.succeeded") {
    const payment = event.data ?? {};
    const bountyId = payment?.metadata?.bountyId ?? payment?.membership?.metadata?.bountyId;
    if (bountyId) await ctx.runMutation(internal.whop.markPaid, { bountyId: String(bountyId), paymentId: payment.id });
  }
  return new Response("ok");
});

/** Where Whop's checkout lands after paying: hands the explorer back to the app. */
export const returnPage = httpAction(async (_ctx, req) => {
  const bounty = new URL(req.url).searchParams.get("bounty") ?? "";
  const back = `odyssey://bounty-paid/${encodeURIComponent(bounty)}`;
  const html = `<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>Bounty paid</title>
<body style="font-family:-apple-system,system-ui;text-align:center;padding:64px 24px;color:#111">
<h2>Payment received</h2><p>Your bounty is going live on the Odyssey map.</p>
<p><a href="${back}" style="display:inline-block;margin-top:16px;padding:14px 26px;border-radius:999px;background:#111;color:#fff;text-decoration:none;font-weight:600">Back to Odyssey</a></p>
<script>setTimeout(function(){location.href=${JSON.stringify(back)}},600)</script></body>`;
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } });
});

/** CLI cleanup: npx convex run whop:removeBounty '{"bountyId":"b-..."}' */
export const removeBounty = internalMutation({
  args: { bountyId: v.string() },
  handler: async (ctx, { bountyId }) => {
    for (const t of ["bounties", "bountyCheckouts"] as const) {
      const rows = await ctx.db.query(t).withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).collect();
      for (const r of rows) await ctx.db.delete(r._id);
    }
  },
});
