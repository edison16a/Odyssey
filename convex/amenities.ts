// Demo amenities: what each SF place has (wifi, seating, bathroom...) and
// public bathrooms, elevators and water near them for the map.
//
//   npx convex run amenities:seed '{}'

import { internalMutation, query } from "./_generated/server";

const SF = ["sf-dogpatch", "sf-mission", "sf"];

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

function featuresFor(cats: string, r: () => number): string[] {
  const out = new Set<string>();
  const add = (f: string, p = 1) => { if (r() < p) out.add(f); };
  if (/cafe|coffee|bakery|library|study|cowork|office/.test(cats)) {
    add("wifi"); add("seating"); add("outlets", 0.8); add("bathroom", 0.85); add("quiet", /library|study/.test(cats) ? 1 : 0.35);
  } else if (/restaurant|food|pizza|fast|deli|dessert|ice/.test(cats)) {
    add("seating"); add("bathroom", 0.9); add("wifi", 0.45); add("outlets", 0.2);
  } else if (/bar|pub|brew|night/.test(cats)) {
    add("seating"); add("bathroom"); add("wifi", 0.3);
  } else if (/park|outdoor|garden|beach|view|playground/.test(cats)) {
    add("seating", 0.8); add("bathroom", 0.4); add("wifi", 0.15);
  } else if (/museum|gallery|art|theatre|cinema|landmark|entertainment|campus/.test(cats)) {
    add("bathroom"); add("elevator", 0.7); add("seating", 0.6); add("wifi", 0.5);
  } else if (/fitness|gym|sport|climb/.test(cats)) {
    add("wifi", 0.7); add("bathroom"); add("seating", 0.3);
  } else if (/shop|store|market|book/.test(cats)) {
    add("bathroom", 0.3); add("wifi", 0.3); add("seating", 0.3);
  } else {
    add("seating", 0.5); add("bathroom", 0.4); add("wifi", 0.4);
  }
  add("accessible", 0.65);
  return [...out];
}

const TRANSIT = [
  { name: "22nd St Caltrain", lat: 37.7575, lng: -122.3925 },
  { name: "16th St Mission BART", lat: 37.7650, lng: -122.4197 },
  { name: "24th St Mission BART", lat: 37.7522, lng: -122.4184 },
  { name: "UCSF Mission Bay", lat: 37.7680, lng: -122.3893 },
  { name: "Chase Center", lat: 37.7680, lng: -122.3877 },
  { name: "4th & King Caltrain", lat: 37.7766, lng: -122.3948 },
];

/** Tag every SF place with amenities and put public bathrooms, elevators and water on the map. */
export const seed = internalMutation({
  args: {},
  handler: async (ctx) => {
    for (const old of await ctx.db.query("amenities").collect()) await ctx.db.delete(old._id);
    let tagged = 0;
    let points = 0;
    for (const area of SF) {
      const places = await ctx.db.query("places").withIndex("by_area", (q) => q.eq("area", area)).collect();
      for (const p of places) {
        const r = rng(p.placeId + "amenity");
        const cats = [...(p.cats ?? []), p.category ?? ""].join(" ").toLowerCase();
        const features = featuresFor(cats, r);
        await ctx.db.patch(p._id, { features });
        tagged++;
        // Parks and landmarks with a bathroom get a public restroom pin beside them.
        const jitter = () => (r() - 0.5) * 0.0012;
        if (features.includes("bathroom") && /park|outdoor|garden|landmark|museum|plaza/.test(cats)) {
          await ctx.db.insert("amenities", {
            kind: "bathroom", name: `Public restroom · ${p.name}`, lat: p.lat + jitter(), lng: p.lng + jitter(), area,
            note: r() < 0.5 ? "Open 7 AM to 8 PM" : "Open during park hours", access: "public", placeId: p.placeId,
          });
          points++;
        } else if (features.includes("bathroom") && r() < 0.18) {
          await ctx.db.insert("amenities", {
            kind: "bathroom", name: `Restroom · ${p.name}`, lat: p.lat, lng: p.lng, area,
            note: "Ask at the counter", access: "customers", placeId: p.placeId,
          });
          points++;
        }
        if (features.includes("elevator")) {
          await ctx.db.insert("amenities", {
            kind: "elevator", name: `Elevator · ${p.name}`, lat: p.lat + jitter(), lng: p.lng + jitter(), area,
            note: "Step-free entrance", access: "public", placeId: p.placeId,
          });
          points++;
        }
        if (/park|outdoor|playground/.test(cats) && r() < 0.5) {
          await ctx.db.insert("amenities", {
            kind: "water", name: `Water fountain · ${p.name}`, lat: p.lat + jitter(), lng: p.lng + jitter(), area,
            note: "Bottle filler", access: "public", placeId: p.placeId,
          });
          points++;
        }
        if (features.includes("wifi") && /library|park|plaza/.test(cats)) {
          await ctx.db.insert("amenities", {
            kind: "wifi", name: `Free wifi · ${p.name}`, lat: p.lat, lng: p.lng, area,
            note: r() < 0.5 ? "#SFWiFi, no password" : "Network: guest", access: "public", placeId: p.placeId,
          });
          points++;
        }
      }
    }
    for (const t of TRANSIT) {
      await ctx.db.insert("amenities", { kind: "elevator", name: `Elevator · ${t.name}`, lat: t.lat, lng: t.lng, area: "sf", note: "Street to platform", access: "public" });
      await ctx.db.insert("amenities", { kind: "bathroom", name: `Restroom · ${t.name}`, lat: t.lat + 0.0003, lng: t.lng - 0.0003, area: "sf", note: "Station restroom", access: "public" });
      points += 2;
    }
    return { tagged, points };
  },
});

/** Everything the app needs: amenity tags by place and the public amenity pins. */
export const demo = query({
  args: {},
  handler: async (ctx) => {
    const features: Record<string, string[]> = {};
    for (const area of SF) {
      const places = await ctx.db.query("places").withIndex("by_area", (q) => q.eq("area", area)).collect();
      for (const p of places) if (p.features?.length) features[p.placeId] = p.features;
    }
    const points = (await ctx.db.query("amenities").collect()).map((a) => ({
      verified: a.verified ?? false, id: a._id, kind: a.kind, name: a.name, lat: a.lat, lng: a.lng, note: a.note, access: a.access, placeId: a.placeId ?? null,
    }));
    return { features, points };
  },
});
