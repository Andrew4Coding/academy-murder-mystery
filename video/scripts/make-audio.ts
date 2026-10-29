import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const SR = 44100;
const out = join(import.meta.dirname, "..", "public", "audio");
mkdirSync(out, { recursive: true });

const wav = (name: string, samples: Float32Array) => {
  const buf = Buffer.alloc(44 + samples.length * 2);
  buf.write("RIFF", 0);
  buf.writeUInt32LE(36 + samples.length * 2, 4);
  buf.write("WAVEfmt ", 8);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(SR, 24);
  buf.writeUInt32LE(SR * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write("data", 36);
  buf.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) {
    buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i])) * 32767), 44 + i * 2);
  }
  writeFileSync(join(out, name), buf);
};

const tone = (freq: number, t: number) => Math.sin(2 * Math.PI * freq * t);

const music = (seconds: number) => {
  const n = seconds * SR;
  const s = new Float32Array(n);
  const chords = [
    [110, 165, 220, 261.63],
    [87.31, 130.81, 174.61, 261.63],
    [98, 146.83, 196, 246.94],
    [82.41, 123.47, 164.81, 246.94],
  ];
  const chordLen = 8;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const ci = Math.floor(t / chordLen) % chords.length;
    const lt = t % chordLen;
    const env = Math.min(1, lt / 2) * Math.min(1, (chordLen - lt) / 2 + 0.2);
    let v = 0;
    for (const f of chords[ci]) v += tone(f, t) * 0.08 + tone(f * 1.003, t) * 0.05;
    const step = Math.floor(t * 2) % 8;
    const note = chords[ci][step % 4] * 2;
    const nt = (t * 2) % 1;
    v += tone(note, t) * 0.05 * Math.exp(-nt * 4);
    const g = Math.min(1, t / 3) * Math.min(1, (seconds - t) / 4);
    s[i] = v * env * g * 0.9;
  }
  return s;
};

const burst = (seconds: number, fn: (t: number) => number) => {
  const n = Math.floor(seconds * SR);
  const s = new Float32Array(n);
  for (let i = 0; i < n; i++) s[i] = fn(i / SR);
  return s;
};

wav("music.wav", music(172));
wav("chime.wav", burst(1.8, (t) => (tone(659, t) * 0.4 + tone(988, t) * 0.25) * Math.exp(-t * 2.5)));
console.log("audio written to", out);
