import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import schema from "../convex/schema";
import { api, internal } from "../convex/_generated/api";
import { bountyQuote, normalizeBounty, expiryFor, isBountyActive, paymentMatches, DAY } from "../convex/bountyRules";

const modules = import.meta.glob("../convex/**/*.{ts,js}");
const center = { lat: 37.8715, lng: -122.273 };
const draft = (overrides: any = {}) => ({
  id: "draft-remote-berkeley", sponsor: "Café owner", title: "Document our café",
  target: { kind: "place", placeId: "cafe-berkeley", name: "Berkeley Café", place: { id: "cafe-berkeley", name: "Berkeley Café", coords: center, photo: "", address: "Berkeley, CA" } },
  center, radius: 120, pool: 100, days: 7, durationDays: 7, maxExplorers: 5,
  ...overrides,
});
const receipt = (row: { bountyId: string; checkoutId: string; amount: number }, overrides: any = {}) => ({
  id: "pay_test", status: "paid", substatus: "succeeded", currency: "usd", account_id: "biz_test",
  total: { amount: row.amount.toFixed(2), currency: "usd" }, refunded_amount: { amount: "0", currency: "usd" },
  checkout_configuration_id: row.checkoutId, metadata: { bountyId: row.bountyId }, ...overrides,
});

afterEach(() => { vi.unstubAllGlobals(); vi.unstubAllEnvs(); vi.useRealTimers(); });

async function pending(overrides: any = {}) {
  const t = convexTest(schema, modules);
  const user = await t.run((ctx) => ctx.db.insert("users", {}));
  const row = await t.mutation(internal.whop.reserveCheckout, {
    ownerId: user, requestId: "request-1", data: draft(overrides), accountId: "biz_test", sandbox: true,
  });
  await t.mutation(internal.whop.attachCheckout, { bountyId: row.bountyId, checkoutId: "ch_test", checkoutUrl: "https://sandbox.whop.com/test" });
  return { t, user, row: { ...row, checkoutId: "ch_test" }, owner: t.withIdentity({ subject: `${user}|session` }) };
}

describe("bounty validation and allocation", () => {
  test("$100 pool costs $110, with server-controlled fee", () => {
    expect(bountyQuote(100)).toEqual({ pool: 100, platformFee: 10, totalAmount: 110 });
    expect(normalizeBounty(draft({ platformFee: 0, totalAmount: 1 }))).toMatchObject({ platformFee: 10, totalAmount: 110, videos: 5 });
  });
  test.each([5, 5.05, 99.99, 5000])("rounds cents and never allocates more than pool %s", (pool) => {
    for (let maximum = 1; maximum <= 20; maximum++) {
      const value = normalizeBounty(draft({ pool, maxExplorers: maximum }));
      expect(Math.round(value.estimatedReward * 100) * maximum).toBeLessThanOrEqual(Math.round(pool * 100));
    }
  });
  test.each([0, 4.99, 5000.01, NaN, Infinity, "100", 10.001])("rejects invalid pool %s", (pool) => {
    expect(() => normalizeBounty(draft({ pool }))).toThrow();
  });
  test.each([0, -1, 21, 2.5, "5", NaN])("rejects invalid explorer limit %s", (maxExplorers) => {
    expect(() => normalizeBounty(draft({ maxExplorers }))).toThrow();
  });
  test.each([1, 7, 14, 30])("persists %s day duration", (durationDays) => {
    const value = normalizeBounty(draft({ durationDays }));
    expect(value.days).toBe(durationDays);
    expect(expiryFor(value, 1000)).toBe(1000 + durationDays * DAY);
  });
  test.each([0, 2, 7.5, "7", -1, 365])("rejects invalid duration %s", (durationDays) => {
    expect(() => normalizeBounty(draft({ durationDays }))).toThrow();
  });
  test("accepts the iOS app's [lat, lng] coordinates", () => {
    const pair = [center.lat, center.lng];
    const value = normalizeBounty(draft({ center: pair, target: { ...draft().target, place: { ...draft().target.place, coords: pair } } }));
    expect(value.center).toEqual(center);
    expect(value.target.place.coords).toEqual(center);
  });
  test.each(["place", "street", "city"])("supports remote %s target without device GPS", (kind) => {
    const value = normalizeBounty(draft({ target: { ...draft().target, kind }, radius: kind === "city" ? 3000 : 120 }));
    expect(value.center).toEqual(center);
    expect(value.target.kind).toBe(kind);
  });
  test.each([
    { center: { lat: 91, lng: 0 } }, { center: { lat: 0, lng: Infinity } },
    { target: { kind: "unknown" } }, { radius: -1 }, { radius: 501 },
    { target: { kind: "place", name: "Café" } },
    { target: { ...draft().target, place: { ...draft().target.place, coords: { lat: 0, lng: 0 } } } },
  ])("rejects invalid location %#", (invalid) => { expect(() => normalizeBounty(draft(invalid))).toThrow(); });
  test("older clients retain 14 days and a valid legacy videos count", () => {
    const value = normalizeBounty(draft({ days: undefined, durationDays: undefined, maxExplorers: undefined, videos: 8 }));
    expect(value).toMatchObject({ durationDays: 14, maxExplorers: 8, videos: 8 });
    expect(expiryFor({ days: 7 }, 0)).toBe(14 * DAY);
  });
});

describe("Convex funding lifecycle", () => {
  test("pending never appears publicly; confirmed payment publishes all selected fields", async () => {
    const { t, row, owner } = await pending();
    expect(await t.query(api.social.bounties)).toEqual([]);
    expect(await owner.query(api.whop.bountyStatus, { bountyId: row.bountyId })).toMatchObject({ status: "pending", bounty: null });
    expect(await t.mutation(internal.whop.markPaid, { bountyId: row.bountyId, payment: receipt(row), webhookId: "event-1" })).toEqual({ ok: true });
    const live = await t.query(api.social.bounties);
    expect(live).toHaveLength(1);
    expect(live[0]).toMatchObject({ target: { kind: "place", name: "Berkeley Café" }, center, maxExplorers: 5, durationDays: 7, pool: 100, platformFee: 10, totalAmount: 110, paidWith: "whop" });
    const stored = await t.run((ctx) => ctx.db.query("bounties").unique());
    expect(stored!.expiresAt! - stored!.createdAt).toBe(7 * DAY);
    expect(stored).toMatchObject({ maxExplorers: 5, targetType: "place", pool: 100, radius: 120 });
  });
  test("same draft reserves one record and conflicting edits cannot change an issued checkout", async () => {
    const { t, row, user } = await pending();
    const again = await t.mutation(internal.whop.reserveCheckout, { ownerId: user, requestId: "request-1", data: draft(), accountId: "biz_test", sandbox: true });
    expect(again.bountyId).toBe(row.bountyId);
    expect(await t.run((ctx) => ctx.db.query("bountyCheckouts").collect())).toHaveLength(1);
    await expect(t.mutation(internal.whop.reserveCheckout, { ownerId: user, requestId: "request-1", data: draft({ pool: 500 }), accountId: "biz_test", sandbox: true })).rejects.toThrow("different bounty");
  });
  test("repeated webhook and sync confirmation produce one live bounty and keep expiry", async () => {
    const { t, row } = await pending();
    const args = { bountyId: row.bountyId, payment: receipt(row), webhookId: "event-1" };
    await t.mutation(internal.whop.markPaid, args);
    const original = await t.run((ctx) => ctx.db.query("bounties").unique());
    await t.mutation(internal.whop.markPaid, args);
    await t.mutation(internal.whop.markPaid, { ...args, webhookId: "event-2" });
    await t.mutation(internal.whop.markPaid, { bountyId: row.bountyId, payment: receipt(row) });
    expect(await t.run((ctx) => ctx.db.query("bounties").collect())).toHaveLength(1);
    expect(await t.run((ctx) => ctx.db.query("whopEvents").collect())).toHaveLength(2);
    expect((await t.run((ctx) => ctx.db.query("bounties").unique()))!.expiresAt).toBe(original!.expiresAt);
  });
  test.each([
    { total: { amount: "1", currency: "usd" } }, { currency: "eur", total: { amount: "110", currency: "eur" } },
    { status: "authorized", substatus: "succeeded" }, { status: "paid", substatus: "refunded" },
    { status: "failed", substatus: "failed" }, { metadata: { bountyId: "another-bounty" } },
    { checkout_configuration_id: "ch_wrong" }, { account_id: "biz_wrong" }, { refunded_amount: { amount: "10" } },
    { refunded_at: "2026-01-01" }, { auto_refunded: true },
  ])("payment mismatch %# cannot publish or consume event", async (invalid) => {
    const { t, row } = await pending();
    expect(await t.mutation(internal.whop.markPaid, { bountyId: row.bountyId, payment: receipt(row, invalid), webhookId: "bad-event" })).toEqual({ ok: false });
    expect(await t.query(api.social.bounties)).toEqual([]);
    expect(await t.query(internal.whop.eventSeen, { webhookId: "bad-event" })).toBe(false);
  });
  test("a second payment cannot fund an already-paid bounty", async () => {
    const { t, row } = await pending();
    await t.mutation(internal.whop.markPaid, { bountyId: row.bountyId, payment: receipt(row) });
    await expect(t.mutation(internal.whop.markPaid, { bountyId: row.bountyId, payment: receipt(row, { id: "pay_second" }) })).rejects.toThrow("already funded");
  });
  test("expired and filled bounties are not returned; legacy rows expire after 14 days", async () => {
    const { t, row } = await pending();
    await t.mutation(internal.whop.markPaid, { bountyId: row.bountyId, payment: receipt(row) });
    await t.run(async (ctx) => {
      const live = (await ctx.db.query("bounties").unique())!;
      await ctx.db.patch(live._id, { expiresAt: Date.now() - 1 });
      await ctx.db.insert("bounties", { bountyId: "legacy", active: true, createdAt: Date.now() - 15 * DAY, data: { videos: 8, recorded: 0 } });
    });
    expect(await t.query(api.social.bounties)).toEqual([]);
    expect(isBountyActive({ active: true, createdAt: Date.now(), data: { videos: 5, recorded: 5 } }, Date.now())).toBe(false);
  });
  test("an older pending record can still be paid with its original data", async () => {
    const t = convexTest(schema, modules);
    const data = { ...draft(), durationDays: undefined, maxExplorers: undefined, videos: 8 };
    delete data.durationDays; delete data.maxExplorers;
    await t.run((ctx) => ctx.db.insert("bountyCheckouts", { bountyId: "legacy", checkoutId: "ch_legacy", data, amount: 110, status: "pending", createdAt: Date.now() }));
    await t.mutation(internal.whop.markPaid, { bountyId: "legacy", payment: receipt({ bountyId: "legacy", checkoutId: "ch_legacy", amount: 110 }) });
    const live = (await t.run((ctx) => ctx.db.query("bounties").unique()))!;
    expect(live.expiresAt! - live.createdAt).toBe(14 * DAY);
    expect(live.data.videos).toBe(8);
  });
  test("public legacy publishing bypass is closed", async () => {
    const { owner } = await pending();
    await expect(owner.mutation(api.social.postBounty, { bounty: draft() })).rejects.toThrow("Only verified payments");
  });
  test("a signed-in user's checkout is hidden from guests and other users", async () => {
    const { t, row } = await pending();
    expect(await t.query(api.whop.bountyStatus, { bountyId: row.bountyId })).toMatchObject({ status: "missing" });
    const another = await t.run((ctx) => ctx.db.insert("users", {}));
    expect(await t.withIdentity({ subject: `${another}|other` }).query(api.whop.bountyStatus, { bountyId: row.bountyId })).toMatchObject({ status: "missing" });
  });
  test("guests can pay: the bounty is published without an owner", async () => {
    const t = convexTest(schema, modules);
    const row = await t.mutation(internal.whop.reserveCheckout, {
      requestId: "guest-1", data: draft(), accountId: "biz_test", sandbox: true,
    });
    await t.mutation(internal.whop.attachCheckout, { bountyId: row.bountyId, checkoutId: "ch_guest", checkoutUrl: "https://sandbox.whop.com/test" });
    expect(await t.query(api.whop.bountyStatus, { bountyId: row.bountyId })).toMatchObject({ status: "pending" });
    const withCheckout = await t.run((ctx) => ctx.db.get(row._id));
    expect(await t.mutation(internal.whop.markPaid, { bountyId: row.bountyId, payment: receipt(withCheckout!) })).toEqual({ ok: true });
    const live = await t.run((ctx) => ctx.db.query("bounties").withIndex("by_bountyId", (q) => q.eq("bountyId", row.bountyId)).unique());
    expect(live?.ownerId).toBeUndefined();
    expect(await t.query(api.whop.bountyStatus, { bountyId: row.bountyId })).toMatchObject({ status: "paid" });
  });
  test("checkout retry reuses Whop resource; app return link never publishes", async () => {
    vi.stubEnv("WHOP_API_KEY", "test-key"); vi.stubEnv("WHOP_PLAN_ID", "plan_test"); vi.stubEnv("WHOP_ENVIRONMENT", "sandbox");
    const t = convexTest(schema, modules);
    const user = await t.run((ctx) => ctx.db.insert("users", {}));
    const owner = t.withIdentity({ subject: `${user}|session` });
    const calls: any[] = [];
    vi.stubGlobal("fetch", vi.fn(async (url: string, init?: RequestInit) => {
      calls.push({ url, init });
      return Response.json(url.includes("/plans/") ? { account: { id: "biz_test" }, product: { id: "prod_test" } } : { id: "ch_test", purchase_url: "https://sandbox.whop.com/test" });
    }));
    const first = await owner.action(api.whop.createBountyCheckout, { bounty: draft() });
    const second = await owner.action(api.whop.createBountyCheckout, { bounty: draft() });
    expect(second).toEqual(first);
    const creates = calls.filter((call) => call.url.includes("checkout_configurations"));
    expect(creates).toHaveLength(1);
    expect(creates[0].init.headers["Idempotency-Key"]).toContain(first.bountyId);
    expect(JSON.parse(creates[0].init.body).variant.initial_price).toBe(110);
    expect(first).toMatchObject({ amount: 110, sandbox: true });
    expect(await t.query(api.social.bounties)).toEqual([]);
    const page = await t.fetch(`/whop/return?bounty=${first.bountyId}`);
    expect(page.status).toBe(200);
    expect(await t.query(api.social.bounties)).toEqual([]);
  });
});

async function webhookHeaders(raw: string, secret: string, id = "hook_signed", timestamp = String(Math.floor(Date.now() / 1000))) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${id}.${timestamp}.${raw}`));
  return { "webhook-id": id, "webhook-timestamp": timestamp, "webhook-signature": `v1,${Buffer.from(mac).toString("base64")}` };
}

describe("signed Whop webhook", () => {
  test("bad or stale signatures cannot publish", async () => {
    vi.stubEnv("WHOP_WEBHOOK_SECRET", "ws_test-secret");
    const { t, row } = await pending();
    const raw = JSON.stringify({ type: "payment.succeeded", data: { id: "pay_test" } });
    const bad = await t.fetch("/whop", { method: "POST", body: raw, headers: { "webhook-id": "invalid", "webhook-timestamp": "NaN", "webhook-signature": "v1,bad" } });
    expect(bad.status).toBe(401);
    const oldHeaders = await webhookHeaders(raw, "ws_test-secret", "old-event", "100");
    expect((await t.fetch("/whop", { method: "POST", body: raw, headers: oldHeaders })).status).toBe(401);
    const validHeaders = await webhookHeaders(raw, "ws_test-secret");
    expect((await t.fetch("/whop", { method: "POST", body: raw + " ", headers: validHeaders })).status).toBe(401);
    expect(await t.query(api.social.bounties)).toEqual([]);
    expect((await t.query(internal.whop.pending, { bountyId: row.bountyId }))!.status).toBe("pending");
  });
  test("valid webhook verifies canonical payment and duplicate delivery is harmless", async () => {
    vi.stubEnv("WHOP_WEBHOOK_SECRET", "ws_test-secret"); vi.stubEnv("WHOP_API_KEY", "test-key");
    const { t, row } = await pending();
    const fetcher = vi.fn(async () => Response.json(receipt(row)));
    vi.stubGlobal("fetch", fetcher);
    const raw = JSON.stringify({ type: "payment.succeeded", data: { id: "pay_test" } });
    const headers = await webhookHeaders(raw, "ws_test-secret");
    expect((await t.fetch("/whop", { method: "POST", body: raw, headers })).status).toBe(200);
    expect((await t.fetch("/whop", { method: "POST", body: raw, headers })).status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(await t.query(api.social.bounties)).toHaveLength(1);
    expect(await t.run((ctx) => ctx.db.query("whopEvents").collect())).toHaveLength(1);
  });
  test("an invalid canonical amount leaves the delivery retryable", async () => {
    vi.stubEnv("WHOP_WEBHOOK_SECRET", "ws_test-secret"); vi.stubEnv("WHOP_API_KEY", "test-key");
    const { t, row } = await pending();
    const fetcher = vi.fn(async () => Response.json(receipt(row, { total: { amount: "1", currency: "usd" } })));
    vi.stubGlobal("fetch", fetcher);
    const raw = JSON.stringify({ type: "payment.succeeded", data: { id: "pay_test" } });
    const headers = await webhookHeaders(raw, "ws_test-secret");
    expect((await t.fetch("/whop", { method: "POST", body: raw, headers })).status).toBe(409);
    expect(await t.query(internal.whop.eventSeen, { webhookId: "hook_signed" })).toBe(false);
    fetcher.mockImplementation(async () => Response.json(receipt(row)));
    expect((await t.fetch("/whop", { method: "POST", body: raw, headers })).status).toBe(200);
    expect(await t.query(api.social.bounties)).toHaveLength(1);
  });
  test("fallback sync verifies a paid receipt for the specific checkout", async () => {
    vi.stubEnv("WHOP_API_KEY", "test-key"); vi.stubEnv("WHOP_PLAN_ID", "plan_test");
    const { t, row, owner } = await pending();
    const fetcher = vi.fn(async (url: string) => Response.json(
      url.includes("/plans/") ? { account: { id: "biz_test" }, product: { id: "prod_test" } } :
      url.includes("/payments?") ? { data: [{ id: "pay_test", checkout_configuration_id: row.checkoutId }] } : receipt(row)
    ));
    vi.stubGlobal("fetch", fetcher);
    expect(await owner.action(api.whop.syncBounty, { bountyId: row.bountyId })).toEqual({ status: "paid" });
    expect(fetcher.mock.calls.some(([url]) => url.includes("created_after="))).toBe(true);
    expect(await t.query(api.social.bounties)).toHaveLength(1);
  });
});

test("owner history preserves canonical expiry without exposing another owner's bounties", async () => {
  const { t, row, owner } = await pending();
  await t.mutation(internal.whop.markPaid, { bountyId: row.bountyId, payment: receipt(row) });
  await t.run(async (ctx) => {
    const live = (await ctx.db.query("bounties").unique())!;
    await ctx.db.patch(live._id, { expiresAt: Date.now() - 1 });
  });
  expect(await t.query(api.social.bounties)).toEqual([]);
  const history = await owner.query(api.social.myBounties);
  expect(history).toHaveLength(1);
  expect(history[0].mine).toBe(true);
  expect(history[0].expiresAt).toBeLessThan(Date.now());
  const other = await t.run((ctx) => ctx.db.insert("users", {}));
  expect(await t.withIdentity({ subject: `${other}|session` }).query(api.social.myBounties)).toEqual([]);
});

test("fallback sync finds the correct receipt on later pages", async () => {
  vi.stubEnv("WHOP_API_KEY", "test-key"); vi.stubEnv("WHOP_PLAN_ID", "plan_test");
  const { t, row, owner } = await pending();
  const urls: string[] = [];
  vi.stubGlobal("fetch", vi.fn(async (url: string) => {
    urls.push(url);
    return Response.json(url.includes("/plans/") ? { account: { id: "biz_test" }, product: { id: "prod_test" } } :
      url.includes("/payments?") ? url.includes("after=next") ? { data: [receipt(row)] } :
        { data: [{ id: "pay_unrelated", metadata: { bountyId: "other" } }], page_info: { has_next_page: true, end_cursor: "next" } } : receipt(row));
  }));
  expect(await owner.action(api.whop.syncBounty, { bountyId: row.bountyId })).toEqual({ status: "paid" });
  expect(urls.some((url) => url.includes("after=next"))).toBe(true);
  expect(urls.some((url) => url.includes("/payments/pay_unrelated"))).toBe(false);
  expect(await t.query(api.social.bounties)).toHaveLength(1);
});

test("retry after a checkout timeout keeps one pending bounty and one idempotency key", async () => {
  vi.stubEnv("WHOP_API_KEY", "test-key"); vi.stubEnv("WHOP_PLAN_ID", "plan_test");
  const t = convexTest(schema, modules);
  const user = await t.run((ctx) => ctx.db.insert("users", {}));
  const owner = t.withIdentity({ subject: `${user}|session` });
  const keys: string[] = [];
  vi.stubGlobal("fetch", vi.fn(async (url: string, init?: RequestInit) => {
    if (url.includes("/plans/")) return Response.json({ account: { id: "biz_test" }, product: { id: "prod_test" } });
    keys.push((init!.headers as Record<string, string>)["Idempotency-Key"]);
    if (keys.length === 1) throw new Error("Checkout request timed out");
    return Response.json({ id: "ch_test", purchase_url: "https://sandbox.whop.com/retry" });
  }));
  await expect(owner.action(api.whop.createBountyCheckout, { bounty: draft() })).rejects.toThrow("timed out");
  const checkout = await owner.action(api.whop.createBountyCheckout, { bounty: draft() });
  expect(keys).toHaveLength(2);
  expect(keys[0]).toBe(keys[1]);
  expect(keys[0]).toContain(checkout.bountyId);
  expect(await t.run((ctx) => ctx.db.query("bountyCheckouts").collect())).toHaveLength(1);
  expect(await t.query(api.social.bounties)).toEqual([]);
});
