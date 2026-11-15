/*
 * Loads the app's bundled content into Convex: every image in the asset
 * catalog (places, people, categories, cities, indoor, brands...) and the
 * landing video go to Convex File Storage, keyed by the path the app uses
 * ("assets/media/places/doe-library.jpg"); then the places, OpenStreetMap
 * discover areas, bounties and the rest of seed.json go into tables.
 *
 * Safe to run again: files whose size has not changed are skipped.
 *
 *   SEED_SECRET=... node tools/convex-seed.mjs
 *
 * Reads CONVEX_URL from .env.local. SEED_SECRET must match the deployment's
 * env var of the same name (npx convex env set SEED_SECRET ...).
 */
import fs from "node:fs";
import path from "node:path";
import { ConvexHttpClient } from "convex/browser";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const env = Object.fromEntries(
  fs.readFileSync(path.join(root, ".env.local"), "utf8")
    .split("\n").map((l) => l.replace(/#.*/, "").trim()).filter(Boolean)
    .map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]),
);
const url = process.env.CONVEX_URL ?? env.CONVEX_URL;
const secret = process.env.SEED_SECRET;
if (!url || !secret) {
  console.error("Need CONVEX_URL (.env.local) and SEED_SECRET in the environment.");
  process.exit(1);
}
const client = new ConvexHttpClient(url);
const call = (name, args = {}) => client.mutation(name, { secret, ...args });

const seed = JSON.parse(fs.readFileSync(path.join(root, "Odyssey/Resources/seed.json"), "utf8"));
const catalog = path.join(root, "Odyssey/Media.xcassets");

/** Same as Media.name(for:) in Swift. */
function assetName(p) {
  let name = p;
  for (const prefix of ["assets/media/", "assets/vendor/", "assets/"]) {
    if (name.startsWith(prefix)) { name = name.slice(prefix.length); break; }
  }
  const dot = name.lastIndexOf(".");
  if (dot >= 0) name = name.slice(0, dot);
  return name.replaceAll("/", "-");
}

// Every media path the seed mentions, mapped to its asset catalog name.
const seedPaths = new Set();
JSON.stringify(seed, (_k, v) => {
  if (typeof v === "string" && /^assets\/.+\.(jpe?g|png|svg|webp)$/i.test(v)) seedPaths.add(v);
  return v;
});
const byAsset = new Map();
for (const p of seedPaths) byAsset.set(assetName(p), p);

const MIME = { ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".svg": "image/svg+xml", ".webp": "image/webp", ".mp4": "video/mp4" };

// Files to upload: [path the app knows, file on disk, kind]
const uploads = [];
for (const set of fs.readdirSync(catalog).filter((d) => d.endsWith(".imageset"))) {
  const name = set.replace(/\.imageset$/, "");
  const files = fs.readdirSync(path.join(catalog, set)).filter((f) => f !== "Contents.json");
  if (files.length === 0) continue;
  const file = path.join(catalog, set, files[0]);
  uploads.push([byAsset.get(name) ?? `xcassets/${name}${path.extname(file)}`, file, "seed-image"]);
}
const video = path.join(root, "Odyssey/Resources/landing-montage.mp4");
if (fs.existsSync(video)) uploads.push(["assets/media/video/landing-montage.mp4", video, "seed-video"]);
for (const dir of ["Odyssey/Resources/Art"]) {
  for (const f of fs.readdirSync(path.join(root, dir))) {
    uploads.push([`art/${f}`, path.join(root, dir, f), "seed-image"]);
  }
}

console.log(`Uploading ${uploads.length} files to ${url}`);
const have = await call("seed:mediaPaths");
let sent = 0;
let skipped = 0;
for (const [mediaPath, file, kind] of uploads) {
  const bytes = fs.readFileSync(file);
  if (have[mediaPath] === bytes.length) { skipped++; continue; }
  const uploadUrl = await call("seed:uploadUrl");
  const res = await fetch(uploadUrl, {
    method: "POST",
    headers: { "Content-Type": MIME[path.extname(file).toLowerCase()] ?? "application/octet-stream" },
    body: bytes,
  });
  if (!res.ok) throw new Error(`Upload failed for ${mediaPath}: ${res.status} ${await res.text()}`);
  const { storageId } = await res.json();
  await call("seed:registerMedia", { path: mediaPath, storageId, kind });
  sent++;
  if (sent % 20 === 0) console.log(`  ${sent} uploaded...`);
}
console.log(`Media: ${sent} uploaded, ${skipped} already there.`);
const missing = [...seedPaths].filter((p) => !uploads.some(([m]) => m === p));
if (missing.length) console.log(`Seed paths with no bundled file (left out): ${missing.length}`);

// Places: the curated seed places plus every discover area's OpenStreetMap places.
const clean = (o) => Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined && v !== null));
const places = seed.places.map((p) => clean({
  placeId: p.id,
  name: p.name,
  category: p.category,
  cats: p.cats ?? seed.categories?.[p.category]?.cats ?? undefined,
  lat: p.coords[0],
  lng: p.coords[1],
  area: p.area ?? "berkeley",
  address: p.address,
  blurb: p.blurb,
  hours: p.hours,
  rating: p.rating,
  reviews: p.reviews,
  website: p.website,
  tags: p.tags,
  source: "seed",
  photoPath: p.photo,
}));
for (const [area, data] of Object.entries(seed.discoverPlaces ?? {})) {
  for (const p of data.places ?? []) {
    places.push(clean({
      placeId: p.id,
      name: p.name,
      cats: p.cats ?? [],
      lat: p.lat,
      lng: p.lng,
      area,
      tags: p.tags ? Object.fromEntries(Object.entries(p.tags).map(([k, v]) => [k, String(v)])) : undefined,
      website: p.tags?.website,
      source: "osm",
    }));
  }
}
let inserted = 0;
let updated = 0;
for (let i = 0; i < places.length; i += 50) {
  const r = await call("seed:places", { places: places.slice(i, i + 50) });
  inserted += r.inserted;
  updated += r.updated;
}
console.log(`Places: ${inserted} new, ${updated} updated (${places.length} total).`);

await call("seed:bounties", { bounties: seed.bounties ?? [] });
console.log(`Bounties: ${(seed.bounties ?? []).length}.`);

// Everything else, one row per top-level key (Convex documents stay under 1 MB).
const skip = new Set(["places", "discoverPlaces", "initialState", "bounties"]);
const entries = Object.entries(seed).filter(([k]) => !skip.has(k)).map(([key, value]) => ({ key, value }));
for (const entry of entries) {
  const size = JSON.stringify(entry.value).length;
  if (size > 900_000) { console.log(`  skipping ${entry.key} (${size} bytes, too large for one document)`); continue; }
  await call("seed:content", { entries: [entry] });
}
console.log(`Seed content: ${entries.length} keys.`);
console.log("Done.");
