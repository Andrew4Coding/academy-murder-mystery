import voiceover from "./voiceover.json";

export const FPS = 30;
export const WIDTH = 1920;
export const HEIGHT = 1080;

export type Line = { text: string; dur: number };
export type SceneDef = { id: string; title: string; lines: Line[] };

export const scenes: SceneDef[] = [
  {
    id: "intro",
    title: "Concept",
    lines: [
      { text: "Welcome to Moonfall.", dur: 3 },
      { text: "Every team is a family in the village.", dur: 4 },
      { text: "But a few of them are werewolves in disguise.", dur: 4.5 },
      { text: "Find them before they find you.", dur: 3.5 },
    ],
  },
  {
    id: "roles",
    title: "Roles",
    lines: [
      { text: "You play in a team of six, and you always move together.", dur: 5 },
      { text: "Your role is revealed in the app.", dur: 4 },
      { text: "Villagers finish every task and vote out the werewolves.", dur: 6 },
      { text: "Werewolves quietly eliminate villagers, sabotage the game, and avoid the vote.", dur: 7 },
    ],
  },
  {
    id: "map",
    title: "The map",
    lines: [
      { text: "Everything happens in one space.", dur: 3.5 },
      { text: "Town Hall is where we meet. Seven booths host the tasks.", dur: 6 },
      { text: "Two stations handle sabotage.", dur: 3.5 },
    ],
  },
  {
    id: "round",
    title: "A round",
    lines: [
      { text: "Each team has five tasks. Visit a booth, finish the challenge, and collect a stamp from the OC.", dur: 7 },
      { text: "Any order you like. Werewolves can pretend to do tasks too.", dur: 5 },
      { text: "A werewolf eliminates a villager from the app when they are close, then waits sixty seconds to strike again.", dur: 7.5 },
      { text: "An eliminated team sits down right where they are.", dur: 4 },
      { text: "Whoever finds them shouts “Dead body!” and the OC rings the bell.", dur: 5.5 },
      { text: "Everyone gathers at Town Hall. Discuss for two minutes, then vote anonymously for two more.", dur: 7.5 },
      { text: "The most-voted team is expelled, and their role is revealed.", dur: 5 },
    ],
  },
  {
    id: "app",
    title: "The app",
    lines: [
      { text: "Wait for the OC to start the game.", dur: 3.5 },
      { text: "Tap to reveal your role. Werewolves also see their allies.", dur: 5 },
      { text: "Follow your task list and watch for notices.", dur: 4.5 },
      { text: "Werewolves get two extra buttons: Kill and Sabotage.", dur: 5 },
      { text: "In a meeting, discuss, then vote for a team or skip.", dur: 5 },
      { text: "Results and updates appear right in the app.", dur: 4.5 },
    ],
  },
  {
    id: "sabotage",
    title: "Sabotage",
    lines: [
      { text: "A werewolf picks a sabotage. The OC is alerted and puts it on the big screen.", dur: 6 },
      { text: "Villagers have ninety seconds to fix it at the Reactor or the Oxygen station.", dur: 6 },
      { text: "If the clock runs out, the werewolves win.", dur: 3.5 },
      { text: "After a sabotage, werewolves must wait two minutes for the next one.", dur: 4.5 },
    ],
  },
  {
    id: "win",
    title: "Winning",
    lines: [
      { text: "Villagers win when every team finishes its tasks, or every werewolf is out.", dur: 6 },
      { text: "Werewolves win when villagers are outnumbered or tied.", dur: 5 },
      { text: "The game lasts forty-five minutes. Then everyone returns to Town Hall for a final vote.", dur: 6.5 },
      { text: "As many teams are expelled as there are werewolves left. Miss one, and the werewolves win.", dur: 6.5 },
      { text: "Good luck, and trust no one.", dur: 3.5 },
    ],
  },
];

export type SceneTiming = {
  id: string;
  title: string;
  startFrame: number;
  durationInFrames: number;
  lineStarts: number[];
  lines: (Line & { startFrame: number; endFrame: number; vo?: string })[];
};

export const VO_DELAY_FRAMES = 5;
const VO_TAIL_SECONDS = 0.5;

let cursor = 0;
let lineIndex = 0;
export const timeline: SceneTiming[] = scenes.map((s) => {
  const startFrame = cursor;
  let local = 0;
  const lines = s.lines.map((l) => {
    const vo = voiceover[lineIndex++] as { file: string; seconds: number } | undefined;
    const dur = vo ? Math.max(l.dur, vo.seconds + VO_TAIL_SECONDS) : l.dur;
    const startF = local;
    local += Math.round(dur * FPS);
    return { ...l, dur, vo: vo?.file, startFrame: cursor + startF, endFrame: cursor + local, local: startF };
  });
  cursor += local;
  return {
    id: s.id,
    title: s.title,
    startFrame,
    durationInFrames: local,
    lineStarts: lines.map((l) => l.local),
    lines,
  };
});

export const TOTAL_FRAMES = cursor;
