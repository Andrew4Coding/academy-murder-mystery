import React from "react";
import { C, FONT } from "../theme";

export const PHONE_W = 380;
export const PHONE_H = 780;

export const Phone: React.FC<{ children: React.ReactNode; scale?: number; style?: React.CSSProperties }> = ({
  children,
  scale = 1,
  style,
}) => (
  <div
    style={{
      position: "absolute",
      width: PHONE_W,
      height: PHONE_H,
      borderRadius: 56,
      background: "#05070F",
      padding: 12,
      boxShadow: "0 40px 90px rgba(0,0,0,0.55), inset 0 0 0 2px #2A3158",
      transform: `scale(${scale})`,
      transformOrigin: "center",
      fontFamily: FONT,
      ...style,
    }}
  >
    <div style={{ position: "relative", width: "100%", height: "100%", borderRadius: 44, overflow: "hidden", background: C.bg }}>
      <div style={{ position: "absolute", top: 12, left: "50%", marginLeft: -52, width: 104, height: 30, borderRadius: 20, background: "#000", zIndex: 5 }} />
      {children}
    </div>
  </div>
);

export const Screen: React.FC<{ children: React.ReactNode; opacity?: number; shift?: number }> = ({
  children,
  opacity = 1,
  shift = 0,
}) => (
  <div style={{ position: "absolute", inset: 0, padding: "64px 22px 22px", opacity, transform: `translateY(${shift}px)` }}>{children}</div>
);

export const Title: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ color: C.ink, fontSize: 32, fontWeight: 800, letterSpacing: -0.5, marginBottom: 14 }}>{children}</div>
);

export const Row: React.FC<{ children: React.ReactNode; color?: string; style?: React.CSSProperties }> = ({
  children,
  color = C.panel,
  style,
}) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      gap: 12,
      padding: "14px 16px",
      borderRadius: 16,
      background: color,
      color: C.ink,
      fontSize: 21,
      fontWeight: 600,
      marginBottom: 10,
      ...style,
    }}
  >
    {children}
  </div>
);

export const BigButton: React.FC<{ children: React.ReactNode; color: string; dim?: boolean; style?: React.CSSProperties }> = ({
  children,
  color,
  dim,
  style,
}) => (
  <div
    style={{
      padding: "18px 0",
      borderRadius: 20,
      background: color,
      color: "#fff",
      textAlign: "center",
      fontSize: 24,
      fontWeight: 700,
      opacity: dim ? 0.45 : 1,
      marginBottom: 12,
      ...style,
    }}
  >
    {children}
  </div>
);

export const TabBar: React.FC<{ active: number }> = ({ active }) => {
  const tabs = ["Family", "Meeting", "Actions"];
  return (
    <div style={{ position: "absolute", left: 14, right: 14, bottom: 14, height: 62, borderRadius: 32, background: C.panel, display: "flex", alignItems: "center", justifyContent: "space-around", color: C.dim, fontSize: 16, fontWeight: 600 }}>
      {tabs.map((t, i) => (
        <div key={t} style={{ padding: "8px 14px", borderRadius: 22, background: i === active ? C.panel2 : "transparent", color: i === active ? C.ink : C.dim }}>
          {t}
        </div>
      ))}
    </div>
  );
};
