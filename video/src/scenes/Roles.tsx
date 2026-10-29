import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { Background, Check, Heading, Token } from "../components/Common";
import { Phone, PHONE_H, PHONE_W } from "../components/Phone";
import { RoleScreen } from "../components/Screens";
import { C, FONT, fade, kf, pop } from "../theme";

const ring = [
  [0, -90], [78, -45], [78, 45], [0, 90], [-78, 45], [-78, -45],
];

const RoleCard: React.FC<{ role: "villager" | "werewolf"; goals: string[]; o: number; dim: number; x: number }> = ({ role, goals, o, dim, x }) => {
  const col = role === "villager" ? C.villager : C.werewolf;
  return (
    <div style={{ position: "absolute", left: x, top: 210, width: 640, padding: 44, borderRadius: 40, background: C.panel, boxShadow: `inset 0 0 0 4px ${col}`, opacity: o * dim, transform: `scale(${0.94 + 0.06 * dim})`, fontFamily: FONT }}>
      <div style={{ display: "flex", alignItems: "center", gap: 28 }}>
        <div style={{ position: "relative", width: 88, height: 88 }}>
          <Token x={44} y={44} size={88} color={col} />
        </div>
        <div style={{ fontSize: 64, fontWeight: 800, color: C.ink }}>{role === "villager" ? "Villager" : "Werewolf"}</div>
      </div>
      <div style={{ marginTop: 40 }}>
        {goals.map((g) => (
          <div key={g} style={{ display: "flex", alignItems: "center", gap: 18, fontSize: 36, fontWeight: 600, color: C.ink, marginBottom: 26 }}>
            <Check size={38} color={col} />
            {g}
          </div>
        ))}
      </div>
    </div>
  );
};

export const Roles: React.FC<{ L: number[] }> = ({ L }) => {
  const f = useCurrentFrame();
  const teamX = kf(f, [[L[1] - 6, 960], [L[1] + 24, 520]]);
  const phoneO = Math.min(fade(f, L[1], 16), 1 - fade(f, L[2] - 6, 12));
  const reveal = kf(f, [[L[1] + 70, 0], [L[1] + 76, 1]]);
  const stage1 = 1 - fade(f, L[2] - 6, 12);
  const cards = fade(f, L[2], 16);
  const vDim = f < L[3] ? 1 : 0.35;
  const wDim = f < L[3] ? 0.35 : 1;
  return (
    <AbsoluteFill>
      <Background />
      <Heading kicker="Roles" />
      <div style={{ opacity: stage1 }}>
        <div style={{ position: "absolute", left: teamX - 140, top: 380, width: 280, height: 280, borderRadius: "50%", background: "rgba(10,132,255,0.10)", boxShadow: `inset 0 0 0 3px ${C.villager}`, opacity: fade(f, 0, 14) }} />
        {ring.map(([dx, dy], i) => (
          <Token key={i} x={teamX + dx} y={520 + dy} size={68 * pop(f, 6 + i * 4)} opacity={pop(f, 6 + i * 4)} />
        ))}
        <div style={{ position: "absolute", left: teamX - 160, top: 700, width: 320, textAlign: "center", fontFamily: FONT, color: C.ink, fontSize: 34, fontWeight: 700, opacity: fade(f, 40) }}>Your team of 6</div>
      </div>
      <div style={{ position: "absolute", left: 1300 - PHONE_W / 2, top: 120, opacity: phoneO, transform: `translateY(${kf(f, [[L[1], 60], [L[1] + 24, 0]])}px)` }}>
        <Phone scale={0.85} style={{ position: "relative" }}>
          <RoleScreen role="villager" reveal={reveal} />
        </Phone>
      </div>
      <RoleCard role="villager" x={190} o={cards} dim={vDim} goals={["Finish every task", "Vote out the werewolves"]} />
      <RoleCard role="werewolf" x={1090} o={cards} dim={wDim} goals={["Eliminate villagers", "Sabotage the game", "Avoid the vote"]} />
      <div style={{ display: "none" }}>{PHONE_H}</div>
    </AbsoluteFill>
  );
};
