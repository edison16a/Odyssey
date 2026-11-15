/*
 * Exports the mockup's hand drawn SVG art so the app shows exactly the
 * same pictures: the eleven engraved explorer portraits and the country
 * arrival scene and plane. The stamp carries today's date, so the app
 * builds it itself. The app draws them with SVGArtView.
 *
 *   node tools/export-art.mjs ../Odyssey/mockup Odyssey/Resources/Art
 */
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const [mockup, out] = process.argv.slice(2);
const html = fs.readFileSync(path.join(mockup, "main.html"), "utf8");
const wanted = /^(core\/(namespace|format|store)|data\/|ui\/(icons|engraving\/|flags)|features\/travel\/country-art)/;
const scripts = [...html.matchAll(/src="([^"]+)"/g)].map((m) => m[1]).filter((s) => wanted.test(s));

const store = {};
const window = {
  localStorage: { getItem: (k) => store[k] ?? null, setItem: (k, v) => (store[k] = v), removeItem: (k) => delete store[k] },
  addEventListener() {}, location: { protocol: "file:", search: "", hash: "" }, matchMedia: () => ({ matches: false, addEventListener() {} }),
};
window.window = window;
const context = vm.createContext({ window, localStorage: window.localStorage, document: { addEventListener() {}, querySelector: () => null }, console, Date, Math, navigator: {} });
for (const src of scripts) vm.runInContext(fs.readFileSync(path.join(mockup, src), "utf8"), context, { filename: src });

const P = vm.runInContext("window.Odyssey", context);
fs.mkdirSync(out, { recursive: true });
const write = (name, svg) => {
  const full = svg.includes("xmlns") ? svg : svg.replace("<svg", '<svg xmlns="http://www.w3.org/2000/svg"');
  fs.writeFileSync(path.join(out, name + ".svg"), full);
};
for (const explorer of P.data.explorers) write("portrait-" + explorer.id, P.ui.portrait(explorer, 300));
const trip = P.data.demoTrip;
write("country-scene", P.features.countryArt.scene(trip));
write("country-plane", P.features.countryArt.plane());
console.log(fs.readdirSync(out).join(" "));
