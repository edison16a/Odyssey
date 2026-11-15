// The Odyssey database.
//
// Shared content (places, seed media, demo explorers) lives next to each
// explorer's own data (profile, check-ins, walkthroughs, votes, posts,
// friends, bounties). `userState` keeps the app's full on-phone state as a
// snapshot, so settings that have no table of their own (widgets, equipped
// cosmetics, footprints...) still follow you to a new phone.

import { defineSchema, defineTable } from "convex/server";
import { authTables } from "@convex-dev/auth/server";
import { v } from "convex/values";

const coord = v.object({ lat: v.number(), lng: v.number() });

const insights = v.object({
  vibe: v.optional(v.string()),
  summary: v.optional(v.string()),
  tags: v.optional(v.array(v.string())),
  source: v.optional(v.string()),
});

export default defineSchema({
  ...authTables,

  /** Text-in sign-ins: a code the user texts to the Odyssey line (see phoneAuth.ts). */
  phoneLogins: defineTable({
    code: v.string(),
    nonce: v.string(),
    status: v.string(), // "pending" | "confirmed" | "used"
    phone: v.optional(v.string()),
    expiresAt: v.number(),
    createdAt: v.number(),
    confirmedAt: v.optional(v.number()),
  })
    .index("by_code", ["code"])
    .index("by_nonce", ["nonce"]),

  // ── Explorers ────────────────────────────────────────────────────────
  profiles: defineTable({
    userId: v.id("users"),
    email: v.optional(v.string()),
    name: v.string(),
    handle: v.string(),
    bio: v.string(),
    city: v.string(),
    avatarKind: v.string(), // "photo" (seed path), "upload" (storage) or "none"
    avatarPath: v.optional(v.string()),
    avatarStorageId: v.optional(v.id("_storage")),
    interests: v.array(v.string()),
    onboarded: v.boolean(),
    coins: v.number(),
    xp: v.number(),
    points: v.number(),
    cash: v.number(),
    streakDays: v.number(),
    streakBest: v.number(),
    streakLastDay: v.optional(v.string()),
    explored: v.number(),
    contributions: v.number(),
    firsts: v.number(),
    km: v.number(),
    /** Set on the seeded demo explorers ("nina"), so the app can match them to its seed people. */
    demoId: v.optional(v.string()),
    /** Cosmetics and other seed extras: frame, rank, effect, icon, banner. */
    extra: v.optional(v.any()),
    updatedAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_demoId", ["demoId"])
    .index("by_handle", ["handle"])
    .index("by_xp", ["xp"])
    .index("by_city_xp", ["city", "xp"]),

  /** The app's whole AppState JSON, last write wins. */
  userState: defineTable({
    userId: v.id("users"),
    version: v.number(),
    state: v.any(),
    updatedAt: v.number(),
  }).index("by_user", ["userId"]),

  // ── Places and media ────────────────────────────────────────────────
  places: defineTable({
    placeId: v.string(), // seed id ("doe") or OpenStreetMap id ("n123...")
    name: v.string(),
    category: v.optional(v.string()),
    cats: v.array(v.string()),
    lat: v.number(),
    lng: v.number(),
    area: v.optional(v.string()),
    address: v.optional(v.string()),
    blurb: v.optional(v.string()),
    hours: v.optional(v.string()),
    rating: v.optional(v.number()),
    reviews: v.optional(v.number()),
    website: v.optional(v.string()),
    tags: v.optional(v.record(v.string(), v.string())),
    source: v.string(), // "seed" | "osm" | "user"
    photoPath: v.optional(v.string()),
    photoStorageId: v.optional(v.id("_storage")),
    explorerCount: v.number(),
    contributionCount: v.number(),
    firstExplorerId: v.optional(v.id("users")),
    firstExploredAt: v.optional(v.number()),
    insights: v.optional(insights),
    updatedAt: v.number(),
  })
    .index("by_placeId", ["placeId"])
    .index("by_area", ["area"])
    .searchIndex("search_name", { searchField: "name", filterFields: ["area"] }),

  /** Every image or video in storage, by the path the app knows it by. */
  media: defineTable({
    path: v.string(), // "assets/media/places/doe-library.jpg" or "user/<id>/<file>"
    storageId: v.id("_storage"),
    kind: v.string(), // "seed-image" | "seed-video" | "checkin-photo" | "selfie" | "avatar" | "walkthrough"
    contentType: v.string(),
    bytes: v.number(),
    ownerId: v.optional(v.id("users")),
    placeId: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_path", ["path"])
    .index("by_owner", ["ownerId"])
    .index("by_kind", ["kind"]),

  /** The rest of the seed (people, quests, ranks, badges, cosmetics...), one row per key. */
  seedContent: defineTable({
    key: v.string(),
    value: v.any(),
    updatedAt: v.number(),
  }).index("by_key", ["key"]),

  // ── Adventures and contributions ────────────────────────────────────
  checkins: defineTable({
    userId: v.id("users"),
    placeId: v.string(),
    placeName: v.string(),
    day: v.string(),
    caption: v.string(),
    photoStorageId: v.optional(v.id("_storage")),
    selfieStorageId: v.optional(v.id("_storage")),
    first: v.boolean(),
    recommended: v.boolean(),
    coins: v.number(),
    xp: v.number(),
    points: v.number(),
    questId: v.optional(v.string()),
    lat: v.optional(v.number()),
    lng: v.optional(v.number()),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_place", ["placeId"])
    .index("by_user_place_day", ["userId", "placeId", "day"]),

  /** Walkthrough videos. Raw video is never public; only verified insights reach the place page. */
  contributions: defineTable({
    userId: v.id("users"),
    placeId: v.string(),
    placeName: v.string(),
    kind: v.string(), // "walkthrough"
    seconds: v.number(),
    videoStorageId: v.optional(v.id("_storage")),
    insights: v.optional(insights),
    status: v.string(), // "pending" | "verified" | "rejected"
    bountyId: v.optional(v.string()),
    points: v.number(),
    /** "seed" for the demo history written by seed:contributionHistory. */
    source: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_place", ["placeId"])
    .index("by_status", ["status"])
    .index("by_source", ["source"]),

  // ── Taste and recommendations ───────────────────────────────────────
  /** Every signal the explorer gives: swipes, stars, check-ins, walkthroughs. */
  tasteEvents: defineTable({
    userId: v.id("users"),
    placeId: v.string(),
    placeName: v.string(),
    kind: v.string(), // "vote" | "checkin" | "walkthrough" | "star" | "interests"
    value: v.number(), // +1, -1, 0 (undo)
    features: v.array(v.string()),
    city: v.optional(v.string()),
    memoryStatus: v.string(), // "pending" | "sent" | "failed" | "skipped"
    memoryError: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_place", ["userId", "placeId"]),

  /** Learned feature weights and the current vote per place. */
  taste: defineTable({
    userId: v.id("users"),
    weights: v.record(v.string(), v.number()),
    votes: v.array(
      v.object({ placeId: v.string(), name: v.string(), v: v.number(), features: v.array(v.string()), at: v.number() }),
    ),
    updatedAt: v.number(),
  }).index("by_user", ["userId"]),

  /** What was recommended and why, so the ranking can be audited and avoid repeats. */
  recommendations: defineTable({
    userId: v.id("users"),
    city: v.optional(v.string()),
    picks: v.array(v.object({ placeId: v.string(), score: v.number(), reason: v.string() })),
    memoriesUsed: v.number(),
    profileFacts: v.array(v.string()),
    usedSupermemory: v.boolean(),
    createdAt: v.number(),
  }).index("by_user", ["userId"]),

  // ── Social ──────────────────────────────────────────────────────────
  posts: defineTable({
    userId: v.id("users"),
    clientId: v.string(),
    placeId: v.string(),
    kind: v.string(), // "visit" | "walk" | "milestone" | "day"
    caption: v.string(),
    first: v.boolean(),
    seconds: v.optional(v.number()),
    photoStorageId: v.optional(v.id("_storage")),
    selfieStorageId: v.optional(v.id("_storage")),
    likes: v.number(),
    comments: v.number(),
    extra: v.optional(v.any()),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_client", ["userId", "clientId"])
    .index("by_created", ["createdAt"]),

  likes: defineTable({ userId: v.id("users"), postKey: v.string(), createdAt: v.number() })
    .index("by_user_post", ["userId", "postKey"])
    .index("by_post", ["postKey"]),

  friendships: defineTable({
    userId: v.id("users"),
    friendKey: v.string(), // another user's id, or a seed person id ("nina")
    status: v.string(), // "friends" | "requested" | "incoming"
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_friend", ["userId", "friendKey"]),

  savedPlaces: defineTable({
    userId: v.id("users"),
    placeId: v.string(),
    kind: v.string(), // "starred" | "saved"
    place: v.any(),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_place_kind", ["userId", "placeId", "kind"]),

  // ── Business bounties and rewards ───────────────────────────────────
  bounties: defineTable({
    ownerId: v.optional(v.id("users")), // empty for seeded bounties
    bountyId: v.string(),
    data: v.any(),
    active: v.boolean(),
    createdAt: v.number(),
  })
    .index("by_bountyId", ["bountyId"])
    .index("by_owner", ["ownerId"]),

  giftCards: defineTable({
    userId: v.id("users"),
    brand: v.string(),
    amount: v.number(),
    code: v.string(),
    day: v.string(),
    createdAt: v.number(),
  }).index("by_user", ["userId"]),

  // ── 3D scans ─────────────────────────────────────────────────────────
  // A walkthrough video and the 3D space a render worker builds from it.
  scans: defineTable({
    userId: v.optional(v.id("users")),
    placeId: v.string(),
    placeName: v.string(),
    name: v.optional(v.string()), // what the explorer called this space: "Main hall", "Kitchen"
    creatorName: v.optional(v.string()),
    // Scans are made without signing in, so the phone that made one proves it with a private key.
    // Only that phone may delete the scan. Never sent back to other phones.
    ownerKey: v.optional(v.string()),
    replaces: v.optional(v.id("scans")), // a re-render: the older scan goes when this one is ready
    lat: v.number(),
    lng: v.number(),
    videoId: v.id("_storage"),
    seconds: v.number(),
    status: v.string(), // "queued", "processing", "ready" or "failed"
    message: v.string(), // what is happening right now, shown on the phone
    progress: v.number(), // 0 to 1
    worker: v.optional(v.string()),
    modelId: v.optional(v.id("_storage")), // the splat file the phone renders
    meta: v.optional(v.string()), // JSON: up direction and the recorded path
    splats: v.optional(v.number()),
    // What the video shows of the building: stairs, doors, seating... Read from a few frames by Claude.
    frames: v.optional(v.array(v.object({ frame: v.number(), storageId: v.id("_storage") }))),
    analysis: v.optional(v.string()), // "pending", "done" or "failed"
    summary: v.optional(v.string()),
    features: v.optional(
      v.array(
        v.object({
          kind: v.string(), // "stairs", "elevator", "restroom"...
          label: v.string(),
          detail: v.string(),
          wheelchair: v.string(), // "barrier", "helps" or "neutral"
          certainty: v.string(), // "seen" (clearly in the video) or "likely"
          frame: v.number(), // the video frame it shows best in, which places it in the 3D space
        }),
      ),
    ),
    access: v.optional(v.object({ wheelchair: v.string(), reason: v.string() })),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_place", ["placeId"])
    .index("by_status", ["status"]),
});
