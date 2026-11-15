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

import { bountyQuote, normalizeBounty, expiryFor, paymentMatches } from "./bountyRules";
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
  return { account: plan.account_id ?? plan.account?.id ?? plan.company?.id, product: plan.product_id ?? plan.product?.id };
}

export const quote = query({
  args: { pool: v.number() },
  handler: async (_ctx, { pool }) => ({ ...bountyQuote(pool), sandbox: process.env.WHOP_ENVIRONMENT !== "production" }),
});

export const createBountyCheckout = action({
  args: { bounty: v.any() },
  handler: async (ctx, { bounty }): Promise<{ bountyId: string; checkoutId: string; url: string; amount: number; sandbox: boolean }> => {
    const ownerId = await getAuthUserId(ctx);
    if (!ownerId) throw new Error("Not signed in");
    const data = normalizeBounty(bounty);
    const requestId = typeof bounty.id === "string" && bounty.id !== "draft" && bounty.id.length <= 120 ? bounty.id : crypto.randomUUID();
    const { account, product } = await accountAndProduct();
    if (!account || !product) throw new Error("Whop plan is missing an account or product");
    const sandbox = process.env.WHOP_ENVIRONMENT !== "production";
    const row = await ctx.runMutation(internal.whop.reserveCheckout, { ownerId, requestId, data, accountId: account, sandbox });
    if (row.checkoutUrl) return { bountyId: row.bountyId, checkoutId: row.checkoutId, url: row.checkoutUrl, amount: row.amount, sandbox: row.sandbox ?? sandbox };
    const site = process.env.CONVEX_SITE_URL ?? "https://impressive-mosquito-265.convex.site";
    const checkout = await whop("/checkout_configurations", {
      method: "POST",
      // One key for retries, including a timeout after Whop created the checkout.
      headers: { "Idempotency-Key": `odyssey-bounty-${row.bountyId}` },
      body: JSON.stringify({
        account_id: account,
        variant: {
          account_id: account, product_id: product, initial_price: row.amount,
          billing_type: "one_time", currency: "usd", visibility: "hidden",
          title: `$${data.pool} bounty · ${data.sponsor.slice(0, 40)}`,
        },
        metadata: { bountyId: row.bountyId, app: "odyssey" },
        redirect_url: `${site}/whop/return?bounty=${row.bountyId}`,
      }),
    });
    if (!checkout.id || !checkout.purchase_url || !String(checkout.purchase_url).startsWith("https://")) throw new Error("Whop did not return a secure checkout");
    await ctx.runMutation(internal.whop.attachCheckout, { bountyId: row.bountyId, checkoutId: checkout.id, checkoutUrl: checkout.purchase_url });
    return { bountyId: row.bountyId, checkoutId: checkout.id, url: checkout.purchase_url, amount: row.amount, sandbox };
  },
});

/** Reserve first, atomically: concurrent requests for the same draft share one pending row. */
export const reserveCheckout = internalMutation({
  args: { ownerId: v.id("users"), requestId: v.string(), data: v.any(), accountId: v.string(), sandbox: v.boolean() },
  handler: async (ctx, a) => {
    const prior = await ctx.db.query("bountyCheckouts").withIndex("by_owner_request", (q) => q.eq("ownerId", a.ownerId).eq("requestId", a.requestId)).unique();
    const data = normalizeBounty(a.data);
    if (prior) {
      if (JSON.stringify(normalizeBounty(prior.data)) !== JSON.stringify(data)) throw new Error("This checkout already belongs to a different bounty. Start a new draft.");
      return prior;
    }
    const bountyId = `b-${crypto.randomUUID()}`;
    const id = await ctx.db.insert("bountyCheckouts", {
      ownerId: a.ownerId, requestId: a.requestId, accountId: a.accountId, sandbox: a.sandbox,
      bountyId, checkoutId: "", data: { ...data, id: bountyId }, amount: data.totalAmount,
      status: "pending", createdAt: Date.now(), durationDays: data.durationDays,
      maxExplorers: data.maxExplorers, targetType: data.target.kind, center: data.center,
      radius: data.radius, pool: data.pool, platformFee: data.platformFee, totalAmount: data.totalAmount,
    });
    return (await ctx.db.get(id))!;
  },
});

export const attachCheckout = internalMutation({
  args: { bountyId: v.string(), checkoutId: v.string(), checkoutUrl: v.string() },
  handler: async (ctx, a) => {
    const row = await ctx.db.query("bountyCheckouts").withIndex("by_bountyId", (q) => q.eq("bountyId", a.bountyId)).unique();
    if (!row) throw new Error("Pending bounty is missing");
    if (row.checkoutId && row.checkoutId !== a.checkoutId) throw new Error("Checkout already attached");
    await ctx.db.patch(row._id, { checkoutId: a.checkoutId, checkoutUrl: a.checkoutUrl });
  },
});

/** Payment and webhook receipt commit together; delivery retries cannot duplicate publication. */
export const markPaid = internalMutation({
  args: { bountyId: v.string(), payment: v.any(), webhookId: v.optional(v.string()) },
  handler: async (ctx, { bountyId, payment, webhookId }) => {
    if (webhookId && await ctx.db.query("whopEvents").withIndex("by_webhookId", (q) => q.eq("webhookId", webhookId)).unique()) return { ok: true };
    const row = await ctx.db.query("bountyCheckouts").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique();
    if (!row || !paymentMatches(payment, row)) return { ok: false };
    const used = await ctx.db.query("bountyCheckouts").withIndex("by_paymentId", (q) => q.eq("paymentId", payment.id)).collect();
    if (used.some((other) => other.bountyId !== bountyId)) throw new Error("Payment already applied to another bounty");
    if (row.status === "paid" && row.paymentId && row.paymentId !== payment.id) throw new Error("Bounty already funded by another payment");
    const startedAt = row.paidAt ?? Date.now();
    const expiresAt = expiryFor(row.data, startedAt);
    if (row.status !== "paid") await ctx.db.patch(row._id, { status: "paid", paymentId: payment.id, paidAt: startedAt });
    const live = await ctx.db.query("bounties").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique();
    if (!live) {
      await ctx.db.insert("bounties", {
        ownerId: row.ownerId as Id<"users"> | undefined, bountyId,
        data: { ...row.data, paidWith: "whop", paymentId: payment.id, expiresAt },
        active: true, createdAt: startedAt, expiresAt,
        durationDays: row.durationDays, maxExplorers: row.maxExplorers, targetType: row.targetType,
        center: row.center, radius: row.radius, pool: row.pool,
        platformFee: row.platformFee, totalAmount: row.totalAmount,
      });
    }
    if (webhookId) await ctx.db.insert("whopEvents", { webhookId, type: "payment.succeeded", at: Date.now() });
    return { ok: true };
  },
});

export const pending = internalQuery({
  args: { bountyId: v.string() },
  handler: async (ctx, { bountyId }) =>
    await ctx.db.query("bountyCheckouts").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique(),
});

export const bountyStatus = query({
  args: { bountyId: v.string() },
  handler: async (ctx, { bountyId }) => {
    const ownerId = await getAuthUserId(ctx);
    if (!ownerId) throw new Error("Not signed in");
    const row = await ctx.db.query("bountyCheckouts").withIndex("by_bountyId", (q) => q.eq("bountyId", bountyId)).unique();
    if (!row || (row.ownerId && row.ownerId !== ownerId)) return { status: "missing", bounty: null };
    return { status: row.status, bounty: row.status === "paid" ? {
      ...row.data, paidWith: "whop", expiresAt: expiryFor(row.data, row.paidAt ?? row.createdAt),
    } : null };
  },
});

/** Page through recent receipts and verify the target checkout server-side. */
export const syncBounty = action({
  args: { bountyId: v.string() },
  handler: async (ctx, { bountyId }): Promise<{ status: string }> => {
    const ownerId = await getAuthUserId(ctx);
    if (!ownerId) throw new Error("Not signed in");
    const row = await ctx.runQuery(internal.whop.pending, { bountyId });
    if (!row || (row.ownerId && row.ownerId !== ownerId)) return { status: "missing" };
    if (row.status === "paid") return { status: "paid" };
    if (!row.checkoutId) return { status: "pending" };
    const { account } = await accountAndProduct();
    const params = new URLSearchParams({
      account_id: account, first: "100", order: "created_at", direction: "desc",
      created_after: new Date(row.createdAt - 300_000).toISOString(),
    });
    // Limit each sync request. The signed webhook remains the primary confirmation path.
    for (let page = 0; page < 10; page++) {
      const list = await whop(`/payments?${params}`);
      for (const candidate of list.data ?? []) {
        if (!candidate.id) continue;
        const candidateBounty = candidate.metadata?.bountyId ?? candidate.membership?.metadata?.bountyId;
        const candidateCheckout = candidate.checkout_configuration_id ?? candidate.checkout_configuration?.id;
        if (candidateBounty !== bountyId && candidateCheckout !== row.checkoutId) continue;
        const payment = await whop(`/payments/${encodeURIComponent(candidate.id)}`);
        if (!paymentMatches(payment, row)) continue;
        const result = await ctx.runMutation(internal.whop.markPaid, { bountyId, payment });
        if (result.ok) return { status: "paid" };
      }
      if (!list.page_info?.has_next_page || !list.page_info?.end_cursor) break;
      params.set("after", list.page_info.end_cursor);
    }
    return { status: "pending" };
  },
});

export const eventSeen = internalQuery({
  args: { webhookId: v.string() },
  handler: async (ctx, { webhookId }) => !!await ctx.db.query("whopEvents").withIndex("by_webhookId", (q) => q.eq("webhookId", webhookId)).unique(),
});

export const seenEvent = internalMutation({
  args: { webhookId: v.string(), type: v.string() },
  handler: async (ctx, { webhookId, type }) => {
    if (!await ctx.db.query("whopEvents").withIndex("by_webhookId", (q) => q.eq("webhookId", webhookId)).unique()) {
      await ctx.db.insert("whopEvents", { webhookId, type, at: Date.now() });
    }
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
  if (!Number.isFinite(Number(ts)) || Math.abs(Date.now() / 1000 - Number(ts)) > 300) return false;
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
  if (await ctx.runQuery(internal.whop.eventSeen, { webhookId })) return new Response("ok");
  if (event?.type === "payment.succeeded") {
    const eventPayment = event.data ?? {};
    if (!eventPayment.id) return new Response("Missing payment", { status: 400 });
    // Retrieve canonical amount, account, metadata and checkout ID, even if the event is sparse.
    const payment = await whop(`/payments/${encodeURIComponent(eventPayment.id)}`);
    const bountyId = payment?.metadata?.bountyId ?? payment?.membership?.metadata?.bountyId;
    if (bountyId) {
      const result = await ctx.runMutation(internal.whop.markPaid, { bountyId: String(bountyId), payment, webhookId });
      if (!result.ok) return new Response("Payment could not be matched to a pending bounty", { status: 409 });
    } else {
      await ctx.runMutation(internal.whop.seenEvent, { webhookId, type: String(event.type) });
    }
  } else {
    await ctx.runMutation(internal.whop.seenEvent, { webhookId, type: String(event?.type ?? "") });
  }
  return new Response("ok");
});

/** Where Whop's checkout lands after paying: hands the explorer back to the app. */
export const returnPage = httpAction(async (_ctx, req) => {
  const bounty = new URL(req.url).searchParams.get("bounty") ?? "";
  const back = `odyssey://bounty-paid/${encodeURIComponent(bounty)}`;
  const html = `<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>Bounty paid</title>
<body style="font-family:-apple-system,system-ui;text-align:center;padding:64px 24px;color:#111">
<h2>Return to Odyssey</h2><p>Odyssey will check your payment status. Your bounty appears after payment is verified.</p>
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
