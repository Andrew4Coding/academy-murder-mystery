import React from "react";
import { AbsoluteFill, random, useCurrentFrame } from "remotion";
import { C, FONT } from "../theme";

export const Background: React.FC<{ moonY?: number }> = ({ moonY = 0 }) => {
  const f = useCurrentFrame();
  const stars = Array.from({ length: 70 }, (_, i) => ({
    x: random(`sx${i}`) * 1920,
    y: random(`sy${i}`) * 700,
    r: 1 + random(`sr${i}`) * 2,
    p: random(`sp${i}`) * 6,
  }));
  return (
    <AbsoluteFill style={{ background: `radial-gradient(1200px 800px at 80% -10%, ${C.bg2}, ${C.bg})`, fontFamily: FONT }}>
      <svg width={1920} height={1080} style={{ position: "absolute" }}>
        {stars.map((s, i) => (
          <circle key={i} cx={s.x} cy={s.y} r={s.r} fill="#fff" opacity={0.25 + 0.35 * Math.abs(Math.sin(f / 40 + s.p))} />
        ))}
        <circle cx={1650} cy={150 + moonY} r={130} fill={C.moon} opacity={0.07} />
        <circle cx={1650} cy={150 + moonY} r={80} fill={C.moon} opacity={0.16} />
      </svg>
    </AbsoluteFill>
  );
};

export const Moon: React.FC<{ size?: number }> = ({ size = 120 }) => (
  <svg width={size} height={size} viewBox="0 0 100 100">
    <defs>
      <mask id="cres">
        <rect width="100" height="100" fill="#fff" />
        <circle cx="68" cy="38" r="38" fill="#000" />
      </mask>
    </defs>
    <circle cx="50" cy="50" r="40" fill={C.moon} mask="url(#cres)" />
  </svg>
);

export const Token: React.FC<{
  x: number;
  y: number;
  color?: string;
  size?: number;
  dead?: boolean;
  label?: string;
  opacity?: number;
  ring?: string;
}> = ({ x, y, color = C.villager, size = 56, dead = false, label, opacity = 1, ring }) => {
  const c = dead ? "#5B628C" : color;
  return (
    <div style={{ position: "absolute", left: x - size / 2, top: y - size / 2, width: size, height: size, opacity }}>
      {ring && (
        <div style={{ position: "absolute", inset: -10, borderRadius: "50%", border: `3px solid ${ring}`, opacity: 0.9 }} />
      )}
      <svg width={size} height={size} viewBox="0 0 56 56">
        <circle cx="28" cy="28" r="27" fill={c} />
        {dead ? (
          <path d="M18 18l20 20M38 18L18 38" stroke="#fff" strokeWidth="5" strokeLinecap="round" />
        ) : (
          <>
            <circle cx="28" cy="21" r="8" fill="#fff" opacity={0.92} />
            <path d="M11 46c2-10 9-14 17-14s15 4 17 14c-5 5-11 7-17 7s-12-2-17-7z" fill="#fff" opacity={0.92} />
          </>
        )}
      </svg>
      {label && (
        <div style={{ position: "absolute", top: size + 6, left: -40, width: size + 80, textAlign: "center", fontFamily: FONT, color: C.ink, fontSize: 22, fontWeight: 600 }}>
          {label}
        </div>
      )}
    </div>
  );
};

export const Chip: React.FC<{ children: React.ReactNode; color?: string; style?: React.CSSProperties }> = ({
  children,
  color = C.panel2,
  style,
}) => (
  <div
    style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 10,
      padding: "10px 22px",
      borderRadius: 999,
      background: color,
      color: C.ink,
      fontFamily: FONT,
      fontSize: 28,
      fontWeight: 600,
      ...style,
    }}
  >
    {children}
  </div>
);

export const Heading: React.FC<{ kicker: string; opacity?: number }> = ({ kicker, opacity = 1 }) => (
  <div style={{ position: "absolute", left: 90, top: 60, fontFamily: FONT, color: C.moon, fontSize: 30, fontWeight: 700, letterSpacing: 6, textTransform: "uppercase", opacity }}>
    {kicker}
  </div>
);

export const Check: React.FC<{ size?: number; color?: string }> = ({ size = 28, color = C.ok }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <circle cx="12" cy="12" r="11" fill={color} />
    <path d="M7 12.5l3.2 3.2L17 8.8" fill="none" stroke="#fff" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
