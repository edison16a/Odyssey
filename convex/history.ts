// Contribution history for places: the seeded demo history around SF and
// the query the place page reads for its graph and recent contributions.
//
//   npx convex run history:seedArea '{"area":"sf-dogpatch"}'
//   npx convex run history:clearSeeded '{}'

import { internalMutation, query } from "./_generated/server";
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";

const DAY = 86_400_000;
const WEEKS = 18;

/** Small deterministic generator so reseeding gives the same history. */
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

const VIBES: Record<string, { vibe: string; tags: string[]; lines: string[] }> = {
  cafe: { vibe: "cozy", tags: ["coffee", "laptop friendly", "busy mornings"], lines: ["Line moves fast, seats open up after 10.", "Bright corner by the window, good for working.", "Pastries sell out by noon."] },
  food: { vibe: "lively", tags: ["casual", "good for groups", "takeout"], lines: ["Order at the counter, food comes quick.", "Patio out back most people miss.", "Gets loud at dinner, calm at lunch."] },
  bar: { vibe: "buzzing", tags: ["night out", "drinks", "standing room"], lines: ["Packed after 9, early is chill.", "Back room is quieter.", "Friendly staff, cash and card."] },
  outdoors: { vibe: "calm", tags: ["open air", "views", "dog friendly"], lines: ["Best light around sunset.", "Windy by the water, bring a layer.", "Benches along the path."] },
  art: { vibe: "creative", tags: ["murals", "photo spot", "free"], lines: ["Murals change every few months.", "Walk the whole block, it keeps going.", "Quiet on weekday mornings."] },
  shop: { vibe: "browsable", tags: ["local", "gifts", "small"], lines: ["Owner is happy to chat.", "New stock on Fridays.", "Tiny but packed with finds."] },
  fitness: { vibe: "energetic", tags: ["workout", "classes", "showers"], lines: ["Morning classes fill up.", "Day passes at the front desk.", "Clean and well kept."] },
  default: { vibe: "worth a visit", tags: ["local favorite", "walkable"], lines: ["Easy to miss from the street.", "Worth a quick stop.", "Different feel every visit."] },
};

function vibeFor(cats: string[]) {
  for (const c of cats) {
    if (/cafe|coffee|bakery/.test(c)) return VIBES.cafe;
    if (/restaurant|food|pizza|fast|deli/.test(c)) return VIBES.food;
    if (/bar|pub|brew|night/.test(c)) return VIBES.bar;
    if (/park|outdoor|garden|view|beach|water/.test(c)) return VIBES.outdoors;
    if (/art|mural|museum|gallery|landmark/.test(c)) return VIBES.art;
    if (/shop|store|book|market/.test(c)) return VIBES.shop;
    if (/fitness|gym|sport|climb/.test(c)) return VIBES.fitness;
  }
  return VIBES.default;
}

/** Give every place in an area 18 weeks of walkthroughs and check-ins from the demo explorers. */
export const seedArea = internalMutation({
  args: { area: v.string(), now: v.optional(v.number()) },
  handler: async (ctx, { area, now }) => {
    const today = now ?? Date.now();
    const crew = (await ctx.db.query("profiles").collect()).filter((p) => p.demoId);
    if (crew.length === 0) throw new Error("Run seed:people first");
    const places = await ctx.db.query("places").withIndex("by_area", (q) => q.eq("area", area)).collect();
    let contributions = 0;
    let checkins = 0;
    for (const place of places) {
      const already = await ctx.db
        .query("contributions")
        .withIndex("by_place", (q) => q.eq("placeId", place.placeId))
        .filter((q) => q.eq(q.field("source"), "seed"))
        .first();
      if (already) continue;
      const rand = rng(place.placeId + "history");
      // Busier near YC and for the curated places.
      const base = place.source === "seed" ? 18 : area === "sf-dogpatch" ? 9 : 5;
      const count = Math.round(base + rand() * base * 1.6);
      const style = vibeFor([...(place.cats ?? []), place.category ?? ""]);
      const visitors = new Set<Id<"users">>();
      let first: { userId: Id<"users">; at: number } | null = null;
      for (let i = 0; i < count; i++) {
        const who = crew[Math.floor(rand() * crew.length)];
        // Recent weeks are busier.
        const daysAgo = Math.floor(Math.pow(rand(), 1.6) * WEEKS * 7);
        const at = today - daysAgo * DAY - Math.floor(rand() * 10) * 3_600_000;
        const day = new Date(at).toISOString().slice(0, 10);
        const seconds = 12 + Math.floor(rand() * 50);
        await ctx.db.insert("contributions", {
          userId: who.userId,
          placeId: place.placeId,
          placeName: place.name,
          kind: "walkthrough",
          seconds,
          insights: {
            vibe: style.vibe,
            tags: [style.tags[Math.floor(rand() * style.tags.length)]],
            summary: style.lines[Math.floor(rand() * style.lines.length)],
            source: "seed",
          },
          status: "verified",
          points: 10 + Math.round(seconds / 3),
          source: "seed",
          createdAt: at,
        });
        contributions++;
        const existing = await ctx.db
          .query("checkins")
          .withIndex("by_user_place_day", (q) => q.eq("userId", who.userId).eq("placeId", place.placeId).eq("day", day))
          .first();
        if (!existing) {
          await ctx.db.insert("checkins", {
            userId: who.userId,
            placeId: place.placeId,
            placeName: place.name,
            day,
            caption: "",
            first: false,
            recommended: false,
            coins: 0,
            xp: 0,
            points: 0,
            lat: place.lat,
            lng: place.lng,
            createdAt: at,
          });
          checkins++;
        }
        visitors.add(who.userId);
        if (!first || at < first.at) first = { userId: who.userId, at };
      }
      await ctx.db.patch(place._id, {
        explorerCount: Math.max(place.explorerCount, visitors.size),
        contributionCount: place.contributionCount + count,
        ...(place.firstExplorerId || !first ? {} : { firstExplorerId: first.userId, firstExploredAt: first.at }),
        ...(place.insights ? {} : { insights: { vibe: style.vibe, tags: style.tags, summary: style.lines[0], source: "seed" } }),
      });
    }
    return { area, places: places.length, contributions, checkins };
  },
});

/** Remove the seeded history (contributions only; check-ins stay as visits). */
export const clearSeeded = internalMutation({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.db.query("contributions").withIndex("by_source", (q) => q.eq("source", "seed")).take(4000);
    for (const r of rows) await ctx.db.delete(r._id);
    return { removed: rows.length };
  },
});

/** The place page: a daily graph of the last 18 weeks and the latest contributions. */
export const forPlace = query({
  args: { placeId: v.string(), now: v.optional(v.number()) },
  handler: async (ctx, { placeId, now }) => {
    const today = now ?? Date.now();
    const start = today - WEEKS * 7 * DAY;
    const rows = await ctx.db.query("contributions").withIndex("by_place", (q) => q.eq("placeId", placeId)).collect();
    const visits = await ctx.db.query("checkins").withIndex("by_place", (q) => q.eq("placeId", placeId)).collect();
    // One count per explorer per day, whether they walked it through or just visited.
    const days = new Array(WEEKS * 7).fill(0);
    const seen = new Set<string>();
    const bump = (userId: string, at: number) => {
      if (at < start || at > today) return;
      const i = Math.min(days.length - 1, Math.floor((at - start) / DAY));
      if (seen.has(`${userId}:${i}`)) return;
      seen.add(`${userId}:${i}`);
      days[i]++;
    };
    rows.forEach((r) => bump(r.userId, r.createdAt));
    visits.forEach((c) => bump(c.userId, c.createdAt));
    const recent = rows.sort((a, b) => b.createdAt - a.createdAt).slice(0, 6);
    const people = new Map<string, any>();
    for (const r of recent) {
      if (people.has(r.userId)) continue;
      people.set(r.userId, await ctx.db.query("profiles").withIndex("by_user", (q) => q.eq("userId", r.userId)).unique());
    }
    return {
      days,
      total: rows.length,
      explorers: new Set(visits.map((c) => c.userId)).size,
      recent: recent.map((r) => {
        const p = people.get(r.userId);
        return {
          name: p?.name ?? "Explorer",
          demoId: p?.demoId ?? null,
          avatarPath: p?.avatarPath ?? null,
          seconds: r.seconds,
          summary: r.insights?.summary ?? null,
          vibe: r.insights?.vibe ?? null,
          createdAt: r.createdAt,
        };
      }),
    };
  },
});
