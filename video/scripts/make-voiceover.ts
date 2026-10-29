import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { scenes } from "../src/script";

const root = join(import.meta.dirname, "..");
process.loadEnvFile(join(root, ".env"));

const key: string = process.env.ELEVENLABS_API_KEY ?? "";
if (!key) throw new Error("ELEVENLABS_API_KEY missing from video/.env");

const VOICE_ID = "nPczCjzI2devNBz1zQrb";
const MODEL = "eleven_multilingual_v2";
const dir = join(root, "public", "audio", "vo");
mkdirSync(dir, { recursive: true });

async function main() {
  const lines = scenes.flatMap((s) => s.lines.map((l) => ({ scene: s.id, text: l.text })));
  const manifest: { file: string; seconds: number }[] = [];

  for (let i = 0; i < lines.length; i++) {
    const name = `${String(i + 1).padStart(2, "0")}-${lines[i].scene}.mp3`;
    const path = join(dir, name);
    if (!existsSync(path)) {
      const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}?output_format=mp3_44100_128`, {
        method: "POST",
        headers: { "xi-api-key": key, "Content-Type": "application/json" },
        body: JSON.stringify({
          text: lines[i].text,
          model_id: MODEL,
          previous_text: lines[i - 1]?.text,
          next_text: lines[i + 1]?.text,
          voice_settings: { stability: 0.45, similarity_boost: 0.8, style: 0.4, speed: 0.9, use_speaker_boost: true },
        }),
      });
      if (!res.ok) throw new Error(`line ${i + 1}: ${res.status} ${await res.text()}`);
      writeFileSync(path, Buffer.from(await res.arrayBuffer()));
      console.log("generated", name);
    }
    const seconds = Number(
      execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).toString().trim(),
    );
    manifest.push({ file: `audio/vo/${name}`, seconds: Math.round(seconds * 100) / 100 });
  }

  writeFileSync(join(root, "src", "voiceover.json"), JSON.stringify(manifest, null, 2) + "\n");
  console.log(`wrote src/voiceover.json (${manifest.length} lines)`);
}

main();
