// The Supermemory side of taste. Every explorer has their own namespace
// (odyssey_user_<convex user id>); nothing is ever read across namespaces.
//
// Signals are written as short, plain-English facts with dreaming:"instant",
// so they are searchable within seconds and Supermemory folds them into the
// explorer's profile. The recommender (recommend.ts) reads the profile and
// searches these memories back.

import { internalAction } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { namespaceFor } from "./lib";

const API = "https://api.supermemory.ai";

export function hasSupermemory(): boolean {
  return !!process.env.SUPERMEMORY_API_KEY;
}

/** One call to the v5 namespace API, with a timeout so a slow network never blocks a recommendation. */
export async function sm<T = any>(
  method: "POST" | "DELETE",
  namespace: string,
  path: string,
  body: unknown,
  timeoutMs = 8000,
): Promise<T> {
  const key = process.env.SUPERMEMORY_API_KEY;
  if (!key) throw new Error("SUPERMEMORY_API_KEY is not set on this deployment");
  if (!/^[a-zA-Z0-9_:-]{1,100}$/.test(namespace)) throw new Error(`Bad namespace ${namespace}`);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(`${API}/ns/${namespace}/${path}`, {
      method,
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`Supermemory ${path} ${res.status}: ${text.slice(0, 300)}`);
    return (text ? JSON.parse(text) : {}) as T;
  } finally {
    clearTimeout(timer);
  }
}

// ── Turning features into words ───────────────────────────────────────

const PHRASE: Record<string, string> = {
  indie: "independent, locally owned",
  chain: "a big chain",
  wifi: "has wifi",
  outdoor: "has outdoor seating",
  quiet: "quiet",
  lively: "lively and busy",
  vegan: "has vegan options",
  late: "open late",
  accessible: "step-free / wheelchair accessible",
  hidden: "a hidden gem",
};

const CATEGORY: Record<string, string> = {
  coffee: "cafe / coffee shop",
  food: "restaurant / food",
  dessert: "dessert spot",
  library: "library",
  study: "study spot",
  park: "park / outdoors",
  entertainment: "museum, art or entertainment",
  nightlife: "bar / nightlife",
  shopping: "shop",
  fitness: "gym / fitness",
  gas: "gas station",
};

export function describeFeatures(features: string[]) {
  const cats: string[] = [];
  const cuisines: string[] = [];
  const traits: string[] = [];
  for (const f of features) {
    if (f.startsWith("cat:")) cats.push(CATEGORY[f.slice(4)] ?? f.slice(4));
    else if (f.startsWith("cuisine:")) cuisines.push(f.slice(8).replace(/_/g, " "));
    else if (PHRASE[f]) traits.push(PHRASE[f]);
  }
  return { cats, cuisines, traits };
}

function sentenceFor(e: {
  kind: string;
  value: number;
  placeName: string;
  features: string[];
  city?: string;
  createdAt: number;
}) {
  const { cats, cuisines, traits } = describeFeatures(e.features);
  const where = e.city ? ` in ${e.city}` : "";
  const what = [cats.join(", "), cuisines.length ? `${cuisines.join(", ")} food` : ""].filter(Boolean).join("; ");
  const kindOf = what ? ` (a ${what})` : "";
  const traitsLine = traits.length ? ` It is ${traits.join(", ")}.` : "";
  const day = new Date(e.createdAt).toISOString().slice(0, 10);
  switch (e.kind) {
    case "vote":
      if (e.value > 0) return `[${day}] The explorer liked ${e.placeName}${where}${kindOf} and wants more places like it.${traitsLine}`;
      if (e.value < 0) return `[${day}] The explorer disliked ${e.placeName}${where}${kindOf} and does not want places like it recommended.${traitsLine}`;
      return `[${day}] The explorer took back their rating of ${e.placeName}${where}; they are neutral about it now.`;
    case "star":
      return `[${day}] The explorer starred ${e.placeName}${where}${kindOf} to visit later.${traitsLine}`;
    case "checkin":
      return `[${day}] The explorer went to ${e.placeName}${where}${kindOf} and checked in there.${traitsLine}`;
    case "walkthrough":
      return `[${day}] The explorer recorded a walkthrough video of ${e.placeName}${where}${kindOf}.${traitsLine}`;
    default:
      return `[${day}] The explorer interacted with ${e.placeName}${where}.`;
  }
}

// ── Actions ───────────────────────────────────────────────────────────

/** Write one taste event to the explorer's namespace. */
export const rememberEvent = internalAction({
  args: { eventId: v.id("tasteEvents"), extra: v.optional(v.string()) },
  handler: async (ctx, { eventId, extra }) => {
    const e = await ctx.runQuery(internal.taste.eventById, { eventId });
    if (!e) return;
    if (!hasSupermemory()) {
      await ctx.runMutation(internal.taste.markEvent, { eventId, status: "skipped", error: "no api key" });
      return;
    }
    const content = sentenceFor(e) + (extra ? ` ${extra}` : "");
    try {
      await sm("POST", namespaceFor(e.userId), "document", {
        content,
        id: `taste_${eventId}`,
        metadata: { source: "odyssey", kind: e.kind, value: e.value, placeId: e.placeId, city: e.city ?? "" },
        taskType: "memory",
        dreaming: "instant",
      });
      await ctx.runMutation(internal.taste.markEvent, { eventId, status: "sent" });
    } catch (err) {
      await ctx.runMutation(internal.taste.markEvent, { eventId, status: "failed", error: String(err).slice(0, 300) });
    }
  },
});

/** Onboarding interests become standing facts in the profile. */
export const rememberInterests = internalAction({
  args: { userId: v.id("users"), interests: v.array(v.string()) },
  handler: async (_ctx, { userId, interests }) => {
    if (!hasSupermemory() || interests.length === 0) return;
    const labels: Record<string, string> = {
      food: "good food",
      books: "books and libraries",
      outdoors: "the outdoors and parks",
      culture: "art, museums and culture",
      nightlife: "nights out",
      travel: "exploring new places",
    };
    const list = interests.map((i) => labels[i] ?? i).join(", ");
    await sm("POST", namespaceFor(userId), "document", {
      content: `The explorer told Odyssey they are into: ${list}.`,
      id: `interests_${userId}_${Date.now()}`,
      metadata: { source: "odyssey", kind: "interests" },
      taskType: "memory",
      dreaming: "instant",
    });
  },
});

/** Forget every taste memory (the "reset what Odyssey knows" button). */
export const forgetTaste = internalAction({
  args: { userId: v.id("users") },
  handler: async (_ctx, { userId }) => {
    if (!hasSupermemory()) return;
    for (const query of [
      "places the explorer liked or disliked",
      "places the explorer visited or checked in at",
      "the explorer's interests and preferences",
    ]) {
      try {
        await sm("DELETE", namespaceFor(userId), "memories/semantic", { query });
      } catch (err) {
        console.warn("forgetTaste", String(err));
      }
    }
  },
});
