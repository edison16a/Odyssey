/*
 * Renders the engraved explorer portraits (exported by export-art.mjs)
 * to transparent PNGs in the asset catalog, so the app shows them as plain
 * images instead of loading a web view for each one. Needs Playwright
 * and Pillow.
 *
 *   node tools/render-portraits.mjs Odyssey/Resources/Art Odyssey/Media.xcassets
 */
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const [artDir, catalog] = process.argv.slice(2);
const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 3, viewport: { width: 200, height: 240 } });
for (const file of fs.readdirSync(artDir).filter((f) => f.startsWith("portrait-"))) {
  const name = file.replace(".svg", "");
  const svg = fs.readFileSync(path.join(artDir, file), "utf8").replace(/width="\d+" height="\d+"/, 'width="200" height="240"');
  await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
  const folder = path.join(catalog, `${name}.imageset`);
  fs.mkdirSync(folder, { recursive: true });
  await page.locator("svg").screenshot({ path: path.join(folder, `${name}.png`), omitBackground: true });
  fs.writeFileSync(path.join(folder, "Contents.json"), JSON.stringify({ images: [{ filename: `${name}.png`, idiom: "universal" }], info: { author: "xcode", version: 1 } }, null, 2));
  console.log(name, (fs.statSync(path.join(folder, `${name}.png`)).size / 1024).toFixed(0) + " KB");
}
await browser.close();

// The engravings use few colors, so a 48 color palette keeps them identical at a sixth of the size.
const files = fs.readdirSync(catalog).filter((d) => d.startsWith("portrait-")).map((d) => path.join(catalog, d, d.replace(".imageset", ".png")));
execFileSync("python3", ["-c", "import sys\nfrom PIL import Image\nfor f in sys.argv[1:]:\n    Image.open(f).convert('RGBA').quantize(colors=48, method=Image.Quantize.FASTOCTREE).save(f, optimize=True)", ...files]);
