"use node";
// Reads a few frames of a walkthrough video with Claude and writes down what
// they show of the building: stairs, ramps, lifts, doors, restrooms, seating
// and so on, plus what that means for someone in a wheelchair.
//
// Only what the frames show counts. A video of one room says nothing about the
// rest of the building, so "unknown" is a normal answer, and the app presents
// everything as seen in a video, not as verified.

import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";
import { v } from "convex/values";
import { internalAction } from "./_generated/server";
import { internal } from "./_generated/api";

const KINDS = [
  "stairs", "step", "ramp", "elevator", "escalator", "automatic_door", "narrow_passage",
  "restroom", "accessible_restroom", "seating", "food_drinks", "reception", "power_outlets", "other",
] as const;

const Analysis = z.object({
  summary: z.string(),
  wheelchair: z.enum(["accessible", "partly", "not_accessible", "unknown"]),
  wheelchair_reason: z.string(),
  features: z.array(
    z.object({
      kind: z.enum(KINDS),
      label: z.string(),
      detail: z.string(),
      wheelchair: z.enum(["barrier", "helps", "neutral"]),
      certainty: z.enum(["seen", "likely"]),
      frame: z.number(),
    }),
  ),
});

const SYSTEM = `You map the inside of buildings for Odyssey, an app where explorers film a walk through a place. Other people use your notes to decide whether they can visit, so a wrong claim that a place is accessible can leave someone stuck at a door. Report only what the frames show.

You get frames from one walkthrough video in the order they were filmed. Each is preceded by its frame number.

List only the things a visitor would want to know before coming. That is a short list, and it is fine for it to be empty or to have one item. Two kinds of thing belong on it:

1. Anything that decides whether someone with a wheelchair, a stroller or bad knees can get in and around: stairs, single steps and raised thresholds, ramps, elevators, escalators, automatic doors, and passages or doorways that are visibly too tight.
2. The few amenities people look for: restrooms (an accessible one separately, only when the sign or the stall shows it), places to sit, food and drinks, a reception or check-in desk, power outlets for working.

Leave out everything else, because a long list buries the items that matter. In particular leave out: ordinary doors, including heavy or wooden ones; hallways, lobbies and rooms as such; screens, banners, posters and signs; card readers and other fittings; furniture that is not seating; decoration; and anything you would describe by its material or look. If you are unsure whether something belongs, it does not.

For each feature:
- label: what a visitor would call it, at most four words, for example "Stairs at the entrance".
- detail: one sentence, at most twenty words, with what matters about it: how many steps, whether there is a handrail, where it leads.
- wheelchair: "barrier" when it blocks a wheelchair user (stairs, steps, a passage that is too tight), "helps" when it makes access possible (ramp, elevator, automatic door, accessible restroom), otherwise "neutral".
- certainty: "seen" when it is clearly visible, "likely" when it is partly visible or you are inferring it. Leave out anything you would only be guessing.
- frame: the number of the frame where it shows best.
List each physical feature once, even when several frames show it, and merge things of the same kind in the same area into one item. At most six, most important first. People are not features.

Then judge wheelchair access for what this video covers:
- "not_accessible": stairs or steps are the visible way in or through, and no ramp or elevator is visible for the same route.
- "partly": some of what is shown is step-free and some is not, or there is a barrier with a visible alternative.
- "accessible": the entrance and the routes shown are visibly level or ramped, with doorways a wheelchair fits through.
- "unknown": the video does not show enough to tell, for example it never shows the entrance. Prefer this over a guess.
wheelchair_reason is one sentence a visitor can act on, naming the feature that decides it.

summary is one or two sentences on what this space is and what it is like.`;

export const analyze = internalAction({
  args: { id: v.id("scans") },
  handler: async (ctx, { id }) => {
    const scan = await ctx.runQuery(internal.scans.framesFor, { id });
    if (!scan || scan.frames.length === 0) return;
    try {
      const client = new Anthropic(); // ANTHROPIC_API_KEY from the Convex environment
      const content: Anthropic.Beta.BetaContentBlockParam[] = [
        {
          type: "text",
          text: `Place: ${scan.placeName}. This part of it: ${scan.name}. ${scan.frames.length} frames from the walkthrough follow.`,
        },
      ];
      for (const f of scan.frames) {
        content.push({ type: "text", text: `Frame ${f.frame}:` });
        content.push({ type: "image", source: { type: "url", url: f.url } });
      }
      const response = await client.beta.messages.create({
        model: "claude-opus-5-5",
        max_tokens: 16000,
        // If a safety filter declines the request, let the API retry it on another model.
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        system: SYSTEM,
        output_config: { effort: "medium", format: zodOutputFormat(Analysis) },
        messages: [{ role: "user", content }],
      });
      if (response.stop_reason === "refusal") throw new Error("Claude declined to read this video");
      const text = response.content.find((block) => block.type === "text");
      if (!text || text.type !== "text") throw new Error("No analysis came back");
      const found = Analysis.parse(JSON.parse(text.text));
      const frames = scan.frames.map((f) => f.frame);
      await ctx.runMutation(internal.scans.saveAnalysis, {
        id,
        summary: found.summary,
        access: { wheelchair: found.wheelchair, reason: found.wheelchair_reason },
        features: found.features.slice(0, 6).map((f) => ({
          ...f,
          // Snap to a frame that was actually sent, so the feature can be placed in the 3D space.
          frame: frames.reduce((best, n) => (Math.abs(n - f.frame) < Math.abs(best - f.frame) ? n : best), frames[0]),
        })),
      });
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) console.error("Scan analysis: rate limited");
      else if (error instanceof Anthropic.APIError) console.error(`Scan analysis: API error ${error.status}: ${error.message}`);
      else console.error("Scan analysis failed:", error);
      await ctx.runMutation(internal.scans.failAnalysis, { id });
    }
  },
});
