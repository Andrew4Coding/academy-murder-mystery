import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { FPS, timeline, TOTAL_FRAMES } from "../src/script";

const root = join(import.meta.dirname, "..");

const ts = (frame: number, srt = false) => {
  const ms = Math.round((frame / FPS) * 1000);
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  const s = Math.floor((ms % 60000) / 1000);
  const r = ms % 1000;
  const p = (n: number, w = 2) => String(n).padStart(w, "0");
  return srt ? `${p(h)}:${p(m)}:${p(s)},${p(r, 3)}` : `${p(m)}:${p(s)}.${p(Math.floor(r / 100), 1)}`;
};

let srt = "";
let md = `# Moonfall explainer: narration script\n\nTotal runtime: ${ts(TOTAL_FRAMES)} (${TOTAL_FRAMES} frames at ${FPS} fps).\nEdit \`src/script.ts\`, then run \`npm run script\` to regenerate this file and \`out/explainer.en.srt\`.\n`;
let n = 1;

for (const s of timeline) {
  md += `\n## ${s.title} (${ts(s.startFrame)} to ${ts(s.startFrame + s.durationInFrames)})\n\n`;
  md += "| Time | Line |\n|---|---|\n";
  for (const l of s.lines) {
    md += `| ${ts(l.startFrame)} | ${l.text} |\n`;
    srt += `${n++}\n${ts(l.startFrame + 3, true)} --> ${ts(l.endFrame - 6, true)}\n${l.text}\n\n`;
  }
}

mkdirSync(join(root, "out"), { recursive: true });
writeFileSync(join(root, "script.md"), md);
writeFileSync(join(root, "out", "explainer.en.srt"), srt);
console.log("wrote script.md and out/explainer.en.srt");
