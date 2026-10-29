import { loadFont } from "@remotion/google-fonts/Inter";
import { Easing, interpolate, spring } from "remotion";

const inter = loadFont("normal", { weights: ["400", "500", "600", "700", "800"], subsets: ["latin"] });

export const FONT = `${inter.fontFamily}, -apple-system, "SF Pro Display", system-ui, sans-serif`;

export const C = {
  bg: "#0B1026",
  bg2: "#151C42",
  panel: "#1C2552",
  panel2: "#27316A",
  line: "rgba(255,255,255,0.12)",
  ink: "#F4F6FF",
  dim: "#9EA8D6",
  moon: "#FFE9A8",
  villager: "#0A84FF",
  werewolf: "#FF453A",
  ok: "#30D158",
  warn: "#FF9F0A",
};

export const ease = Easing.bezier(0.22, 1, 0.36, 1);

export const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

export const fade = (f: number, start: number, dur = 14) =>
  interpolate(f, [start, start + dur], [0, 1], { ...clamp, easing: ease });

export const fadeOut = (f: number, end: number, dur = 14) =>
  interpolate(f, [end - dur, end], [1, 0], { ...clamp, easing: ease });

export const pop = (f: number, start: number) =>
  Math.max(0, spring({ frame: f - start, fps: 30, config: { damping: 15, stiffness: 150, mass: 0.8 } }));

export const kf = (f: number, pts: [number, number][]) =>
  interpolate(
    f,
    pts.map((p) => p[0]),
    pts.map((p) => p[1]),
    { ...clamp, easing: ease },
  );
