import {
  array, bool, data, flatMap, int, num, optional, rawEnum, set, str, struct, union, uuid,
  type Codec, type Infer
} from "./combinators.js";
import { createHash } from "node:crypto";
import { GameEngine } from "../engine/engine.js";

function refine<A, B>(inner: Codec<A>, to: (a: A) => B, from: (b: B) => A): Codec<B> {
  return { dec: (j, p) => to(inner.dec(j, p)), enc: (v) => inner.enc(from(v)) };
}

const familyStruct = struct({ rawValue: int });
export const familyId: Codec<number> = refine(familyStruct, (s) => s.rawValue, (n) => ({ rawValue: n }));

export const role = rawEnum(["villager", "werewolf"] as const);
export const side = rawEnum(["villagers", "werewolves"] as const);
export const lifeState = rawEnum(["alive", "killed", "expelled"] as const);
export const sabotageKind = rawEnum(["reactor", "oxygen"] as const);
export const timerTarget = rawEnum(["meeting", "finalVote", "sabotage"] as const);

export const voteChoice = union({ family: { _0: familyId }, skip: {} });

export const gameSettings = struct({
  discussionDuration: num,
  votingDuration: num,
  killCooldown: num,
  sabotageCooldown: num,
  sabotageDuration: num,
  gameDuration: num,
  oxygenDuration: optional(num),
  oxygenCooldown: optional(num),
  debugMode: optional(bool)
});

export const family = struct({ id: familyId, role, life: lifeState, killReadyAt: num });

export const activeSabotage = struct({ kind: sabotageKind, startedAt: num, endsAt: num, triggeredBy: familyId });

export const outcome = struct({
  winner: side,
  reason: rawEnum([
    "allWerewolvesRemoved", "parity", "sabotageExpired", "finalVoteSucceeded", "finalVoteFailed", "ocEnded"
  ] as const)
});

export const phase = union({
  running: {},
  discussion: { until: num },
  voting: { until: num, isFinal: bool },
  ended: { _0: outcome }
});

export const voteCount = struct({ choice: voteChoice, count: int });
export const reveal = struct({ family: familyId, role });
export const voteResult = struct({ tally: array(voteCount), expelled: array(reveal), isFinal: bool, at: num });

const gameStateWire = struct({
  settings: gameSettings,
  startedAt: num,
  families: flatMap(familyId, family),
  phase,
  sabotage: optional(activeSabotage),
  sabotageReadyAt: num,
  announcedDeaths: array(familyId),
  lastResult: optional(voteResult),
  deadSinceLastMeeting: array(familyId),
  finalVoteStarted: bool,
  finalVotePending: bool,
  finalVoteOverride: optional(num),
  timerPausedAt: optional(flatMap(timerTarget, num))
});

type GameStateWire = Infer<typeof gameStateWire>;
export type VoteChoice = Infer<typeof voteChoice>;
export type GameState = GameStateWire & { votes: Map<number, VoteChoice>; skipVotes: Set<number> };

export const gameState: Codec<GameState> = refine(
  gameStateWire,
  (s): GameState => ({ ...s, votes: new Map(), skipVotes: new Set() }),
  (s) => s
);

export const gameEngine: Codec<GameEngine> = refine(
  struct({ state: gameState }),
  (e) => new GameEngine(e.state),
  (e) => ({ state: e.state })
);

export const ocOverride = union({
  forceKill: { _0: familyId },
  revive: { _0: familyId },
  endGame: { _0: side },
  proxyVote: { _0: familyId },
  timerAdjusted: { _0: timerTarget, seconds: num },
  timerPaused: { _0: timerTarget },
  timerResumed: { _0: timerTarget }
});

export const gameCommand = union({
  kill: { killer: familyId, victim: familyId },
  requestSabotage: { by: familyId, kind: sabotageKind },
  resolveSabotage: {},
  startMeeting: {},
  reportBody: { by: familyId, body: familyId },
  castVote: { by: familyId, choice: voteChoice },
  proxyVote: { for: familyId, choice: voteChoice },
  extendMeeting: { seconds: num },
  adjustTimer: { _0: timerTarget, seconds: num },
  pauseTimer: { _0: timerTarget },
  resumeTimer: { _0: timerTarget },
  voteSkipDiscussion: { by: familyId },
  approveSkipDiscussion: {},
  override: { _0: ocOverride }
});

export const gameEventKind = union({
  gameStarted: { werewolves: array(familyId) },
  familyKilled: { _0: familyId, by: optional(familyId) },
  sabotageStarted: { kind: sabotageKind, by: familyId, endsAt: num },
  sabotageResolved: {},
  sabotageExpired: {},
  meetingStarted: { deadFamilies: array(familyId) },
  votingOpened: { isFinal: bool },
  voteCast: { by: familyId },
  voteClosed: { tally: array(voteCount), expelled: array(reveal), isFinal: bool },
  ocOverride: { _0: ocOverride },
  gameEnded: { _0: outcome }
});

export const gameEvent = struct({ at: num, kind: gameEventKind });

export const ocStation = union({ sabotage: { _0: sabotageKind }, townHall: {}, admin: {} });

export const player = struct({ id: uuid, name: str, family: familyId, bleToken: str });
export const familyInfo = struct({ id: familyId, name: str, joinCode: str });
export const ocDevice = struct({ id: uuid, station: ocStation });
export const identity = union({ player: { _0: uuid }, oc: { _0: uuid } });
export const credential = union({ familyCode: { _0: str }, ocPin: { _0: str }, resume: { _0: uuid } });

export const hello = struct({
  version: int,
  credential,
  name: optional(str),
  station: optional(ocStation),
  mapHash: optional(str),
  boothsRevision: optional(str)
});

export const sighting = struct({ token: str, rssi: int });

export const hostState = struct({
  settings: gameSettings,
  werewolfCount: int,
  gameCode: optional(str),
  families: flatMap(familyId, familyInfo),
  players: flatMap(uuid, player),
  ocDevices: flatMap(uuid, ocDevice),
  ocPin: str,
  rssiThreshold: int,
  sightingFreshness: num,
  engine: optional(gameEngine),
  simulated: bool
});

export const identityView = union({
  player: { id: uuid, name: str, family: familyId },
  oc: { id: uuid, station: ocStation }
});

export const familySummary = struct({
  id: familyId,
  name: str,
  life: lifeState,
  revealedRole: optional(role),
  playerID: optional(uuid),
  playerName: optional(str)
});

export const lobbyView = struct({ familyName: str, joinCode: str, playerID: uuid, playerName: str });
export const resultRow = struct({ name: str, count: int, isSkip: bool });
export const expelledView = struct({ name: str, role: optional(role) });
export const voteResultView = struct({ rows: array(resultRow), expelled: array(expelledView), isFinal: bool });
export const sabotageView = struct({ kind: sabotageKind, startedAt: num, endsAt: num });

export const adminFamilyRow = struct({
  id: familyId,
  name: str,
  playerName: optional(str),
  life: lifeState,
  role: optional(role),
  voted: bool
});

export const deviceStatus = struct({
  id: uuid,
  label: str,
  detail: str,
  connection: rawEnum(["online", "unreachable", "offline"] as const),
  lastSeen: optional(num),
  isOC: bool
});

export const adminView = struct({
  joinCode: optional(str),
  playersJoined: int,
  isLobby: bool,
  phase,
  gameEndsAt: optional(num),
  families: array(adminFamilyRow),
  sabotage: optional(sabotageView),
  skipVotes: int,
  votersTotal: int,
  skipRequested: bool,
  settings: gameSettings,
  werewolfCount: int,
  rssiThreshold: int,
  sightingFreshness: num,
  ocPin: str,
  setupIssues: array(str),
  lastResult: optional(voteResultView),
  votesCast: int,
  devices: array(deviceStatus),
  timerPausedAt: flatMap(timerTarget, num)
});

export const ocView = struct({ sabotage: optional(sabotageView) });
export const sabotageTiming = struct({ kind: sabotageKind, duration: num });
export const proximitySettings = struct({ rssiThreshold: int, sightingFreshness: num });

export const gameView = struct({
  role,
  family: familyId,
  familyName: str,
  life: lifeState,
  allies: optional(array(familySummary)),
  families: array(familySummary),
  phase,
  announcedDeaths: array(familySummary),
  myVote: optional(voteChoice),
  votesCast: int,
  votersTotal: int,
  lastResult: optional(voteResultView),
  bleToken: str,
  proximity: proximitySettings,
  nearby: array(familySummary),
  killReadyAt: optional(num),
  sabotage: optional(sabotageView),
  sabotageReadyAt: optional(num),
  sabotageTimings: array(sabotageTiming),
  nearbyBodies: array(familySummary),
  bodyActive: bool,
  skipVotes: int,
  mySkipVote: bool,
  skipRequested: bool,
  startsAt: optional(num)
});

export const clientView = struct({
  serverTime: num,
  identity: identityView,
  familyName: optional(str),
  lobby: optional(lobbyView),
  game: optional(gameView),
  oc: optional(ocView),
  admin: optional(adminView)
});

export const welcome = struct({ resumeID: uuid, serverTime: num });
export const selfie = struct({ player: uuid, jpeg: data });
export const selfieList = array(selfie);
export const boothMap = struct({ hash: str, jpeg: data });
export const boothImage: Codec<{ hash: string; jpeg: Buffer }> = refine(
  struct({ hash: str, jpeg: data }),
  (s) => ({ jpeg: s.jpeg, hash: createHash("sha256").update(s.jpeg).digest("hex") }),
  (b) => b
);
export const booth = struct({
  id: uuid,
  title: str,
  location: str,
  capacity: str,
  duration: str,
  task: str,
  steps: array(str),
  stampRequirement: str,
  staffNotes: array(str),
  image: optional(boothImage)
});
export const boothCatalog = struct({ revision: str, booths: array(booth) });

export const publicScreen = union({
  hostOffline: {},
  waiting: {},
  starting: { at: num },
  playing: { gameEndsAt: num },
  discussion: { until: num },
  voting: { until: num, isFinal: bool, cast: int, total: int },
  result: { _0: voteResultView },
  ended: { _0: outcome }
});

export const lobbyFamily = struct({ id: familyId, name: str, player: optional(str), selfie: optional(data) });
export const revealedFamily = struct({
  id: familyId,
  name: str,
  player: optional(str),
  selfie: optional(data),
  isWerewolf: bool
});

export const publicDisplayState = struct({
  screen: publicScreen,
  familiesRemaining: optional(int),
  alarm: optional(struct({ kind: sabotageKind, endsAt: num })),
  announcedDeaths: array(str),
  joinCode: optional(str),
  lobbyFamilies: array(lobbyFamily),
  reveal: array(revealedFamily)
});

export const adminCommand = union({
  ringBell: {},
  startMeeting: {},
  extendMeeting: { seconds: num },
  adjustTimer: { _0: timerTarget, seconds: num },
  pauseTimer: { _0: timerTarget },
  resumeTimer: { _0: timerTarget },
  approveSkipDiscussion: {},
  resolveSabotage: {},
  removeFamily: { _0: familyId },
  removeDevice: { _0: uuid },
  updateSettings: { werewolfCount: int, settings: gameSettings },
  setProximity: { rssiThreshold: int, sightingFreshness: num },
  startGame: {},
  newGame: {},
  renameFamily: { _0: familyId, _1: str },
  regenerateOCPIN: {},
  setBoothMap: { _0: data },
  removeBoothMap: {},
  saveBooth: { _0: booth },
  deleteBooth: { _0: uuid },
  reorderBooths: { _0: array(uuid) },
  setBoothImage: { _0: uuid, _1: data },
  removeBoothImage: { _0: uuid },
  restoreBoothDefaults: {},
  eliminate: { _0: array(familyId) },
  revive: { _0: array(familyId) },
  proxyVote: { family: familyId, choice: voteChoice },
  endGame: { _0: side },
  checkConnectivity: {}
});

export const clientMessage = union({
  hello: { _0: hello },
  probeReply: { _0: uuid },
  renameFamily: { _0: str },
  voteSkipDiscussion: {},
  reportBody: { _0: familyId },
  admin: { _0: adminCommand },
  selfie: { _0: data },
  vote: { _0: voteChoice },
  sightings: { _0: array(sighting) },
  kill: { victim: familyId },
  requestSabotage: { _0: sabotageKind },
  resolveSabotage: {},
  leave: {},
  sync: {}
});

export const serverMessage = union({
  welcome: { _0: welcome },
  state: { _0: clientView },
  rejected: { _0: str },
  probe: { _0: uuid },
  reset: {},
  selfies: { _0: array(selfie) },
  map: { _0: optional(boothMap) },
  booths: { _0: boothCatalog },
  display: { _0: publicDisplayState }
});

export type Phase = Infer<typeof phase>;
export type Family = Infer<typeof family>;
export type Outcome = Infer<typeof outcome>;
export type GameCommand = Infer<typeof gameCommand>;
export type GameEvent = Infer<typeof gameEvent>;
export type GameEventKind = Infer<typeof gameEventKind>;
export type OCOverride = Infer<typeof ocOverride>;
export type GameSettings = Infer<typeof gameSettings>;
export type VoteCount = Infer<typeof voteCount>;
export type Reveal = Infer<typeof reveal>;
export type VoteResult = Infer<typeof voteResult>;
export type Role = Infer<typeof role>;
export type Side = Infer<typeof side>;
export type LifeState = Infer<typeof lifeState>;
export type Booth = Infer<typeof booth>;
export type SabotageKind = Infer<typeof sabotageKind>;
export type TimerTarget = Infer<typeof timerTarget>;
export type OCStation = Infer<typeof ocStation>;
export type HostState = Infer<typeof hostState>;
export type Player = Infer<typeof player>;
export type FamilyInfo = Infer<typeof familyInfo>;
export type Identity = Infer<typeof identity>;
export type Hello = Infer<typeof hello>;
export type ClientMessage = Infer<typeof clientMessage>;
export type ServerMessage = Infer<typeof serverMessage>;
export type AdminCommand = Infer<typeof adminCommand>;
export type ClientView = Infer<typeof clientView>;
export type GameView = Infer<typeof gameView>;
export type AdminView = Infer<typeof adminView>;
export type PhaseView = Phase;
export type VoteResultView = Infer<typeof voteResultView>;
export type FamilySummary = Infer<typeof familySummary>;
export type PublicDisplayState = Infer<typeof publicDisplayState>;
export type SabotageView = Infer<typeof sabotageView>;
export type DeviceStatus = Infer<typeof deviceStatus>;
export type BoothMap = Infer<typeof boothMap>;
export type BoothImage = Infer<typeof boothImage>;
export type BoothCatalog = Infer<typeof boothCatalog>;
export type Selfie = Infer<typeof selfie>;
export type Sighting = Infer<typeof sighting>;
export type ActiveSabotage = Infer<typeof activeSabotage>;

export const WIRE_VERSION = 3;
export const defaultSettings = (): GameSettings => ({
  discussionDuration: 120,
  votingDuration: 120,
  killCooldown: 60,
  sabotageCooldown: 120,
  sabotageDuration: 90,
  gameDuration: 45 * 60,
  oxygenDuration: undefined,
  oxygenCooldown: undefined,
  debugMode: undefined
});
