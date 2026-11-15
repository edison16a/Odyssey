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

const OFFERS: Record<string, { title: string; detail: string; percent: number; priceCents: number }[]> = {
  cafe: [
    { title: "Free drink with any pastry", detail: "Any size drip or tea, one per visit.", percent: 100, priceCents: 0 },
    { title: "20% off your order", detail: "Food and drinks, dine in or to go.", percent: 20, priceCents: 0 },
    { title: "10 coffees for the price of 7", detail: "A digital punch card, valid 60 days.", percent: 30, priceCents: 2800 },
  ],
  food: [
    { title: "15% off dinner", detail: "Valid after 5 PM, parties up to 4.", percent: 15, priceCents: 0 },
    { title: "Free appetizer", detail: "With any two entrees.", percent: 100, priceCents: 0 },
    { title: "$25 of food for $18", detail: "Credit applied at the register.", percent: 28, priceCents: 1800 },
  ],
  bar: [
    { title: "Happy hour all night", detail: "Happy hour prices until close, weeknights.", percent: 25, priceCents: 0 },
    { title: "First round 2 for 1", detail: "House drinks, one per explorer.", percent: 50, priceCents: 0 },
  ],
  dessert: [
    { title: "Free topping", detail: "On any scoop or slice.", percent: 100, priceCents: 0 },
    { title: "Buy one get one half off", detail: "Any dessert.", percent: 25, priceCents: 0 },
  ],
};

function offerKind(cats: string): keyof typeof OFFERS | null {
  if (/cafe|coffee|bakery|tea/.test(cats)) return "cafe";
  if (/ice|dessert|donut|chocolate|confection/.test(cats)) return "dessert";
  if (/bar|pub|brew|wine|night/.test(cats)) return "bar";
  if (/restaurant|food|pizza|fast|deli|taco|burger|ramen|sushi/.test(cats)) return "food";
  return null;
}

/** Give most SF cafes, restaurants and bars one or two deals. */
export const seed = internalMutation({
  args: {},
  handler: async (ctx) => {
    for (const d of await ctx.db.query("deals").collect()) await ctx.db.delete(d._id);
    let count = 0;
    for (const area of ["sf-dogpatch", "sf-mission", "sf"]) {
      const places = await ctx.db.query("places").withIndex("by_area", (q) => q.eq("area", area)).collect();
      for (const p of places) {
        const cats = [...(p.cats ?? []), p.category ?? ""].join(" ").toLowerCase();
        const kind = offerKind(cats);
        if (!kind) continue;
        const r = rng(p.placeId + "deal");
        if (r() < 0.25) continue;
        const offers = OFFERS[kind];
        const n = r() < 0.4 ? 2 : 1;
        const start = Math.floor(r() * offers.length);
        for (let i = 0; i < n; i++) {
          const o = offers[(start + i) % offers.length];
          await ctx.db.insert("deals", {
            dealId: `${p.placeId}-${i}`,
            placeId: p.placeId,
            placeName: p.name,
            ...o,
            whopPlanId: `plan_demo_${p.placeId.slice(-6)}${i}`,
            remaining: 5 + Math.floor(r() * 40),
            expiresAt: Date.now() + (3 + Math.floor(r() * 25)) * 86_400_000,
          });
          count++;
        }
      }
    }
    return { deals: count };
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
