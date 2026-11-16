// Restaurant and cafe deals, claimed through Whop. Whop is mocked for the
// demo: claiming writes a claim row with a Whop-style receipt and returns a
// discount code to show at the counter.
//
//   npx convex run deals:seed '{}'

import { internalMutation, mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { getAuthUserId } from "@convex-dev/auth/server";

function rng(seed: string) {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i++) h = Math.imul(h ^ seed.charCodeAt(i), 16777619);
  return () => {
    h += 0x6d2b79f5;
    let t = h;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * A short, hand-picked list of real restaurants and cafes a few minutes' walk from
 * Y Combinator in Dogpatch. Every offer fits what the place actually sells. Deals used
 * to be generated from place categories, which handed offices and bakeries ice cream
 * offers ("office" contains "ice"), so they are listed by hand instead.
 */
const DEALS: { placeId: string; offers: { title: string; detail: string; percent: number; priceCents: number }[] }[] = [
  { placeId: "long-bridge", offers: [
    { title: "Free topping on any pizza", detail: "One extra topping on a whole pie, dine in or to go.", percent: 100, priceCents: 0 },
  ] },
  { placeId: "paper-son", offers: [
    { title: "Free drip coffee with any pastry", detail: "One per visit.", percent: 100, priceCents: 0 },
  ] },
  { placeId: "the-ramp", offers: [
    { title: "15% off brunch", detail: "Weekdays before 2 PM, parties up to 4.", percent: 15, priceCents: 0 },
  ] },
  { placeId: "just-for-you", offers: [
    { title: "$25 of food for $18", detail: "Credit applied at the register.", percent: 28, priceCents: 1800 },
  ] },
  { placeId: "piccino", offers: [
    { title: "Free starter with two mains", detail: "Dinner only.", percent: 100, priceCents: 0 },
  ] },
  { placeId: "n4057348979", offers: [
    { title: "Second scoop half off", detail: "Any flavor, cup or cone.", percent: 25, priceCents: 0 },
  ] },
  { placeId: "n4521494871", offers: [
    { title: "10% off your order", detail: "Dine in or to go.", percent: 10, priceCents: 0 },
  ] },
];

/** Replace every deal with the hand-picked Dogpatch list above. */
export const seed = internalMutation({
  args: {},
  handler: async (ctx) => {
    for (const d of await ctx.db.query("deals").collect()) await ctx.db.delete(d._id);
    let count = 0;
    const missing: string[] = [];
    for (const { placeId, offers } of DEALS) {
      const place = await ctx.db.query("places").withIndex("by_placeId", (q) => q.eq("placeId", placeId)).unique();
      if (!place) { missing.push(placeId); continue; }
      const r = rng(placeId + "deal");
      for (const [i, o] of offers.entries()) {
        await ctx.db.insert("deals", {
          dealId: `${placeId}-${i}`,
          placeId,
          placeName: place.name,
          ...o,
          whopPlanId: `plan_demo_${placeId.slice(-6)}${i}`,
          remaining: 10 + Math.floor(r() * 30),
          expiresAt: Date.now() + (7 + Math.floor(r() * 21)) * 86_400_000,
        });
        count++;
      }
    }
    return { deals: count, missing };
  },
});

export const all = query({
  args: {},
  handler: async (ctx) => {
    return (await ctx.db.query("deals").collect()).map(({ _id, _creationTime, ...d }) => d);
  },
});

/** Mock Whop checkout: record the claim and hand back a code for the counter. */
export const claim = mutation({
  args: { dealId: v.string(), device: v.optional(v.string()) },
  handler: async (ctx, { dealId, device }) => {
    const deal = await ctx.db.query("deals").withIndex("by_dealId", (q) => q.eq("dealId", dealId)).unique();
    if (!deal) throw new Error("Deal not found");
    if (deal.remaining <= 0) throw new Error("This deal is all claimed");
    const userId = await getAuthUserId(ctx);
    const prior = (await ctx.db.query("dealClaims").withIndex("by_deal", (q) => q.eq("dealId", dealId)).collect())
      .find((c) => (userId && c.userId === userId) || (device && c.device === device));
    if (prior) return { code: prior.code, receipt: prior.receipt, again: true };
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const pick = () => alphabet[Math.floor(Math.random() * alphabet.length)];
    const code = `ODY-${Array.from({ length: 4 }, pick).join("")}-${Array.from({ length: 4 }, pick).join("")}`;
    const receipt = `whop_rcpt_${Math.random().toString(36).slice(2, 12)}`;
    await ctx.db.insert("dealClaims", { dealId, userId: userId ?? undefined, device, code, receipt, createdAt: Date.now() });
    await ctx.db.patch(deal._id, { remaining: deal.remaining - 1 });
    return { code, receipt, again: false };
  },
});
