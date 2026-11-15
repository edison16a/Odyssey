/*
 * Renders Globie, every streak form in every mood, from the mockup's own
 * SVG into the widget extension's asset catalog. Widgets cannot draw
 * Globie's Canvas, so they show these pictures instead.
 *
 *   node tools/render-globies.mjs ../Pathy/mockup
 *
 * Each picture is 390 px square with Globie's 300 px art centred, the same
 * proportions the app's Canvas uses, then cut down to a 256 colour PNG.
 * Needs Playwright and Pillow.
 */
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const mockup = path.resolve(process.argv[2] || "../Pathy/mockup");
const catalog = path.resolve("OdysseyWidgets/Assets.xcassets");
const forms = ["classic", "glow", "spark", "fire", "galaxy", "gold", "aurora", "crystal", "supernova", "eclipse", "legend"];
const moods = ["happy", "ecstatic", "sleepy", "sad"];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 600, height: 600 }, deviceScaleFactor: 1 });
await page.goto("file://" + path.join(mockup, "main.html"));
await page.waitForFunction(() => window.Pathy?.ui?.globeBuddy);
await page.addStyleTag({
  content: `
    html, body { background: transparent !important; }
    body > *:not(#shot) { display: none !important; }
    #shot { position: fixed; left: 0; top: 0; width: 390px; height: 390px; padding: 45px; box-sizing: border-box; }
    #shot * { animation-play-state: paused !important; animation-delay: -0.8s !important; transition: none !important; }
    #shot .gb-body, #shot .gb-shadow { animation: none !important; }`,
});

for (const form of forms) {
  for (const mood of moods) {
    const name = `globie-${form}-${mood}`;
    const dir = path.join(catalog, `${name}.imageset`);
    fs.mkdirSync(dir, { recursive: true });
    await page.evaluate(([form, mood]) => {
      let el = document.getElementById("shot");
      if (!el) {
        el = document.createElement("div");
        el.id = "shot";
        document.body.appendChild(el);
      }
      el.innerHTML = window.Pathy.ui.globeBuddy(mood, 300, form);
    }, [form, mood]);
    await page.waitForTimeout(60);
    const file = path.join(dir, `${name}.png`);
    await page.locator("#shot").screenshot({ path: file, omitBackground: true });
    // A 256 colour palette keeps all 44 pictures near 240 KB.
    execFileSync("python3", ["-c",
      "import sys;from PIL import Image;im=Image.open(sys.argv[1]).convert('RGBA');" +
      "im.quantize(colors=256,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE).save(sys.argv[1],optimize=True)", file]);
    fs.writeFileSync(path.join(dir, "Contents.json"),
      JSON.stringify({ images: [{ filename: `${name}.png`, idiom: "universal" }], info: { author: "xcode", version: 1 } }, null, 2));
  }
}
await browser.close();
console.log(`Rendered ${forms.length * moods.length} Globies into ${catalog}`);
