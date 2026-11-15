// "For you": ranks the places around the explorer by what Odyssey has
// learned about them over time.
//
// Inputs per candidate come from the phone (it already knows what is near
// you and each place's features). Scoring blends:
//
//   learned    Σ feature weights from every vote/check-in (Convex, exact)
//   memory     what Supermemory remembers: profile facts and the memories
//              most relevant to this outing, turned into feature affinities
//              (+ a direct hit when a memory names the place itself)
//   similar    overlap with places they gave a thumbs up / thumbs down
//   interest   the onboarding interests
//   near       closeness (1.4·e^(−m/700), as on the phone)
//   novelty    new places beat ones they have checked in at; "be first"
//              places get a small push; picks shown again and again without
//              a reaction fade
//
// then re-ranks for variety (no wall of identical cafés), and explains each
// pick in one short, honest sentence. If Supermemory is slow or down the
// ranking still works from Convex alone.

import { action } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { getAuthUserId } from "@convex-dev/auth/server";
import { describeFeatures, hasSupermemory, sm } from "./memory";
import { namespaceFor } from "./lib";

const candidate = v.object({
  placeId: v.string(),
  name: v.string(),
  features: v.array(v.string()),
  metres: v.number(),
  canBeFirst: v.optional(v.boolean()),
});

type Candidate = typeof candidate.type;
type Vote = { placeId: string; name: string; v: number; features: string[]; at: number };
type TasteContext = {
  city?: string;
  interests: string[];
  weights: Record<string, number>;
  votes: Vote[];
  visited: string[];
  recentlyShown: Record<string, number>;
};
type Scored = {
  placeId: string;
  cats: string[];
  score: number;
  reason: string;
  signals: Record<string, number>;
};
type Pick = { placeId: string; score: number; reason: string; signals: Record<string, number> };
type ForYouResult = {
  picks: Pick[];
  profileFacts: string[];
  memoriesUsed: number;
  usedSupermemory: boolean;
  supermemoryError?: string;
};
type Memory = { text: string; weight: number; polarity: number };

// Words in a memory that point at a feature key.
const LEXICON: Array<[RegExp, string]> = [
  [/\b(coffee|caf[eé]s?|espresso|latte|boba|bubble tea|tea house)\b/i, "cat:coffee"],
  [/\b(restaurants?|food|eat(ing)?|dinner|lunch|brunch)\b/i, "cat:food"],
  [/\b(dessert|ice cream|bakery|pastr(y|ies)|sweets?)\b/i, "cat:dessert"],
  [/\b(librar(y|ies)|books?|reading)\b/i, "cat:library"],
  [/\b(study|studying|work(ing)? spot|laptop)\b/i, "cat:study"],
  [/\b(parks?|outdoors?|nature|hik(e|ing)|garden|trails?)\b/i, "cat:park"],
  [/\b(museums?|art|galler(y|ies)|culture|theat(re|er)|entertainment)\b/i, "cat:entertainment"],
  [/\b(bars?|nightlife|cocktails?|nights? out|clubs?)\b/i, "cat:nightlife"],
  [/\b(shop(s|ping)?|stores?|boutiques?|markets?)\b/i, "cat:shopping"],
  [/\b(gyms?|fitness|climbing|workout|yoga)\b/i, "cat:fitness"],
  [/\b(independent|indie|locally owned|local spots?|small business)\b/i, "indie"],
  [/\b(chains?|franchises?)\b/i, "chain"],
  [/\b(wi-?fi|internet)\b/i, "wifi"],
  [/\b(outdoor seating|patio|sit outside)\b/i, "outdoor"],
  [/\b(quiet|calm|peaceful|cozy)\b/i, "quiet"],
  [/\b(lively|busy|buzzing|energetic|loud)\b/i, "lively"],
  [/\b(vegan|plant-based|vegetarian)\b/i, "vegan"],
  [/\b(late|late-night|open late|after dark)\b/i, "late"],
  [/\b(accessible|wheelchair|step-free)\b/i, "accessible"],
  [/\b(hidden gems?|off the beaten|undiscovered|secret)\b/i, "hidden"],
];
const CUISINES = ["japanese", "ramen", "sushi", "mexican", "thai", "indian", "chinese", "korean", "italian", "pizza",
  "burger", "vietnamese", "mediterranean", "french", "bubble_tea", "coffee_shop", "sandwich", "bagel", "donut"];

const NEGATIVE = /\b(dislike[sd]?|does ?n[o']t (want|like|enjoy)|avoid(s|ed)?|not a fan|hate[sd]?|took back|neutral|thumbs down|not into|skip(s|ped)?)\b/i;

function polarityOf(text: string): number {
  if (/\btook back\b|\bneutral\b/i.test(text)) return 0;
  return NEGATIVE.test(text) ? -1 : 1;
}

function affinityFrom(memories: Memory[]) {
  const affinity: Record<string, number> = {};
  for (const m of memories) {
    if (m.polarity === 0) continue;
    const hit = new Set<string>();
    for (const [re, key] of LEXICON) if (re.test(m.text)) hit.add(key);
    for (const c of CUISINES) if (new RegExp(`\\b${c.replace("_", "[ _]")}\\b`, "i").test(m.text)) hit.add(`cuisine:${c}`);
    for (const key of hit) affinity[key] = (affinity[key] ?? 0) + m.polarity * m.weight;
  }
  // Keep any one feature from dominating.
  for (const k of Object.keys(affinity)) affinity[k] = Math.max(-3, Math.min(3, affinity[k]));
  return affinity;
}

function jaccard(a: string[], b: string[]) {
  const A = new Set(a.filter((f) => !f.startsWith("cat:")));
  const B = new Set(b.filter((f) => !f.startsWith("cat:")));
  if (A.size === 0 || B.size === 0) return 0;
  let both = 0;
  for (const x of A) if (B.has(x)) both++;
  return both / (A.size + B.size - both);
}

function hash(s: string) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  return (h >>> 0) / 4294967295;
}

const INTEREST_CATS: Record<string, string[]> = {
  food: ["food", "coffee", "dessert"],
  books: ["library", "study"],
  outdoors: ["park"],
  culture: ["entertainment"],
  nightlife: ["nightlife"],
  travel: ["entertainment", "park"],
};

const TRAIT_WORDS: Record<string, string> = {
  indie: "independent spots", wifi: "wifi", outdoor: "outdoor seating", quiet: "quiet places",
  lively: "lively places", vegan: "vegan options", late: "late nights", accessible: "step-free access", hidden: "hidden gems",
};

async function readMemories(userId: string, city: string | undefined, candidates: Candidate[]) {
  const ns = namespaceFor(userId as any);
  const kinds = [...new Set(candidates.flatMap((c) => describeFeatures(c.features).cats))].slice(0, 6).join(", ");
  const query = `What kinds of places does this explorer love or avoid${city ? ` around ${city}` : ""}? ${kinds}`;
  const [profile, search] = await Promise.allSettled([
    sm("POST", ns, "profile", {}, 3500),
    sm("POST", ns, "search", { query, searchMode: "hybrid", limit: 20 }, 3500),
  ]);
  const memories: Memory[] = [];
  const facts: string[] = [];
  if (profile.status === "fulfilled") {
    const p = profile.value?.profile ?? {};
    for (const m of p.static ?? []) { facts.push(m.memory); memories.push({ text: m.memory, weight: 1, polarity: polarityOf(m.memory) }); }
    for (const m of p.dynamic ?? []) { facts.push(m.memory); memories.push({ text: m.memory, weight: 0.7, polarity: polarityOf(m.memory) }); }
    for (const bucket of Object.values(p.buckets ?? {}) as any[]) {
      for (const m of bucket ?? []) memories.push({ text: m.memory, weight: 0.9, polarity: polarityOf(m.memory) });
    }
  }
  if (search.status === "fulfilled") {
    for (const r of search.value?.results ?? []) {
      const text = r.memory ?? r.chunk;
      if (!text) continue;
      memories.push({ text, weight: 0.4 + 0.8 * (r.similarity ?? 0.5), polarity: polarityOf(text) });
    }
  }
  const ok = profile.status === "fulfilled" || search.status === "fulfilled";
  const error = [profile, search].filter((r) => r.status === "rejected").map((r: any) => String(r.reason)).join("; ");
  return { memories, facts: facts.slice(0, 12), ok, error };
}

export const forYou = action({
  args: {
    candidates: v.array(candidate),
    city: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { candidates, city, limit }): Promise<ForYouResult> => {
    const userId = await getAuthUserId(ctx);
    if (!userId) throw new Error("Not signed in");
    const me: TasteContext = await ctx.runQuery(internal.taste.contextFor, { userId });
    const where = city ?? me.city;
    const pool = candidates.slice(0, 250);

    const sm = hasSupermemory() ? await readMemories(userId, where, pool) : { memories: [], facts: [], ok: false, error: "no key" };
    const affinity = affinityFrom(sm.memories);
    const liked = me.votes.filter((x) => x.v > 0);
    const disliked = new Set(me.votes.filter((x) => x.v < 0).map((x) => x.placeId));
    const dislikedVotes = me.votes.filter((x) => x.v < 0);
    const visited = new Set(me.visited);
    const day = new Date().toISOString().slice(0, 10);

    const scored: Scored[] = pool
      .filter((c) => !disliked.has(c.placeId))
      .map((c): Scored => {
        const learnedParts = c.features.map((f) => [f, me.weights[f] ?? 0] as const);
        const learned = learnedParts.reduce((a, [, w]) => a + w, 0);
        const memoryParts = c.features.map((f) => [f, affinity[f] ?? 0] as const);
        let memory = 0.8 * memoryParts.reduce((a, [, w]) => a + w, 0);
        const named = sm.memories.find((m) => m.text.toLowerCase().includes(c.name.toLowerCase()) && c.name.length > 3);
        if (named) memory += named.polarity > 0 ? 1.5 : named.polarity < 0 ? -3 : 0;

        let bestLike: { name: string; sim: number } | null = null;
        for (const l of liked) {
          if (l.placeId === c.placeId) continue;
          const sim = jaccard(c.features, l.features);
          if (!bestLike || sim > bestLike.sim) bestLike = { name: l.name, sim };
        }
        const worstDislike = Math.max(0, ...dislikedVotes.map((d) => jaccard(c.features, d.features)));
        const similar = 1.6 * (bestLike?.sim ?? 0) - 1.4 * worstDislike;

        const cats = c.features.filter((f) => f.startsWith("cat:")).map((f) => f.slice(4));
        const interest = me.interests.find((i) => (INTEREST_CATS[i] ?? []).some((k) => cats.includes(k)));
        const near = 1.4 * Math.exp(-c.metres / 700);
        const novelty = (visited.has(c.placeId) ? -0.4 : 0.5) + (c.canBeFirst ? 0.3 : 0) - 0.15 * (me.recentlyShown[c.placeId] ?? 0);
        const jitter = 0.15 * hash(`${userId}:${day}:${c.placeId}`);
        const liked0 = liked.some((l) => l.placeId === c.placeId) ? 2.5 : 0;
        const score = learned + memory + similar + (interest ? 0.6 : 0) + near + novelty + jitter + liked0;

        // The reason: whichever personal signal mattered most, said plainly.
        const topLearned = learnedParts.filter(([f, w]) => w >= 0.5 && TRAIT_WORDS[f]).sort((a, b) => b[1] - a[1])[0];
        const topMemory = memoryParts.filter(([f, w]) => w >= 0.5).sort((a, b) => b[1] - a[1])[0];
        const walk = `${Math.max(1, Math.round(c.metres / 80))} min walk`;
        let reason: string;
        if (named && named.polarity > 0) reason = `You've been loving ${c.name}`;
        else if (bestLike && bestLike.sim >= 0.34) reason = `Like ${bestLike.name}, which you liked`;
        else if (topMemory && (!topLearned || topMemory[1] >= topLearned[1])) {
          const f = topMemory[0];
          const label = TRAIT_WORDS[f] ?? (f.startsWith("cat:") ? describeFeatures([f]).cats[0] + "s" : f.startsWith("cuisine:") ? f.slice(8).replace(/_/g, " ") : f);
          reason = `Odyssey remembers you're into ${label}`;
        } else if (topLearned) reason = `Because you like ${TRAIT_WORDS[topLearned[0]]}`;
        else if (interest) reason = `Fits your love of ${interest === "books" ? "books" : interest}, ${walk}`;
        else if (c.canBeFirst) reason = `Nobody's explored it yet, ${walk}`;
        else reason = `Close by, ${walk}`;
        return { placeId: c.placeId, cats, score, reason, signals: { learned, memory, similar, near, novelty } };
      })
      .sort((a, b) => b.score - a.score);

    // Variety: each extra pick from an already-picked category costs a little.
    const want = Math.min(limit ?? 40, scored.length);
    const picked: Scored[] = [];
    const catCount: Record<string, number> = {};
    const rest = [...scored];
    while (picked.length < want && rest.length > 0) {
      let best = 0;
      let bestScore = -Infinity;
      for (let i = 0; i < Math.min(rest.length, 30); i++) {
        const r = rest[i];
        const main = r.cats[0] ?? "other";
        const adjusted = r.score - 0.35 * (catCount[main] ?? 0);
        if (adjusted > bestScore) { bestScore = adjusted; best = i; }
      }
      const [r] = rest.splice(best, 1);
      catCount[r.cats[0] ?? "other"] = (catCount[r.cats[0] ?? "other"] ?? 0) + 1;
      picked.push(r);
    }

    const result: Pick[] = picked.map((r) => ({
      placeId: r.placeId,
      score: Math.round(r.score * 1000) / 1000,
      reason: r.reason,
      signals: Object.fromEntries(Object.entries(r.signals).map(([k, x]) => [k, Math.round((x as number) * 100) / 100])),
    }));
    await ctx.runMutation(internal.taste.saveRecommendation, {
      userId,
      city: where,
      picks: result.slice(0, 20).map(({ placeId, score, reason }) => ({ placeId, score, reason })),
      memoriesUsed: sm.memories.length,
      profileFacts: sm.facts,
      usedSupermemory: sm.ok,
    });
    return {
      picks: result,
      profileFacts: sm.facts,
      memoriesUsed: sm.memories.length,
      usedSupermemory: sm.ok,
      supermemoryError: sm.ok ? undefined : sm.error || undefined,
    };
  },
});
