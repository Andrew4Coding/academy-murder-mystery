import {
  aliveFamilies, finalVoteAt, isDebug, outcomeOf, sabotageDuration, skipRequested, type GameEngine
} from "../engine/engine.js";
import type {
  AdminView, ClientView, DeviceStatus, FamilyInfo, FamilySummary, GameView, HostState, Identity, PhaseView,
  PublicDisplayState, VoteResult, VoteResultView, SabotageView, OCStation, GameState
} from "../codec/schemas.js";

export const RESULT_DURATION = 30;

export interface ViewContext {
  state: HostState;
  selfies: Map<string, Buffer>;
  now(): number;
  nearbyFamilies(of: number): number[];
  nearbyBodies(of: number): number[];
  deviceStatuses(): DeviceStatus[];
}

export function playerOf(state: HostState, family: number) {
  for (const player of state.players.values()) if (player.family === family) return player;
  return undefined;
}

export function setupIssues(state: HostState): string[] {
  const issues: string[] = [];
  const debug = isDebug(state.settings);
  const minimum = debug ? 2 : 3;
  if (state.families.size < minimum) issues.push(`Create at least ${minimum} families.`);
  if (state.werewolfCount < 1) issues.push("At least one family must be werewolves.");
  if (!debug && state.werewolfCount * 2 >= state.families.size && state.families.size > 0) {
    issues.push("Werewolf families must be fewer than half of all families.");
  }
  for (const info of [...state.families.values()].sort((a, b) => a.id - b.id)) {
    if (!playerOf(state, info.id)) issues.push(`${info.name} has no player.`);
  }
  return issues;
}

export function stationTitle(station: OCStation): string {
  switch (station.case) {
    case "sabotage": return station._0 === "reactor" ? "Reactor (Collab 7A)" : "Oxygen (Collab 6)";
    case "townHall": return "Town Hall";
    case "admin": return "iPad dashboard";
  }
}

function phaseView(game: GameState | undefined): PhaseView {
  if (!game) return { case: "running" };
  return game.phase;
}

export function sabotageView(engine: GameEngine): SabotageView | undefined {
  const s = engine.state.sabotage;
  return s ? { kind: s.kind, startedAt: s.startedAt, endsAt: s.endsAt } : undefined;
}

export function publicResult(state: HostState, result: VoteResult): VoteResultView {
  return {
    rows: result.tally.map((count) =>
      count.choice.case === "family"
        ? { name: state.families.get(count.choice._0)?.name ?? "Unknown", count: count.count, isSkip: false }
        : { name: "Skip", count: count.count, isSkip: true }
    ),
    expelled: result.expelled.map((r) => ({ name: state.families.get(r.family)?.name ?? "Unknown", role: undefined })),
    isFinal: result.isFinal
  };
}

export function summary(state: HostState, id: number, engine: GameEngine): FamilySummary | undefined {
  const info = state.families.get(id);
  const family = engine.state.families.get(id);
  if (!info || !family) return undefined;
  const player = playerOf(state, id);
  return {
    id,
    name: info.name,
    life: family.life,
    revealedRole: outcomeOf(engine.state) && family.life === "expelled" ? family.role : undefined,
    playerID: player?.id,
    playerName: player?.name
  };
}

const compact = <T>(items: (T | undefined)[]): T[] => items.filter((x): x is T => x !== undefined);

export function adminView(ctx: ViewContext): AdminView {
  const { state } = ctx;
  const engine = state.engine;
  const game = engine?.state;
  const rows = [...state.families.values()]
    .sort((a, b) => a.id - b.id)
    .map((info: FamilyInfo) => {
      const family = game?.families.get(info.id);
      return {
        id: info.id,
        name: info.name,
        playerName: playerOf(state, info.id)?.name,
        life: family?.life ?? ("alive" as const),
        role: family?.role,
        voted: game?.votes.has(info.id) ?? false
      };
    });
  return {
    joinCode: state.gameCode,
    playersJoined: state.players.size,
    isLobby: !engine,
    phase: phaseView(game),
    gameEndsAt: game ? finalVoteAt(game) : undefined,
    families: rows,
    sabotage: engine ? sabotageView(engine) : undefined,
    skipVotes: game?.skipVotes.size ?? 0,
    votersTotal: game ? aliveFamilies(game).length : 0,
    skipRequested: game ? skipRequested(game) : false,
    settings: state.settings,
    werewolfCount: state.werewolfCount,
    rssiThreshold: state.rssiThreshold,
    sightingFreshness: state.sightingFreshness,
    ocPin: state.ocPin,
    setupIssues: engine ? [] : setupIssues(state),
    lastResult: game?.lastResult ? publicResult(state, game.lastResult) : undefined,
    votesCast: game?.votes.size ?? 0,
    devices: ctx.deviceStatuses(),
    timerPausedAt: new Map(game?.timerPausedAt ?? [])
  };
}

function gameView(ctx: ViewContext, info: FamilyInfo, engine: GameEngine, viewer: string): GameView {
  const { state } = ctx;
  const game = engine.state;
  const mine = game.families.get(info.id)!;
  const isWolf = mine.role === "werewolf";
  const allies = isWolf
    ? compact(
        [...game.families.values()]
          .filter((f) => f.role === "werewolf" && f.id !== mine.id)
          .sort((a, b) => a.id - b.id)
          .map((f) => summary(state, f.id, engine))
      )
    : undefined;
  return {
    role: mine.role,
    family: info.id,
    familyName: info.name,
    life: mine.life,
    allies,
    families: compact([...state.families.keys()].sort((a, b) => a - b).map((id) => summary(state, id, engine))),
    phase: game.phase,
    announcedDeaths: compact(game.announcedDeaths.map((id) => summary(state, id, engine))),
    myVote: game.votes.get(info.id),
    votesCast: game.votes.size,
    votersTotal: aliveFamilies(game).length,
    lastResult: game.lastResult ? publicResult(state, game.lastResult) : undefined,
    bleToken: state.players.get(viewer)?.bleToken ?? "",
    proximity: { rssiThreshold: state.rssiThreshold, sightingFreshness: state.sightingFreshness },
    nearby:
      isWolf && mine.life === "alive"
        ? compact(ctx.nearbyFamilies(info.id).map((id) => summary(state, id, engine)))
        : [],
    killReadyAt: isWolf && mine.life === "alive" ? mine.killReadyAt : undefined,
    sabotage: sabotageView(engine),
    sabotageReadyAt: isWolf ? game.sabotageReadyAt : undefined,
    sabotageTimings: (["reactor", "oxygen"] as const).map((kind) => ({
      kind,
      duration: sabotageDuration(game.settings, kind)
    })),
    nearbyBodies:
      mine.life === "alive" ? compact(ctx.nearbyBodies(info.id).map((id) => summary(state, id, engine))) : [],
    bodyActive: mine.life === "killed" && game.deadSinceLastMeeting.includes(info.id),
    skipVotes: game.skipVotes.size,
    mySkipVote: game.skipVotes.has(info.id),
    skipRequested: skipRequested(game),
    startsAt: game.startedAt
  };
}

export function viewFor(ctx: ViewContext, identity: Identity): ClientView | undefined {
  const { state } = ctx;
  if (identity.case === "player") {
    const player = state.players.get(identity._0);
    const info = player && state.families.get(player.family);
    if (!player || !info) return undefined;
    const view: ClientView = {
      serverTime: ctx.now(),
      identity: { case: "player", id: identity._0, name: player.name, family: player.family },
      familyName: info.name,
      lobby: undefined,
      game: undefined,
      oc: undefined,
      admin: undefined
    };
    const engine = state.engine;
    if (engine && engine.state.families.has(info.id)) {
      view.game = gameView(ctx, info, engine, identity._0);
    } else {
      view.lobby = {
        familyName: info.name,
        joinCode: state.gameCode ?? info.joinCode,
        playerID: identity._0,
        playerName: player.name
      };
    }
    return view;
  }
  const device = state.ocDevices.get(identity._0);
  if (!device) return undefined;
  const view: ClientView = {
    serverTime: ctx.now(),
    identity: { case: "oc", id: identity._0, station: device.station },
    familyName: undefined,
    lobby: undefined,
    game: undefined,
    oc: undefined,
    admin: undefined
  };
  if (device.station.case === "admin") view.admin = adminView(ctx);
  else if (state.engine) view.oc = { sabotage: sabotageView(state.engine) };
  return view;
}

function lobbyFamilies(ctx: ViewContext) {
  return [...ctx.state.families.values()]
    .sort((a, b) => a.id - b.id)
    .map((family) => {
      const player = playerOf(ctx.state, family.id);
      return { id: family.id, name: family.name, player: player?.name, selfie: player && ctx.selfies.get(player.id) };
    });
}

function endReveal(ctx: ViewContext, game: GameState) {
  return [...game.families.values()]
    .sort((a, b) => a.id - b.id)
    .map((family) => {
      const player = playerOf(ctx.state, family.id);
      return {
        id: family.id,
        name: ctx.state.families.get(family.id)?.name ?? "Unknown",
        player: player?.name,
        selfie: player && ctx.selfies.get(player.id),
        isWerewolf: family.role === "werewolf"
      };
    });
}

export function publicDisplayState(ctx: ViewContext): PublicDisplayState {
  const { state } = ctx;
  const base = { familiesRemaining: undefined, alarm: undefined, announcedDeaths: [], joinCode: undefined, lobbyFamilies: [], reveal: [] };
  const engine = state.engine;
  if (!engine) {
    return { ...base, screen: { case: "waiting" }, joinCode: state.gameCode, lobbyFamilies: lobbyFamilies(ctx) };
  }
  const game = engine.state;
  const now = ctx.now();
  if (game.startedAt > now) return { ...base, screen: { case: "starting", at: game.startedAt } };

  const names = game.announcedDeaths.map((id) => state.families.get(id)?.name).filter((n): n is string => !!n);
  const alarm = game.sabotage ? { kind: game.sabotage.kind, endsAt: game.sabotage.endsAt } : undefined;
  let screen: PublicDisplayState["screen"];
  const phase = game.phase;
  if (phase.case === "ended") screen = { case: "ended", _0: phase._0 };
  else if (phase.case === "discussion") screen = { case: "discussion", until: phase.until };
  else if (phase.case === "voting") {
    screen = { case: "voting", until: phase.until, isFinal: phase.isFinal, cast: game.votes.size, total: aliveFamilies(game).length };
  } else if (game.lastResult && now - game.lastResult.at < RESULT_DURATION) {
    screen = { case: "result", _0: publicResult(state, game.lastResult) };
  } else {
    screen = { case: "playing", gameEndsAt: finalVoteAt(game) };
  }
  return {
    ...base,
    screen,
    familiesRemaining: aliveFamilies(game).length,
    alarm,
    announcedDeaths: names,
    reveal: outcomeOf(game)?.winner === "werewolves" ? endReveal(ctx, game) : []
  };
}
