import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { Background, Check, Heading, Moon, Token } from "../components/Common";
import { C, FONT, fade, fadeOut, kf, pop } from "../theme";

const Card: React.FC<{ role: "villager" | "werewolf"; items: [string, number][]; x: number; o: number; dim: number }> = ({ role, items, x, o, dim }) => {
  const col = role === "villager" ? C.villager : C.werewolf;
  return (
    <div style={{ position: "absolute", left: x, top: 240, width: 700, padding: 44, borderRadius: 40, background: C.panel, boxShadow: `inset 0 0 0 4px ${col}`, opacity: o * dim, fontFamily: FONT }}>
      <div style={{ fontSize: 54, fontWeight: 800, color: col === C.villager ? "#6BB4FF" : "#FF8A82", marginBottom: 32 }}>
        {role === "villager" ? "Villagers win when" : "Werewolves win when"}
      </div>
      {items.map(([t, io]) => (
        <div key={t} style={{ opacity: io, display: "flex", alignItems: "center", gap: 18, fontSize: 36, fontWeight: 600, color: C.ink, marginBottom: 24 }}>
          <Check size={38} color={col} />
          {t}
        </div>
      ))}
    </div>
  );
};

const teams = [0, 1, 2, 3, 4, 5];
const wolfAt = [1, 4];

export const WinScene: React.FC<{ L: number[]; D: number }> = ({ L, D }) => {
  const f = useCurrentFrame();
  const cards = fade(f, 0, 14) * (1 - fade(f, L[2] - 4, 12));
  const vDim = f < L[1] ? 1 : 0.4;
  const wDim = f < L[1] ? 0.4 : 1;
  const wolfItems = ["Villagers are outnumbered or tied", "The final vote fails", "A sabotage runs out the clock"];
  const clock = fade(f, L[2], 14) * (1 - fade(f, L[3] - 4, 12));
  const vote = fade(f, L[3], 14) * (1 - fade(f, L[4] - 4, 12));
  const caseB = f >= L[3] + 110;
  const bars = [2, 4, 1, 1, 4, 2];
  const barsB = [1, 2, 4, 1, 3, 2];
  const use = caseB ? barsB : bars;
  const topN = caseB ? [2, 4] : [1, 4];
  const grow = kf(f, [[L[3] + 20, 0], [L[3] + 70, 1]]) * (caseB ? kf(f, [[L[3] + 110, 0], [L[3] + 150, 1]]) : 1);
  const end = fade(f, L[4], 20);
  const win = caseB ? kf(f, [[L[3] + 170, 0], [L[3] + 185, 1]]) : kf(f, [[L[3] + 78, 0], [L[3] + 92, 1]]);
  return (
    <AbsoluteFill>
      <Background />
      <Heading kicker="Winning" opacity={1 - end} />
      <Card role="villager" x={160} o={cards} dim={vDim} items={[["Every team finishes its tasks", 1], ["Every werewolf is voted out", 1]]} />
      <Card role="werewolf" x={1060} o={cards} dim={wDim} items={[[wolfItems[0], 1], [wolfItems[1], fade(f, L[1] + 90)], [wolfItems[2], fade(f, L[1] + 115)]]} />
      <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", flexDirection: "column", opacity: clock, fontFamily: FONT, paddingBottom: 120 }}>
        <div style={{ fontSize: 260, fontWeight: 800, color: C.ink, letterSpacing: -8, fontVariantNumeric: "tabular-nums" }}>45:00</div>
        <div style={{ fontSize: 44, fontWeight: 700, color: C.moon }}>Final vote at Town Hall</div>
      </div>
      <div style={{ position: "absolute", inset: 0, opacity: vote, fontFamily: FONT }}>
        <div style={{ position: "absolute", left: 0, right: 0, top: 140, textAlign: "center", fontSize: 44, fontWeight: 700, color: C.ink }}>
          2 werewolves left, so the top 2 teams are expelled
        </div>
        {teams.map((t, i) => {
          const x = 380 + i * 235;
          const isW = wolfAt.includes(i);
          const expelled = topN.includes(i) && grow > 0.95;
          return (
            <React.Fragment key={t}>
              <div style={{ position: "absolute", left: x - 34, top: 680 - use[i] * 65 * grow, width: 68, height: use[i] * 65 * grow, borderRadius: 14, background: expelled ? C.moon : C.panel2 }} />
              <Token x={x} y={745} size={78} color={expelled && isW ? C.werewolf : C.villager} ring={expelled ? C.moon : undefined} />
              {expelled && (
                <div style={{ position: "absolute", left: x - 90, top: 800, width: 180, textAlign: "center", fontSize: 26, fontWeight: 800, color: isW ? C.werewolf : C.moon }}>
                  {isW ? "Werewolf" : "Villager"}
                </div>
              )}
              {caseB && isW && !expelled && win > 0.5 && (
                <div style={{ position: "absolute", left: x - 90, top: 800, width: 180, textAlign: "center", fontSize: 26, fontWeight: 800, color: C.werewolf }}>Still hiding</div>
              )}
            </React.Fragment>
          );
        })}
        <div style={{ position: "absolute", left: 0, right: 0, top: 250, textAlign: "center", fontSize: 60, fontWeight: 800, color: caseB ? C.werewolf : C.ok, opacity: win, transform: `scale(${0.9 + 0.1 * win})` }}>
          {caseB ? "A werewolf slipped through: Werewolves win" : "Both werewolves caught: Villagers win"}
        </div>
      </div>
      <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", flexDirection: "column", opacity: end, fontFamily: FONT, paddingBottom: 100 }}>
        <Moon size={190} />
        <div style={{ fontSize: 110, fontWeight: 800, color: C.ink, marginTop: 10, letterSpacing: 8 }}>TRUST NO ONE</div>
      </div>
      <div style={{ display: "none" }}>{D + pop(f, 0)}</div>
    </AbsoluteFill>
  );
};
