import React from "react";
import { useCurrentFrame } from "remotion";
import { C, FONT, fade, fadeOut } from "../theme";
import { timeline } from "../script";

const all = timeline.flatMap((s) => s.lines);

export const Subtitle: React.FC = () => {
  const f = useCurrentFrame();
  const line = all.find((l) => f >= l.startFrame && f < l.endFrame);
  if (!line) return null;
  const local = f - line.startFrame;
  const o = Math.min(fade(local, 0, 8), fadeOut(local, line.endFrame - line.startFrame, 6));
  return (
    <div style={{ position: "absolute", left: 0, right: 0, bottom: 52, display: "flex", justifyContent: "center", fontFamily: FONT, opacity: o }}>
      <div
        style={{
          maxWidth: 1500,
          textAlign: "center",
          padding: "16px 36px",
          borderRadius: 22,
          background: "rgba(8,11,30,0.78)",
          color: C.ink,
          fontSize: 44,
          fontWeight: 600,
          lineHeight: 1.25,
          letterSpacing: -0.3,
        }}
      >
        {line.text}
      </div>
    </div>
  );
};
