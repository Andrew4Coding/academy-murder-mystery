import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Background, Chip, Heading, Token } from "../components/Common";
import { MapBoard, POS, Spot } from "../components/MapBoard";
import { C, FONT, clamp, ease, fade, kf, pop } from "../theme";

type Pt = [number, number, number];

const at = (f: number, pts: Pt[]) => {
  const fr = pts.map((p) => p[0]);
  const opt = { ...clamp, easing: ease };
  return {
    x: interpolate(f, fr, pts.map((p) => p[1]), opt),
    y: interpolate(f, fr, pts.map((p) => p[2]), opt),
  };
};

const P = (s: Spot, dx = 0, dy = 40): [number, number] => [POS[s].x + dx, POS[s].y + dy];

const Bell: React.FC<{ x: number; y: number; ring: number }> = ({ x, y, ring }) => (
  <svg style={{ position: "absolute", left: x - 40, top: y - 40, opacity: ring > 0 ? 1 : 0, transform: `rotate(${Math.sin(ring * 40) * 16 * (1 - ring)}deg)` }} width="80" height="80" viewBox="0 0 24 24">
    <path d="M12 3a6 6 0 0 0-6 6v4l-2 3h16l-2-3V9a6 6 0 0 0-6-6zm-2 15a2 2 0 0 0 4 0z" fill={C.moon} />
  </svg>
);

const Bubble: React.FC<{ x: number; y: number; o: number; children: React.ReactNode; color?: string }> = ({ x, y, o, children, color = C.moon }) => (
  <div style={{ position: "absolute", left: x - 110, top: y - 110, width: 220, textAlign: "center", padding: "12px 0", borderRadius: 22, background: color, color: "#14183A", fontFamily: FONT, fontSize: 30, fontWeight: 800, opacity: o, transform: `scale(${0.8 + 0.2 * o})` }}>
    {children}
  </div>
);

export const Round: React.FC<{ L: number[] }> = ({ L }) => {
  const f = useCurrentFrame();
  const [b3x, b3y] = P("b3");
  const [b1x, b1y] = P("b1");
  const [b2x, b2y] = P("b2");
  const [b4x, b4y] = P("b4");
  const [hx, hy] = [POS.townhall.x, POS.townhall.y];

  const v1 = at(f, [
    [0, hx - 90, hy + 110],
    [L[0] + 90, b3x, b3y],
    [L[1], b3x, b3y],
    [L[1] + 80, b1x, b1y],
    [L[4] - 10, b1x, b1y],
    [L[5] + 60, hx - 90, hy + 110],
  ]);
  const wolf = at(f, [
    [0, hx + 80, hy + 110],
    [L[1] + 20, b2x + 40, b2y + 20],
    [L[2] + 10, b2x + 40, b2y + 20],
    [L[2] + 110, b4x - 70, b4y - 20],
    [L[3] + 80, b4x - 140, b4y + 80],
    [L[4] + 40, b4x - 140, b4y + 80],
    [L[5] + 80, hx + 90, hy + 110],
  ]);
  const v2 = at(f, [
    [0, hx, hy + 120],
    [L[0] + 120, b4x, b4y],
    [L[5] + 80, b4x, b4y],
  ]);
  const v3 = at(f, [
    [0, hx - 60, hy - 110],
    [L[3] + 40, hx - 60, hy - 110],
    [L[4] + 20, b4x - 120, b4y - 120],
    [L[4] + 80, b4x - 120, b4y - 120],
    [L[5] + 70, hx - 20, hy - 110],
  ]);

  const dead = f >= L[3] + 10;
  const v2Pos = dead ? { x: b4x, y: b4y + 6 } : v2;
  const killProx = fade(f, L[2] + 70, 10) * (1 - fade(f, L[3] + 10, 8));
  const stamps = f < L[0] + 100 ? 0 : f < L[1] + 100 ? 1 : 2;
  const fakeStamp = fade(f, L[1] + 40, 10) * (1 - fade(f, L[2] - 10, 10));
  const bell = f >= L[4] + 70 ? Math.min(1, (f - (L[4] + 70)) / 40) : 0;
  const shout = fade(f, L[4] + 30, 8) * (1 - fade(f, L[4] + 90, 10));
  const phase = f < L[5] ? "Tasks & kills" : f < L[6] ? "Town Hall: discuss 2:00, vote 2:00" : "Vote result";
  const voteIn = kf(f, [[L[6] + 10, 0], [L[6] + 60, 1]]);
  const expelled = fade(f, L[6] + 70, 10);

  const map: Partial<Record<Spot, number>> = {};
  const pulse: Partial<Record<Spot, number>> = {};
  if (f >= L[4] + 70 && f < L[5] + 40) pulse.townhall = 0.5 + 0.5 * Math.sin(f / 4);

  const voters: [number, number][] = [
    [hx - 90, hy + 110],
    [hx - 20, hy - 110],
    [hx + 90, hy + 110],
  ];
  const wolfTarget = { x: hx + 90, y: hy + 110 };

  return (
    <AbsoluteFill>
      <Background />
      <Heading kicker="A round" />
      <div style={{ position: "absolute", left: 640, top: 52, display: "flex", gap: 14 }}>
        <Chip color={C.panel2}>{phase}</Chip>
      </div>
      <div style={{ position: "absolute", right: 90, top: 52, display: "flex", gap: 14, opacity: f < L[5] ? 1 : 0 }}>
        <Chip>Stamps {stamps}/5</Chip>
      </div>
      <div style={{ position: "absolute", left: 110, top: -50, transform: "scale(1.1)", transformOrigin: "top left" }}>
        <MapBoard reveal={map} pulse={pulse}>
          <Bell x={hx + 130} y={hy - 110} ring={bell} />
          {killProx > 0 && (
            <div style={{ position: "absolute", left: (wolf.x + v2.x) / 2 - 120, top: (wolf.y + v2.y) / 2 - 120, width: 240, height: 240, borderRadius: "50%", border: `4px dashed ${C.werewolf}`, opacity: killProx, transform: `scale(${0.9 + 0.1 * Math.sin(f / 3)})` }} />
          )}
          <Token x={v1.x} y={v1.y} size={68} color={C.villager} label="" />
          <Token x={v3.x} y={v3.y} size={68} color={C.villager} />
          <Token x={v2Pos.x} y={v2Pos.y} size={dead ? 60 : 68} color={C.villager} dead={dead} />
          <Token
            x={f >= L[6] + 60 ? wolfTarget.x : wolf.x}
            y={f >= L[6] + 60 ? wolfTarget.y : wolf.y}
            size={68}
            color={f >= L[6] + 70 ? C.werewolf : "#C46A9A"}
            ring={expelled > 0.5 ? C.moon : undefined}
          />
          {stamps > 0 && f < L[5] && (
            <div style={{ position: "absolute", left: b3x - 40, top: b3y - 120, opacity: f < L[1] + 60 ? pop(f, L[0] + 100) : 0, fontFamily: FONT, fontSize: 26, fontWeight: 800, color: "#14183A", background: C.ok, borderRadius: 16, padding: "8px 16px" }}>
              Stamp
            </div>
          )}
          {fakeStamp > 0 && (
            <Bubble x={b2x + 60} y={b2y + 40} o={fakeStamp} color={C.panel2}>
              <span style={{ color: C.ink, fontSize: 24 }}>Pretending…</span>
            </Bubble>
          )}
          {killProx > 0.5 && (
            <div style={{ position: "absolute", left: wolf.x - 20, top: wolf.y - 80, fontFamily: FONT, fontSize: 28, fontWeight: 800, color: "#fff", background: C.werewolf, borderRadius: 16, padding: "8px 20px", opacity: killProx }}>
              Kill · 60s
            </div>
          )}
          {dead && f < L[5] && (
            <div style={{ position: "absolute", left: b4x - 110, top: b4y + 40, width: 220, textAlign: "center", fontFamily: FONT, color: C.dim, fontSize: 24, fontWeight: 700, opacity: fade(f, L[3] + 14) }}>
              Eliminated
            </div>
          )}
          <Bubble x={b4x - 120} y={b4y - 100} o={shout}>
            Dead body!
          </Bubble>
          {f >= L[6] + 10 &&
            [voters[0], voters[1]].map(([vx, vy], i) => {
              const px = vx + (wolfTarget.x - vx) * voteIn;
              const py = vy + (wolfTarget.y - vy) * voteIn - Math.sin(voteIn * Math.PI) * 60;
              return <div key={i} style={{ position: "absolute", left: px - 11, top: py - 11 - 50, width: 22, height: 22, borderRadius: 11, background: C.moon, opacity: 1 - fade(f, L[6] + 60, 6) }} />;
            })}
          {expelled > 0 && (
            <Bubble x={wolfTarget.x} y={wolfTarget.y + 190} o={expelled} color={C.werewolf}>
              <span style={{ color: "#fff", fontSize: 28 }}>Werewolf!</span>
            </Bubble>
          )}
        </MapBoard>
      </div>
    </AbsoluteFill>
  );
};
