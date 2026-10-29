import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { Background, Heading } from "../components/Common";
import { Phone } from "../components/Phone";
import { ActionsScreen, LobbyScreen, MeetingScreen, ResultScreen, RoleScreen, TasksScreen } from "../components/Screens";
import { C, FONT, fade, fadeOut, kf } from "../theme";

const captions = [
  "Lobby",
  "Role reveal",
  "Task list and notices",
  "Werewolf actions",
  "Meeting and vote",
  "Results",
];

const Layer: React.FC<{ f: number; from: number; to: number; children: React.ReactNode }> = ({ f, from, to, children }) => {
  const o = Math.min(fade(f, from, 10), fadeOut(f, to + 10, 10));
  if (o <= 0.001) return null;
  return (
    <div style={{ position: "absolute", inset: 0, opacity: o, transform: `translateY(${(1 - fade(f, from, 14)) * 24}px)` }}>{children}</div>
  );
};

export const AppScene: React.FC<{ L: number[]; D: number }> = ({ L, D }) => {
  const f = useCurrentFrame();
  const ends = [...L.slice(1), D];
  const idx = L.findIndex((s, i) => f >= s && f < ends[i]);
  const cap = captions[Math.max(0, idx)];
  const dots = Math.floor(f / 12) % 4;
  const cd = Math.max(0, 60 - Math.floor((f - L[3]) / 3));
  const killReady = f - L[3] > 90;
  const mSecs = (() => {
    const s = Math.max(0, 120 - Math.floor((f - L[4]) / 1.4));
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
  })();
  const picked = f > L[4] + 90 ? 1 : -1;
  const tasksDone = f < L[2] + 20 ? 1 : f < L[2] + 70 ? 2 : 3;
  return (
    <AbsoluteFill>
      <Background />
      <Heading kicker="The app" />
      <div style={{ position: "absolute", left: 960 - 190, top: 60 + 20 }}>
        <Phone style={{ position: "relative" }} scale={1}>
          <Layer f={f} from={0} to={L[1]}>
            <LobbyScreen dots={dots} />
          </Layer>
          <Layer f={f} from={L[1]} to={L[2]}>
            <RoleScreen role="werewolf" reveal={kf(f, [[L[1] + 40, 0], [L[1] + 46, 1]])} />
          </Layer>
          <Layer f={f} from={L[2]} to={L[3]}>
            <TasksScreen done={tasksDone} notice={fade(f, L[2] + 80, 12)} />
          </Layer>
          <Layer f={f} from={L[3]} to={L[4]}>
            <ActionsScreen cooldown={cd} killReady={killReady} />
          </Layer>
          <Layer f={f} from={L[4]} to={L[5]}>
            <MeetingScreen secs={mSecs} picked={picked} />
          </Layer>
          <Layer f={f} from={L[5]} to={D + 1}>
            <ResultScreen show={fade(f, L[5] + 10, 16)} />
          </Layer>
        </Phone>
      </div>
      <div style={{ position: "absolute", left: 90, right: 90, top: 420, display: "flex", justifyContent: "space-between", pointerEvents: "none" }}>
        <div style={{ width: 360, fontFamily: FONT, color: C.moon, fontSize: 40, fontWeight: 800, opacity: fade(f, 0, 12) }}>{cap}</div>
      </div>
      <div style={{ position: "absolute", right: 120, top: 420, width: 380, fontFamily: FONT, color: C.dim, fontSize: 28, fontWeight: 600, lineHeight: 1.4, opacity: idx === 3 ? fade(f, L[3] + 10) : 0 }}>
        Kill needs a villager close by and a finished cooldown.
      </div>
    </AbsoluteFill>
  );
};
