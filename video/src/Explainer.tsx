import React from "react";
import { AbsoluteFill, Audio, Sequence, interpolate, staticFile } from "remotion";
import { Subtitle } from "./components/Subtitle";
import { AppScene } from "./scenes/AppScene";
import { Intro } from "./scenes/Intro";
import { MapScene } from "./scenes/MapScene";
import { Roles } from "./scenes/Roles";
import { Round } from "./scenes/Round";
import { SabotageScene } from "./scenes/SabotageScene";
import { WinScene } from "./scenes/WinScene";
import { TOTAL_FRAMES, timeline } from "./script";
import { VOICEOVER_FILE } from "./config";

const at = (id: string, line: number, offset = 0) => {
  const s = timeline.find((t) => t.id === id)!;
  return s.startFrame + s.lineStarts[line] + offset;
};

const sfx: { file: string; from: number; volume: number }[] = [
  { file: "chime.wav", from: 4, volume: 0.5 },
  { file: "whoosh.wav", from: at("roles", 2, -6), volume: 0.35 },
  { file: "stamp.wav", from: at("round", 0, 100), volume: 0.7 },
  { file: "stamp.wav", from: at("round", 1, 100), volume: 0.7 },
  { file: "kill.wav", from: at("round", 3, 10), volume: 0.7 },
  { file: "bell.wav", from: at("round", 4, 70), volume: 0.6 },
  { file: "alert.wav", from: at("sabotage", 0, 130), volume: 0.5 },
  { file: "stamp.wav", from: at("sabotage", 1, 150), volume: 0.7 },
  { file: "alert.wav", from: at("sabotage", 2, 70), volume: 0.5 },
  { file: "chime.wav", from: at("win", 3, 80), volume: 0.5 },
  { file: "bell.wav", from: at("win", 2, 4), volume: 0.5 },
];

const scenes: Record<string, React.FC<{ L: number[]; D: number }>> = {
  intro: Intro,
  roles: Roles,
  map: MapScene,
  round: Round,
  app: AppScene,
  sabotage: SabotageScene,
  win: WinScene,
};

export const Explainer: React.FC = () => (
  <AbsoluteFill style={{ background: "#0B1026" }}>
    {timeline.map((s) => {
      const Scene = scenes[s.id];
      return (
        <Sequence key={s.id} from={s.startFrame} durationInFrames={s.durationInFrames} name={s.title}>
          <Scene L={s.lineStarts} D={s.durationInFrames} />
        </Sequence>
      );
    })}
    <Audio
      src={staticFile("audio/music.wav")}
      volume={(f) =>
        interpolate(f, [0, 60, TOTAL_FRAMES - 90, TOTAL_FRAMES], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) *
        (VOICEOVER_FILE ? 0.12 : 0.3)
      }
    />
    {VOICEOVER_FILE && <Audio src={staticFile(VOICEOVER_FILE)} />}
    {sfx.map((e, i) => (
      <Sequence key={i} from={e.from}>
        <Audio src={staticFile(`audio/${e.file}`)} volume={e.volume} />
      </Sequence>
    ))}
    <Subtitle />
  </AbsoluteFill>
);
