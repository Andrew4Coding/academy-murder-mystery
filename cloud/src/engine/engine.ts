import { RuleError } from "./errors.js";
import { shuffled, type Rng } from "./rng.js";
import type {
  Booth, Family, GameCommand, GameEvent, GameEventKind, GameSettings, GameState, OCOverride, Outcome, Phase,
  Reveal, Role, Side, SabotageKind, TimerTarget, VoteChoice, VoteCount
} from "../codec/schemas.js";

export const ALL_BOOTHS: Booth[] = [1, 2, 3, 4, 5, 6, 7];

export const isDebug = (settings: GameSettings): boolean => settings.debugMode ?? false;

export function sabotageDuration(settings: GameSettings, kind: SabotageKind): number {
  return kind === "oxygen" ? (settings.oxygenDuration ?? settings.sabotageDuration) : settings.sabotageDuration;
}

export function sabotageCooldown(settings: GameSettings, kind: SabotageKind): number {
  if (isDebug(settings)) return 0;
  return kind === "oxygen" ? (settings.oxygenCooldown ?? settings.sabotageCooldown) : settings.sabotageCooldown;
}

const event = (at: number, kind: GameEventKind): GameEvent => ({ at, kind });

const choiceKey = (c: VoteChoice): string => (c.case === "skip" ? "skip" : `f${c._0}`);

const isMeetingPhase = (phase: Phase): boolean => phase.case === "discussion" || phase.case === "voting";

export function aliveFamilies(state: GameState, role?: Role): Family[] {
  return [...state.families.values()]
    .filter((f) => f.life === "alive" && (role === undefined || f.role === role))
    .sort((a, b) => a.id - b.id);
}

export function skipRequested(state: GameState): boolean {
  return state.skipVotes.size * 2 > aliveFamilies(state).length;
}

export function finalVoteAt(state: GameState): number {
  return state.finalVoteOverride ?? state.startedAt + state.settings.gameDuration;
}

export function outcomeOf(state: GameState): Outcome | undefined {
  return state.phase.case === "ended" ? state.phase._0 : undefined;
}

function getFamily(state: GameState, id: number): Family {
  const family = state.families.get(id);
  if (!family) throw new RuleError("unknownFamily");
  return family;
}

type Timer = "sabotageExpiry" | "phaseEnd" | "finalVote";

export class GameEngine {
  constructor(public state: GameState) {}

  static start(
    familyIDs: number[],
    werewolfCount: number,
    settings: GameSettings,
    now: number,
    rng: Rng
  ): { engine: GameEngine; events: GameEvent[] } {
    const ids = [...familyIDs].sort((a, b) => a - b);
    if (new Set(ids).size !== ids.length) throw new RuleError("invalidSetup", "Family IDs must be unique");
    if (werewolfCount < 1) throw new RuleError("invalidSetup", "At least one werewolf family is required");
    const ok = isDebug(settings) ? werewolfCount < ids.length : werewolfCount * 2 < ids.length;
    if (!ok) throw new RuleError("invalidSetup", "Werewolf families must be fewer than half of all families");

    const werewolves = new Set(shuffled(ids, rng).slice(0, werewolfCount));
    const roles = new Map<number, Role>(ids.map((id) => [id, werewolves.has(id) ? "werewolf" : "villager"]));
    return GameEngine.begin(roles, settings, now);
  }

  private static begin(
    roles: Map<number, Role>,
    settings: GameSettings,
    now: number
  ): { engine: GameEngine; events: GameEvent[] } {
    const families = new Map<number, Family>();
    for (const id of [...roles.keys()].sort((a, b) => a - b)) {
      families.set(id, { id, role: roles.get(id) ?? "villager", life: "alive", tasks: new Set(ALL_BOOTHS), killReadyAt: now });
    }
    const state: GameState = {
      settings,
      startedAt: now,
      families,
      phase: { case: "running" },
      sabotage: undefined,
      sabotageReadyAt: now,
      announcedDeaths: [],
      lastResult: undefined,
      deadSinceLastMeeting: [],
      finalVoteStarted: false,
      finalVotePending: false,
      finalVoteOverride: undefined,
      timerPausedAt: undefined,
      votes: new Map(),
      skipVotes: new Set()
    };
    const werewolves = [...families.values()].filter((f) => f.role === "werewolf").map((f) => f.id).sort((a, b) => a - b);
    return { engine: new GameEngine(state), events: [event(now, { case: "gameStarted", werewolves })] };
  }

  advance(now: number): GameEvent[] {
    return this.settle(now);
  }

  apply(command: GameCommand, now: number): GameEvent[] {
    const next = new GameEngine(structuredClone(this.state));
    const events = next.settle(now);
    if (outcomeOf(next.state)) throw new RuleError("gameEnded");
    events.push(...next.perform(command, now));
    next.dropFinishedPauses();
    this.state = next.state;
    return events;
  }

  private settle(now: number): GameEvent[] {
    const events: GameEvent[] = [];
    for (;;) {
      const next = this.nextTimer();
      if (!next || next[0] > now) break;
      events.push(...this.fire(next[1], next[0]));
      this.dropFinishedPauses();
    }
    return events;
  }

  private paused(): Map<TimerTarget, number> {
    return this.state.timerPausedAt ?? new Map();
  }

  private dropFinishedPauses(): void {
    const paused = new Map(this.paused());
    if (!isMeetingPhase(this.state.phase)) paused.delete("meeting");
    if (this.state.finalVoteStarted || outcomeOf(this.state)) paused.delete("finalVote");
    if (!this.state.sabotage) paused.delete("sabotage");
    this.state.timerPausedAt = paused.size === 0 ? undefined : paused;
  }

  private nextTimer(): [number, Timer] | undefined {
    if (outcomeOf(this.state)) return undefined;
    let best: [number, Timer] | undefined;
    const consider = (time: number, timer: Timer) => {
      if (!best || time < best[0]) best = [time, timer];
    };
    const paused = this.paused();
    if (this.state.sabotage && !paused.has("sabotage")) consider(this.state.sabotage.endsAt, "sabotageExpiry");
    if (!paused.has("meeting")) {
      const phase = this.state.phase;
      if (phase.case === "discussion" || phase.case === "voting") consider(phase.until, "phaseEnd");
    }
    if (!this.state.finalVoteStarted && !paused.has("finalVote")) consider(finalVoteAt(this.state), "finalVote");
    return best;
  }

  private fire(timer: Timer, time: number): GameEvent[] {
    const state = this.state;
    switch (timer) {
      case "sabotageExpiry":
        state.sabotage = undefined;
        return [event(time, { case: "sabotageExpired" }), ...this.end("werewolves", "sabotageExpired", time)];
      case "phaseEnd":
        if (state.phase.case === "discussion") {
          state.phase = { case: "voting", until: time + state.settings.votingDuration, isFinal: false };
          return [event(time, { case: "votingOpened", isFinal: false })];
        }
        if (state.phase.case === "voting") return this.closeVoting(time);
        return [];
      case "finalVote":
        state.finalVoteStarted = true;
        if (state.phase.case === "running") return this.openFinalVote(time);
        state.finalVotePending = true;
        return [];
    }
  }

  private openFinalVote(time: number): GameEvent[] {
    const state = this.state;
    const dead = state.deadSinceLastMeeting;
    state.deadSinceLastMeeting = [];
    state.announcedDeaths = dead;
    state.lastResult = undefined;
    state.votes = new Map();
    state.phase = { case: "voting", until: time + state.settings.votingDuration, isFinal: true };
    return [
      event(time, { case: "meetingStarted", deadFamilies: dead }),
      event(time, { case: "votingOpened", isFinal: true })
    ];
  }

  private perform(command: GameCommand, now: number): GameEvent[] {
    switch (command.case) {
      case "kill": return this.kill(command.killer, command.victim, now);
      case "requestSabotage": return this.requestSabotage(command.by, command.kind, now);
      case "resolveSabotage": return this.resolveSabotage(now);
      case "startMeeting": return this.startMeeting(now);
      case "reportBody": return this.reportBody(command.by, command.body, now);
      case "castVote": return this.castVote(command.by, command.choice, now);
      case "proxyVote": return this.proxyVote(command.for, command.choice, now);
      case "extendMeeting": return this.extendMeeting(command.seconds);
      case "adjustTimer": return this.adjustTimer(command._0, command.seconds, now);
      case "pauseTimer": return this.pauseTimer(command._0, now);
      case "resumeTimer": return this.resumeTimer(command._0, now);
      case "voteSkipDiscussion": return this.voteSkipDiscussion(command.by, now);
      case "approveSkipDiscussion": return this.approveSkipDiscussion(now);
      case "override": return this.applyOverride(command._0, now);
    }
  }

  private kill(killerID: number, victimID: number, now: number): GameEvent[] {
    const state = this.state;
    if (state.phase.case !== "running") throw new RuleError("wrongPhase");
    const killer = getFamily(state, killerID);
    const victim = getFamily(state, victimID);
    if (killer.role !== "werewolf") throw new RuleError("notWerewolf");
    if (killer.life !== "alive") throw new RuleError("familyNotAlive");
    if (victim.role !== "villager") throw new RuleError("notVillager");
    if (victim.life !== "alive") throw new RuleError("familyNotAlive");
    if (now < killer.killReadyAt) throw new RuleError("cooldownActive");

    victim.life = "killed";
    state.deadSinceLastMeeting.push(victimID);
    killer.killReadyAt = now + (isDebug(state.settings) ? 0 : state.settings.killCooldown);
    const killed = event(now, { case: "familyKilled", _0: victimID, by: killerID });
    return isDebug(state.settings) ? [killed] : [killed, ...this.evaluateWin(now)];
  }

  private requestSabotage(id: number, kind: SabotageKind, now: number): GameEvent[] {
    const state = this.state;
    if (state.phase.case !== "running") throw new RuleError("wrongPhase");
    const family = getFamily(state, id);
    if (family.role !== "werewolf") throw new RuleError("notWerewolf");
    if (state.sabotage) throw new RuleError("sabotageAlreadyActive");
    if (now < state.sabotageReadyAt) throw new RuleError("cooldownActive");

    const endsAt = now + sabotageDuration(state.settings, kind);
    state.sabotage = { kind, startedAt: now, endsAt, triggeredBy: id };
    state.sabotageReadyAt = endsAt + sabotageCooldown(state.settings, kind);
    return [event(now, { case: "sabotageStarted", kind, by: id, endsAt })];
  }

  private resolveSabotage(now: number): GameEvent[] {
    const sabotage = this.state.sabotage;
    if (!sabotage) throw new RuleError("noActiveSabotage");
    this.state.sabotage = undefined;
    this.state.sabotageReadyAt = now + sabotageCooldown(this.state.settings, sabotage.kind);
    return [event(now, { case: "sabotageResolved" })];
  }

  private reportBody(id: number, body: number, now: number): GameEvent[] {
    const state = this.state;
    if (state.phase.case !== "running") throw new RuleError("wrongPhase");
    if (state.sabotage) throw new RuleError("sabotageActive");
    if (getFamily(state, id).life !== "alive") throw new RuleError("familyNotAlive");
    if (!state.deadSinceLastMeeting.includes(body) || getFamily(state, body).life !== "killed") {
      throw new RuleError("notDead");
    }
    return this.startMeeting(now);
  }

  private startMeeting(now: number): GameEvent[] {
    const state = this.state;
    if (state.phase.case !== "running") throw new RuleError("wrongPhase");
    if (state.sabotage) throw new RuleError("sabotageActive");
    const dead = state.deadSinceLastMeeting;
    state.deadSinceLastMeeting = [];
    state.announcedDeaths = dead;
    state.lastResult = undefined;
    state.votes = new Map();
    state.skipVotes = new Set();
    state.phase = { case: "discussion", until: now + state.settings.discussionDuration };
    return [event(now, { case: "meetingStarted", deadFamilies: dead })];
  }

  private extendMeeting(seconds: number): GameEvent[] {
    if (!(seconds > 0)) throw new RuleError("wrongPhase");
    const phase = this.state.phase;
    if (phase.case === "discussion") this.state.phase = { case: "discussion", until: phase.until + seconds };
    else if (phase.case === "voting") this.state.phase = { case: "voting", until: phase.until + seconds, isFinal: phase.isFinal };
    else throw new RuleError("wrongPhase");
    return [];
  }

  private adjustTimer(target: TimerTarget, seconds: number, now: number): GameEvent[] {
    const state = this.state;
    const floor = (this.paused().get(target) ?? now) + 1;
    const moved = (end: number) => Math.max(end + seconds, floor);
    switch (target) {
      case "meeting": {
        const phase = state.phase;
        if (phase.case === "discussion") state.phase = { case: "discussion", until: moved(phase.until) };
        else if (phase.case === "voting") state.phase = { case: "voting", until: moved(phase.until), isFinal: phase.isFinal };
        else throw new RuleError("wrongPhase");
        break;
      }
      case "finalVote":
        if (state.finalVoteStarted) throw new RuleError("timerFinished");
        state.finalVoteOverride = moved(finalVoteAt(state));
        break;
      case "sabotage":
        if (!state.sabotage) throw new RuleError("noActiveSabotage");
        state.sabotage = { ...state.sabotage, endsAt: moved(state.sabotage.endsAt) };
        break;
    }
    return [event(now, { case: "ocOverride", _0: { case: "timerAdjusted", _0: target, seconds } })];
  }

  private requireRunning(target: TimerTarget): void {
    const state = this.state;
    switch (target) {
      case "meeting":
        if (!isMeetingPhase(state.phase)) throw new RuleError("wrongPhase");
        break;
      case "finalVote":
        if (state.finalVoteStarted) throw new RuleError("timerFinished");
        break;
      case "sabotage":
        if (!state.sabotage) throw new RuleError("noActiveSabotage");
        break;
    }
  }

  private pauseTimer(target: TimerTarget, now: number): GameEvent[] {
    this.requireRunning(target);
    if (this.paused().has(target)) return [];
    this.state.timerPausedAt = new Map(this.paused()).set(target, now);
    return [event(now, { case: "ocOverride", _0: { case: "timerPaused", _0: target } })];
  }

  private resumeTimer(target: TimerTarget, now: number): GameEvent[] {
    this.requireRunning(target);
    const pausedAt = this.paused().get(target);
    if (pausedAt === undefined) return [];
    const gap = Math.max(0, now - pausedAt);
    const state = this.state;
    switch (target) {
      case "meeting": {
        const phase = state.phase;
        if (phase.case === "discussion") state.phase = { case: "discussion", until: phase.until + gap };
        else if (phase.case === "voting") state.phase = { case: "voting", until: phase.until + gap, isFinal: phase.isFinal };
        break;
      }
      case "finalVote":
        state.finalVoteOverride = finalVoteAt(state) + gap;
        break;
      case "sabotage":
        if (state.sabotage) state.sabotage.endsAt += gap;
        break;
    }
    const paused = new Map(this.paused());
    paused.delete(target);
    state.timerPausedAt = paused.size === 0 ? undefined : paused;
    return [event(now, { case: "ocOverride", _0: { case: "timerResumed", _0: target } })];
  }

  private voteSkipDiscussion(id: number, now: number): GameEvent[] {
    const state = this.state;
    if (state.phase.case !== "discussion") throw new RuleError("wrongPhase");
    if (getFamily(state, id).life !== "alive") throw new RuleError("familyNotAlive");
    if (state.skipVotes.has(id)) state.skipVotes.delete(id);
    else state.skipVotes.add(id);
    if (!skipRequested(state)) return [];
    return this.skipDiscussion(now);
  }

  private skipDiscussion(now: number): GameEvent[] {
    const state = this.state;
    state.skipVotes = new Set();
    state.timerPausedAt?.delete("meeting");
    state.phase = { case: "voting", until: now + state.settings.votingDuration, isFinal: false };
    return [event(now, { case: "votingOpened", isFinal: false })];
  }

  private approveSkipDiscussion(now: number): GameEvent[] {
    if (this.state.phase.case !== "discussion") throw new RuleError("wrongPhase");
    if (!skipRequested(this.state)) throw new RuleError("skipNotRequested");
    return this.skipDiscussion(now);
  }

  private castVote(id: number, choice: VoteChoice, now: number): GameEvent[] {
    const state = this.state;
    if (state.phase.case !== "voting") throw new RuleError("wrongPhase");
    const voter = getFamily(state, id);
    if (voter.life !== "alive") throw new RuleError("familyNotAlive");
    if (choice.case === "family" && getFamily(state, choice._0).life !== "alive") throw new RuleError("invalidVoteTarget");
    state.votes.set(id, choice);
    return [event(now, { case: "voteCast", by: id }), ...this.closeVotingIfComplete(now)];
  }

  private proxyVote(id: number, choice: VoteChoice, now: number): GameEvent[] {
    if (this.state.phase.case !== "voting") throw new RuleError("wrongPhase");
    return [
      event(now, { case: "ocOverride", _0: { case: "proxyVote", _0: id } }),
      ...this.castVote(id, choice, now)
    ];
  }

  private applyOverride(override: OCOverride, now: number): GameEvent[] {
    const state = this.state;
    const events: GameEvent[] = [event(now, { case: "ocOverride", _0: override })];
    switch (override.case) {
      case "forceKill": {
        const id = override._0;
        const family = getFamily(state, id);
        if (family.life !== "alive") throw new RuleError("familyNotAlive");
        family.life = "killed";
        state.deadSinceLastMeeting.push(id);
        state.votes.delete(id);
        events.push(event(now, { case: "familyKilled", _0: id, by: undefined }));
        events.push(...this.evaluateWin(now));
        if (!outcomeOf(state)) events.push(...this.closeVotingIfComplete(now));
        break;
      }
      case "revive": {
        const id = override._0;
        const family = getFamily(state, id);
        if (family.life === "alive") throw new RuleError("notDead");
        family.life = "alive";
        state.deadSinceLastMeeting = state.deadSinceLastMeeting.filter((x) => x !== id);
        events.push(...this.evaluateWin(now));
        break;
      }
      case "endGame":
        events.push(...this.end(override._0, "ocEnded", now));
        break;
      default:
        throw new RuleError("wrongPhase");
    }
    return events;
  }

  private closeVotingIfComplete(now: number): GameEvent[] {
    if (this.state.phase.case !== "voting" || this.state.votes.size < aliveFamilies(this.state).length) return [];
    return this.closeVoting(now);
  }

  private closeVoting(time: number): GameEvent[] {
    const state = this.state;
    if (state.phase.case !== "voting") return [];
    const isFinal = state.phase.isFinal;
    const votes = state.votes;
    state.votes = new Map();
    const tally = tallyVotes(votes);
    if (isFinal) return this.closeFinalVote(votes, tally, time);

    const expelled: Reveal[] = [];
    const leader = uniqueLeader(tally);
    if (leader && leader.case === "family") {
      const family = state.families.get(leader._0);
      if (family) family.life = "expelled";
      expelled.push({ family: leader._0, role: family?.role ?? "villager" });
    }
    state.phase = { case: "running" };
    state.lastResult = { tally, expelled, isFinal: false, at: time };
    const events: GameEvent[] = [event(time, { case: "voteClosed", tally, expelled, isFinal: false })];
    events.push(...this.evaluateWin(time));
    if (!outcomeOf(state) && state.finalVotePending) {
      state.finalVotePending = false;
      events.push(...this.openFinalVote(time));
    }
    return events;
  }

  private closeFinalVote(votes: Map<number, VoteChoice>, tally: VoteCount[], time: number): GameEvent[] {
    const state = this.state;
    const living = aliveFamilies(state);
    const werewolves = new Set(living.filter((f) => f.role === "werewolf").map((f) => f.id));
    const counts = new Map<number, number>();
    for (const choice of votes.values()) {
      if (choice.case === "family") counts.set(choice._0, (counts.get(choice._0) ?? 0) + 1);
    }
    const count = (id: number) => counts.get(id) ?? 0;
    const ranked = living.map((f) => f.id).sort((a, b) => (count(a) !== count(b) ? count(b) - count(a) : a - b));

    const cutoff = werewolves.size;
    let cleanCut: boolean;
    if (cutoff >= ranked.length) {
      cleanCut = true;
    } else {
      const last = count(ranked[cutoff - 1] ?? -1);
      cleanCut = last > 0 && last > count(ranked[cutoff]!);
    }

    const expelled: Reveal[] = [];
    if (cleanCut) {
      for (const id of ranked.slice(0, cutoff)) {
        const family = state.families.get(id);
        if (family) family.life = "expelled";
        expelled.push({ family: id, role: family?.role ?? "villager" });
      }
    }
    const top = new Set(ranked.slice(0, cutoff));
    const caught = cleanCut && top.size === werewolves.size && [...top].every((id) => werewolves.has(id));
    state.lastResult = { tally, expelled, isFinal: true, at: time };
    return [
      event(time, { case: "voteClosed", tally, expelled, isFinal: true }),
      ...this.end(caught ? "villagers" : "werewolves", caught ? "finalVoteSucceeded" : "finalVoteFailed", time)
    ];
  }

  private evaluateWin(now: number): GameEvent[] {
    const werewolves = aliveFamilies(this.state, "werewolf").length;
    const villagers = aliveFamilies(this.state, "villager").length;
    if (werewolves === 0) return this.end("villagers", "allWerewolvesRemoved", now);
    if (!isDebug(this.state.settings) && villagers <= werewolves) return this.end("werewolves", "parity", now);
    return [];
  }

  private end(winner: Side, reason: Outcome["reason"], now: number): GameEvent[] {
    const outcome: Outcome = { winner, reason };
    this.state.phase = { case: "ended", _0: outcome };
    this.state.sabotage = undefined;
    this.state.votes = new Map();
    return [event(now, { case: "gameEnded", _0: outcome })];
  }
}

export function tallyVotes(votes: Map<number, VoteChoice>): VoteCount[] {
  const counts = new Map<number, number>();
  let skips: number | undefined;
  for (const choice of votes.values()) {
    if (choice.case === "family") counts.set(choice._0, (counts.get(choice._0) ?? 0) + 1);
    else skips = (skips ?? 0) + 1;
  }
  const result: VoteCount[] = [...counts.keys()]
    .sort((a, b) => a - b)
    .map((id) => ({ choice: { case: "family", _0: id }, count: counts.get(id)! }));
  if (skips !== undefined) result.push({ choice: { case: "skip" }, count: skips });
  return result;
}

function uniqueLeader(tally: VoteCount[]): VoteChoice | undefined {
  if (tally.length === 0) return undefined;
  const top = Math.max(...tally.map((t) => t.count));
  const leaders = tally.filter((t) => t.count === top);
  return leaders.length === 1 ? leaders[0]!.choice : undefined;
}

export { choiceKey };
