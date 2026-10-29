import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { Background, Moon, Token } from "../components/Common";
import { C, FONT, fade, kf, pop } from "../theme";

export const Intro: React.FC<{ L: number[] }> = ({ L }) => {
  const f = useCurrentFrame();
  const xs = [510, 680, 850, 1020, 1190, 1360];
  const wolves = [1, 4];
  const flip = kf(f, [[L[2] + 20, 0], [L[2] + 40, 1], [L[3] - 10, 1], [L[3] + 10, 0]]);
  const q = fade(f, L[3] + 10);
  return (
    <AbsoluteFill>
      <Background moonY={kf(f, [[0, 120], [60, 0]])} />
      <div style={{ position: "absolute", left: 0, right: 0, top: kf(f, [[0, 240], [50, 150]]), textAlign: "center", opacity: fade(f, 0, 24), transform: `translateY(${kf(f, [[0, 40], [30, 0]])}px)` }}>
        <div style={{ display: "flex", justifyContent: "center" }}>
          <Moon size={150} />
        </div>
        <div style={{ fontFamily: FONT, color: C.ink, fontSize: 120, fontWeight: 800, letterSpacing: 14, marginTop: 6 }}>MOONFALL</div>
        <div style={{ fontFamily: FONT, color: C.dim, fontSize: 34, fontWeight: 500, letterSpacing: 4, opacity: fade(f, 20) }}>A game of trust and suspicion</div>
      </div>
      <svg width={1920} height={1080} style={{ position: "absolute" }}>
        <path d="M0 800 L0 700 L120 700 L170 640 L220 700 L380 700 L380 660 L470 660 L470 700 L620 700 L670 630 L720 700 L900 700 L900 680 L1030 680 L1030 700 L1180 700 L1230 640 L1280 700 L1450 700 L1450 650 L1560 650 L1560 700 L1700 700 L1750 630 L1800 700 L1920 700 L1920 800 Z" fill="#070A1C" />
      </svg>
      {xs.map((x, i) => {
        const p = pop(f, L[1] + i * 5);
        const isW = wolves.includes(i);
        const col = isW ? (flip > 0.5 ? C.werewolf : C.villager) : C.villager;
        const glow = isW ? flip : 0;
        return (
          <React.Fragment key={i}>
            <Token x={x} y={700 - 20 * p} size={78 * p} color={col} ring={glow > 0.4 ? C.werewolf : undefined} opacity={p} />
            {q > 0 && (
              <div style={{ position: "absolute", left: x - 20, top: 590, width: 40, textAlign: "center", color: C.moon, fontFamily: FONT, fontSize: 48, fontWeight: 800, opacity: q }}>?</div>
            )}
          </React.Fragment>
        );
      })}
    </AbsoluteFill>
  );
};
