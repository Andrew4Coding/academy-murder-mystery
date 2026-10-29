import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { Background, Heading } from "../components/Common";
import { MapBoard, Spot } from "../components/MapBoard";
import { fade, kf } from "../theme";

export const MapScene: React.FC<{ L: number[] }> = ({ L }) => {
  const f = useCurrentFrame();
  const booths: Spot[] = ["b1", "b2", "b3", "b4", "b5", "b6", "b7"];
  const reveal: Partial<Record<Spot, number>> = { photobooth: fade(f, L[1] + 70), s1: fade(f, L[2]), s2: fade(f, L[2] + 8) };
  reveal.townhall = fade(f, L[1]);
  booths.forEach((b, i) => (reveal[b] = fade(f, L[1] + 18 + i * 7)));
  const beat = 0.5 + 0.5 * Math.sin(f / 5);
  const pulse: Partial<Record<Spot, number>> = {};
  if (f >= L[1] && f < L[1] + 60) pulse.townhall = beat;
  if (f >= L[2]) {
    pulse.s1 = beat;
    pulse.s2 = beat;
  }
  return (
    <AbsoluteFill>
      <Background />
      <Heading kicker="The map" />
      <div style={{ position: "absolute", left: 110, top: -50, opacity: fade(f, 0, 20), transform: `scale(${1.1 * kf(f, [[0, 0.96], [40, 1]])})`, transformOrigin: "top left" }}>
        <MapBoard reveal={Object.fromEntries(Object.entries(reveal).map(([k, v]) => [k, v as number])) as Partial<Record<Spot, number>>} pulse={pulse} />
      </div>
    </AbsoluteFill>
  );
};
