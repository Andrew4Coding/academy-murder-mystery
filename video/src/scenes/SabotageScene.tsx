import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { Background, Chip, Heading, Token } from "../components/Common";
import { Phone } from "../components/Phone";
import { SabotagePickScreen } from "../components/Screens";
import { C, FONT, fade, kf, pop } from "../theme";

const fmt = (s: number) => `${Math.floor(s / 60)}:${String(Math.max(0, Math.floor(s) % 60)).padStart(2, "0")}`;

export const SabotageScene: React.FC<{ L: number[]; D: number }> = ({ L, D }) => {
  const f = useCurrentFrame();
  const picked = f > L[0] + 40 ? 0 : -1;
  const confirmed = f > L[0] + 110 ? 1 : 0;
  const tvIn = fade(f, L[0] + 130, 16);
  const resolved = f >= L[1] + 150 && f < L[2];
  const failing = f >= L[2];
  const secs = failing
    ? kf(f, [[L[2], 40], [L[2] + 70, 0]])
    : resolved
      ? 14
      : kf(f, [[L[1], 90], [L[1] + 148, 14]]);
  const alert = resolved ? C.ok : C.werewolf;
  const blink = failing && secs <= 0 ? 0.6 + 0.4 * Math.sin(f / 3) : 1;
  const fix = kf(f, [[L[1] + 40, 0], [L[1] + 148, 1]]);
  const cdBar = kf(f, [[L[3] + 10, 1], [L[3] + 150, 0.2]]);
  return (
    <AbsoluteFill>
      <Background />
      <Heading kicker="Sabotage" />
      <div style={{ position: "absolute", left: 130, top: 100 }}>
        <Phone scale={0.95} style={{ position: "relative", transformOrigin: "top left" }}>
          <SabotagePickScreen picked={picked} confirmed={confirmed} />
        </Phone>
      </div>
      <div style={{ position: "absolute", left: 620, top: 150, width: 1160, height: 560, borderRadius: 34, background: "#05070F", boxShadow: `0 0 0 6px ${C.panel2}, 0 40px 90px rgba(0,0,0,0.5)`, opacity: tvIn, transform: `scale(${0.96 + 0.04 * tvIn})`, overflow: "hidden", fontFamily: FONT }}>
        <div style={{ position: "absolute", inset: 0, background: failing && secs <= 0 ? "rgba(255,69,58,0.25)" : "transparent" }} />
        <div style={{ position: "absolute", left: 36, top: 26, color: C.dim, fontSize: 24, fontWeight: 700, letterSpacing: 4 }}>OC · AIRPLAY DISPLAY</div>
        <div style={{ position: "absolute", left: 0, right: 0, top: 110, textAlign: "center", color: alert, fontSize: 70, fontWeight: 800, opacity: blink }}>
          {resolved ? "Sabotage resolved" : "Sabotage: Reactor"}
        </div>
        <div style={{ position: "absolute", left: 0, right: 0, top: 210, textAlign: "center", color: C.ink, fontSize: 190, fontWeight: 800, letterSpacing: -6, fontVariantNumeric: "tabular-nums" }}>
          {fmt(secs)}
        </div>
        {failing && secs <= 0 && (
          <div style={{ position: "absolute", left: 0, right: 0, top: 450, textAlign: "center", color: C.werewolf, fontSize: 48, fontWeight: 800 }}>Werewolves win</div>
        )}
        {!failing && (
          <div style={{ position: "absolute", left: 60, right: 60, top: 460 }}>
            <div style={{ color: C.dim, fontSize: 26, fontWeight: 600, marginBottom: 12 }}>Reactor station</div>
            <div style={{ height: 22, borderRadius: 11, background: C.panel }}>
              <div style={{ width: `${fix * 100}%`, height: "100%", borderRadius: 11, background: C.ok }} />
            </div>
          </div>
        )}
      </div>
      {f >= L[1] && !failing && (
        <>
          <Token x={1000} y={800} size={74 * pop(f, L[1])} color={C.villager} opacity={pop(f, L[1])} />
          <Token x={1100} y={800} size={74 * pop(f, L[1] + 6)} color={C.villager} opacity={pop(f, L[1] + 6)} />
          <div style={{ position: "absolute", left: 1170, top: 776, opacity: fade(f, L[1] + 20) }}>
            <Chip>Laser Maze / Pose Challenge</Chip>
          </div>
        </>
      )}
      {f >= L[3] && (
        <div style={{ position: "absolute", left: 620, top: 780, width: 1160, opacity: fade(f, L[3]), fontFamily: FONT }}>
          <div style={{ color: C.ink, fontSize: 34, fontWeight: 700, marginBottom: 14 }}>Next sabotage in {fmt(120 * cdBar)}</div>
          <div style={{ height: 24, borderRadius: 12, background: C.panel }}>
            <div style={{ width: `${cdBar * 100}%`, height: "100%", borderRadius: 12, background: C.warn }} />
          </div>
        </div>
      )}
      <div style={{ display: "none" }}>{D}</div>
    </AbsoluteFill>
  );
};
