/*
 * Exports the HTML mockup's data into one JSON file the iOS app bundles.
 * It runs the mockup's core and data scripts in a sandbox, then writes
 * everything that is plain data (functions are dropped) to seed.json.
 *
 *   node tools/export-seed.mjs ../Odyssey/mockup Odyssey/Resources/seed.json
 */
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const [mockup, out] = process.argv.slice(2);
const html = fs.readFileSync(path.join(mockup, "main.html"), "utf8");
const scripts = [...html.matchAll(/src="([^"]+)"/g)].map((m) => m[1])
  .filter((src) => /^(core|data)\//.test(src) && !src.includes("router"));

const store = {};
const window = {
  localStorage: { getItem: (k) => store[k] ?? null, setItem: (k, v) => (store[k] = v), removeItem: (k) => delete store[k] },
  addEventListener() {},
  location: { protocol: "file:", search: "" },
  matchMedia: () => ({ matches: false, addEventListener() {} }),
};
window.window = window;
const context = vm.createContext({ window, localStorage: window.localStorage, document: { addEventListener() {}, querySelector: () => null }, console, Date, Math, navigator: {} });
for (const src of scripts) vm.runInContext(fs.readFileSync(path.join(mockup, src), "utf8"), context, { filename: src });

const data = vm.runInContext("window.Odyssey.data", context);
const plain = JSON.parse(JSON.stringify(data, (k, v) => (typeof v === "function" ? undefined : v)));
plain.initialState = JSON.parse(JSON.stringify(vm.runInContext("window.Odyssey.core.store.get()", context)));

// The hackathon is at Y Combinator (560 20th St), so the app starts with it unexplored:
// checking in there makes you its first explorer and lights it up on the map.
const yc = plain.places.find((p) => p.id === "yc");
if (yc) yc.status = "unexplored";
for (const recap of plain.recaps) recap.stops = recap.stops.filter((stop) => stop.placeId !== "yc");

// The app is called Odyssey now; keys like onOdyssey stay as they are.
const renamed = JSON.stringify(plain, (key, value) => (typeof value === "string" ? value.replace(/\bOdyssey\b/g, "Odyssey") : value));
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, renamed);
console.log(Object.keys(plain).map((k) => k + ":" + (Array.isArray(plain[k]) ? plain[k].length : typeof plain[k])).join("  "));
console.log((fs.statSync(out).size / 1024).toFixed(0) + " KB");
