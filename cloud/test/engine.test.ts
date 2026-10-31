import { describe, expect, it } from "vitest";
import { RuleError } from "../src/engine/errors.js";
import { GameEngine } from "../src/engine/engine.js";
import { SeededGenerator, shuffled } from "../src/engine/rng.js";
import * as codec from "../src/codec/schemas.js";
import { Fixture, fam, kinds, outcomeOf, settings, skip } from "./support.js";

const throwsRule = (kind: string, fn: () => unknown) => {
  try {
    fn();
  } catch (e) {
    expect(e).toBeInstanceOf(RuleError);
    expect((e as RuleError).kind).toBe(kind);
    return;
  }
  throw new Error(`expected ${kind}`);
};

describe("setup", () => {
  it("validates werewolf share and unique families", () => {
    const rng = () => new SeededGenerator(1);
    expect(() => GameEngine.start([1, 2, 3, 4], 2, settings(), 0, rng())).toThrow();
    expect(() => GameEngine.start([1, 2, 3, 4], 0, settings(), 0, rng())).toThrow();
    expect(() => GameEngine.start([1, 1, 2], 1, settings(), 0, rng())).toThrow();
    expect(() => GameEngine.start([1, 2], 1, settings({ debugMode: true }), 0, rng())).not.toThrow();
  });

  it("is deterministic per seed", () => {
    const a = new Fixture(8, 2, settings(), 99);
    const b = new Fixture(8, 2, settings(), 99);
    expect(a.werewolves).toEqual(b.werewolves);
    expect(shuffled([1, 2, 3, 4, 5], new SeededGenerator(3))).toEqual(shuffled([1, 2, 3, 4, 5], new SeededGenerator(3)));
  });

  it("matches the splitmix64 reference sequence", () => {
    const g = new SeededGenerator(0);
    expect(g.next()).toBe(0xe220a8397b1dcdafn);
    expect(g.next()).toBe(0x6e789e6aa1b965f4n);
  });
});

describe("kill and sabotage", () => {
  it("kills a family and starts the cooldown", () => {
    const f = new Fixture();
    const [wolf, victim] = [f.werewolves[0]!, f.villagers[0]!];
    const events = f.apply({ case: "kill", killer: wolf, victim }, 61);
    expect(kinds(events)).toContainEqual({ case: "familyKilled", _0: victim, by: wolf });
    expect(f.family(victim).life).toBe("killed");
    expect(f.family(wolf).killReadyAt).toBe(121);
  });

  it("respects the kill cooldown", () => {
    const f = new Fixture();
    const wolf = f.werewolves[0]!;
    f.apply({ case: "kill", killer: wolf, victim: f.villagers[0]! }, 0);
    throwsRule("cooldownActive", () => f.apply({ case: "kill", killer: wolf, victim: f.villagers[1]! }, 59));
    f.apply({ case: "kill", killer: wolf, victim: f.villagers[1]! }, 60);
  });

  it("rejects invalid actors and targets, and leaves state untouched", () => {
    const f = new Fixture();
    const [wolf, villager, other] = [f.werewolves[0]!, f.villagers[0]!, f.villagers[1]!];
    const before = structuredClone(f.engine.state);
    throwsRule("notWerewolf", () => f.apply({ case: "kill", killer: villager, victim: other }, 100));
    throwsRule("notVillager", () => f.apply({ case: "kill", killer: wolf, victim: wolf }, 100));
    expect(f.engine.state).toEqual(before);
    f.apply({ case: "kill", killer: wolf, victim: villager }, 100);
    throwsRule("familyNotAlive", () => f.apply({ case: "kill", killer: wolf, victim: villager }, 200));
  });

  it("blocks kills during meetings", () => {
    const f = new Fixture();
    const [wolf, victim] = [f.werewolves[0]!, f.villagers[0]!];
    f.apply({ case: "startMeeting" }, 100);
    throwsRule("wrongPhase", () => f.apply({ case: "kill", killer: wolf, victim }, 110));
    f.advance(230);
    throwsRule("wrongPhase", () => f.apply({ case: "kill", killer: wolf, victim }, 231));
    f.advance(350);
    f.apply({ case: "kill", killer: wolf, victim }, 351);
  });

  it("shares the sabotage cooldown and resets it on resolve", () => {
    const f = new Fixture(6, 2);
    const [first, second] = [f.werewolves[0]!, f.werewolves[1]!];
    const events = f.apply({ case: "requestSabotage", by: first, kind: "reactor" }, 0);
    expect(kinds(events)).toEqual([{ case: "sabotageStarted", kind: "reactor", by: first, endsAt: 90 }]);
    expect(f.engine.state.sabotageReadyAt).toBe(210);
    f.apply({ case: "resolveSabotage" }, 10);
    expect(f.engine.state.sabotageReadyAt).toBe(130);
    throwsRule("cooldownActive", () => f.apply({ case: "requestSabotage", by: second, kind: "oxygen" }, 129));
    f.apply({ case: "requestSabotage", by: second, kind: "oxygen" }, 130);
  });

  it("allows one sabotage at a time and none during meetings", () => {
    const f = new Fixture(6, 1, settings({ sabotageCooldown: 0 }));
    const wolf = f.werewolves[0]!;
    f.apply({ case: "requestSabotage", by: wolf, kind: "reactor" }, 10);
    throwsRule("sabotageAlreadyActive", () => f.apply({ case: "requestSabotage", by: wolf, kind: "oxygen" }, 20));
    f.apply({ case: "resolveSabotage" }, 30);
    f.apply({ case: "startMeeting" }, 40);
    throwsRule("wrongPhase", () => f.apply({ case: "requestSabotage", by: wolf, kind: "oxygen" }, 50));
  });

  it("ends the game when a sabotage expires", () => {
    const f = new Fixture();
    const wolf = f.werewolves[0]!;
    f.apply({ case: "requestSabotage", by: wolf, kind: "oxygen" }, 120);
    expect(kinds(f.apply({ case: "resolveSabotage" }, 209))).toEqual([{ case: "sabotageResolved" }]);
    expect(outcomeOf(f.advance(400))).toBeUndefined();
    f.apply({ case: "requestSabotage", by: wolf, kind: "oxygen" }, 400);
    expect(outcomeOf(f.advance(490))).toEqual({ winner: "werewolves", reason: "sabotageExpired" });
  });

  it("refuses meetings while a sabotage runs", () => {
    const f = new Fixture();
    f.apply({ case: "requestSabotage", by: f.werewolves[0]!, kind: "reactor" }, 10);
    throwsRule("sabotageActive", () => f.apply({ case: "startMeeting" }, 20));
  });
});

describe("meetings and voting", () => {
  const openVoting = (f: Fixture, start = 100) => {
    f.apply({ case: "startMeeting" }, start);
    f.advance(start + 120);
  };

  it("moves discussion -> voting -> running", () => {
    const f = new Fixture();
    expect(kinds(f.apply({ case: "startMeeting" }, 100))).toEqual([{ case: "meetingStarted", deadFamilies: [] }]);
    expect(f.engine.state.phase).toEqual({ case: "discussion", until: 220 });
    expect(kinds(f.advance(220))).toEqual([{ case: "votingOpened", isFinal: false }]);
    expect(f.engine.state.phase).toEqual({ case: "voting", until: 340, isFinal: false });
    expect(kinds(f.advance(340))).toEqual([{ case: "voteClosed", tally: [], expelled: [], isFinal: false }]);
    expect(f.engine.state.phase).toEqual({ case: "running" });
  });

  it("announces deaths since the last meeting once", () => {
    const f = new Fixture();
    const victim = f.villagers[0]!;
    f.apply({ case: "kill", killer: f.werewolves[0]!, victim }, 70);
    expect(kinds(f.apply({ case: "startMeeting" }, 100))).toEqual([{ case: "meetingStarted", deadFamilies: [victim] }]);
    f.advance(340);
    expect(kinds(f.apply({ case: "startMeeting" }, 400))).toEqual([{ case: "meetingStarted", deadFamilies: [] }]);
  });

  it("rejects votes outside voting, from the dead, and for the dead", () => {
    const f = new Fixture();
    const [voter, other] = [f.villagers[0]!, f.villagers[1]!];
    throwsRule("wrongPhase", () => f.apply({ case: "castVote", by: voter, choice: skip }, 10));
    f.apply({ case: "override", _0: { case: "forceKill", _0: other } }, 20);
    openVoting(f);
    throwsRule("familyNotAlive", () => f.apply({ case: "castVote", by: other, choice: skip }, 230));
    throwsRule("invalidVoteTarget", () => f.apply({ case: "castVote", by: voter, choice: fam(other) }, 230));
  });

  it("expels the majority target and reveals its role", () => {
    const f = new Fixture();
    const wolf = f.werewolves[0]!;
    openVoting(f);
    for (const voter of f.villagers.slice(0, 3)) f.apply({ case: "castVote", by: voter, choice: fam(wolf) }, 230);
    f.apply({ case: "castVote", by: wolf, choice: fam(f.villagers[0]!) }, 231);
    const closed = f.advance(340);
    const first = closed[0]!.kind;
    expect(first.case).toBe("voteClosed");
    if (first.case === "voteClosed") {
      expect(first.expelled).toEqual([{ family: wolf, role: "werewolf" }]);
      expect(first.tally.map((t) => t.count).sort()).toEqual([1, 3]);
    }
    expect(f.family(wolf).life).toBe("expelled");
  });

  it("expels nobody on a skip lead or tie", () => {
    const f = new Fixture();
    const [a, b] = [f.villagers[0]!, f.villagers[1]!];
    openVoting(f);
    f.apply({ case: "castVote", by: a, choice: skip }, 230);
    f.apply({ case: "castVote", by: b, choice: skip }, 230);
    f.apply({ case: "castVote", by: f.villagers[2]!, choice: fam(a) }, 230);
    f.advance(340);
    expect(f.engine.state.families.size).toBe(6);
    expect([...f.engine.state.families.values()].every((x) => x.life === "alive")).toBe(true);
    openVoting(f, 400);
    f.apply({ case: "castVote", by: a, choice: fam(b) }, 530);
    f.apply({ case: "castVote", by: b, choice: fam(a) }, 530);
    f.advance(640);
    expect([...f.engine.state.families.values()].every((x) => x.life === "alive")).toBe(true);
  });

  it("closes early when every living family voted, and lets families change votes", () => {
    const f = new Fixture(4, 1);
    openVoting(f);
    f.apply({ case: "castVote", by: 1, choice: fam(2) }, 230);
    f.apply({ case: "castVote", by: 1, choice: skip }, 235);
    let closing: ReturnType<typeof f.apply> = [];
    for (const id of [1, 2, 3, 4]) closing = f.apply({ case: "castVote", by: id, choice: skip }, 240);
    expect(kinds(closing)).toContainEqual({ case: "voteClosed", tally: [{ choice: skip, count: 4 }], expelled: [], isFinal: false });
    expect(f.engine.state.phase).toEqual({ case: "running" });
    expect(f.engine.state.votes.size).toBe(0);
  });

  it("opens voting once a majority votes to skip discussion", () => {
    const f = new Fixture(4, 1);
    f.apply({ case: "startMeeting" }, 100);
    f.apply({ case: "voteSkipDiscussion", by: 1 }, 101);
    f.apply({ case: "voteSkipDiscussion", by: 1 }, 102);
    expect(f.engine.state.skipVotes.size).toBe(0);
    f.apply({ case: "voteSkipDiscussion", by: 1 }, 103);
    f.apply({ case: "voteSkipDiscussion", by: 2 }, 104);
    const events = f.apply({ case: "voteSkipDiscussion", by: 3 }, 105);
    expect(kinds(events)).toEqual([{ case: "votingOpened", isFinal: false }]);
  });
});

describe("final vote", () => {
  it("opens at the game limit with announced deaths", () => {
    const f = new Fixture();
    const victim = f.villagers[0]!;
    f.apply({ case: "kill", killer: f.werewolves[0]!, victim }, 100);
    expect(kinds(f.advance(2700))).toEqual([
      { case: "meetingStarted", deadFamilies: [victim] },
      { case: "votingOpened", isFinal: true }
    ]);
    expect(f.engine.state.phase).toEqual({ case: "voting", until: 2820, isFinal: true });
  });

  it("gives villagers the win when the top families are exactly the werewolves", () => {
    const f = new Fixture(6, 2);
    f.advance(2700);
    const wolves = f.werewolves;
    f.villagers.forEach((id, i) => f.apply({ case: "castVote", by: id, choice: fam(wolves[i % 2]!) }, 2710));
    f.apply({ case: "castVote", by: wolves[0]!, choice: fam(f.villagers[0]!) }, 2711);
    const events = f.apply({ case: "castVote", by: wolves[1]!, choice: skip }, 2712);
    expect(outcomeOf(events)).toEqual({ winner: "villagers", reason: "finalVoteSucceeded" });
    expect(f.family(wolves[0]!).life).toBe("expelled");
  });

  it("gives werewolves the win when a villager outranks a werewolf, on a tie, or with no votes", () => {
    const a = new Fixture();
    a.advance(2700);
    const scapegoat = a.villagers[0]!;
    for (const id of a.villagers) a.apply({ case: "castVote", by: id, choice: fam(scapegoat) }, 2710);
    expect(outcomeOf(a.apply({ case: "castVote", by: a.werewolves[0]!, choice: skip }, 2711))).toEqual({
      winner: "werewolves", reason: "finalVoteFailed"
    });

    const b = new Fixture();
    b.advance(2700);
    const wolf = b.werewolves[0]!;
    const rival = b.villagers[0]!;
    [fam(wolf), fam(wolf), fam(rival), fam(rival), skip].forEach((choice, i) =>
      b.apply({ case: "castVote", by: b.villagers[i]!, choice }, 2710)
    );
    expect(outcomeOf(b.apply({ case: "castVote", by: wolf, choice: skip }, 2711))).toEqual({
      winner: "werewolves", reason: "finalVoteFailed"
    });
    expect(b.family(wolf).life).toBe("alive");

    const c = new Fixture();
    c.advance(2700);
    expect(outcomeOf(c.advance(2820))).toEqual({ winner: "werewolves", reason: "finalVoteFailed" });
  });

  it("waits for a meeting in progress", () => {
    const f = new Fixture();
    f.apply({ case: "startMeeting" }, 2650);
    expect(f.advance(2700)).toEqual([]);
    expect(f.engine.state.finalVotePending).toBe(true);
    f.advance(2770);
    expect(kinds(f.advance(2890))).toContainEqual({ case: "votingOpened", isFinal: true });
    expect(f.engine.state.phase).toEqual({ case: "voting", until: 3010, isFinal: true });
  });
});

describe("timers and overrides", () => {
  it("pauses and resumes the meeting timer with the gap added back", () => {
    const f = new Fixture();
    f.apply({ case: "startMeeting" }, 100);
    f.apply({ case: "pauseTimer", _0: "meeting" }, 150);
    expect(f.advance(1000)).toEqual([]);
    f.apply({ case: "resumeTimer", _0: "meeting" }, 400);
    expect(f.engine.state.phase).toEqual({ case: "discussion", until: 470 });
    expect(f.engine.state.timerPausedAt).toBeUndefined();
  });

  it("adjusts timers with a floor one second ahead", () => {
    const f = new Fixture();
    f.apply({ case: "startMeeting" }, 100);
    f.apply({ case: "adjustTimer", _0: "meeting", seconds: -1000 }, 110);
    expect(f.engine.state.phase).toEqual({ case: "discussion", until: 111 });
    f.apply({ case: "adjustTimer", _0: "finalVote", seconds: 60 }, 120);
    expect(f.engine.state.finalVoteOverride).toBe(2760);
    throwsRule("noActiveSabotage", () => f.apply({ case: "adjustTimer", _0: "sabotage", seconds: 5 }, 120));
  });

  it("applies OC force kill, revive and end game, and rejects timer overrides as commands", () => {
    const f = new Fixture(6, 2);
    const wolf = f.werewolves[0]!;
    const events = f.apply({ case: "override", _0: { case: "forceKill", _0: wolf } }, 10);
    expect(kinds(events)).toContainEqual({ case: "familyKilled", _0: wolf, by: undefined });
    f.apply({ case: "override", _0: { case: "revive", _0: wolf } }, 20);
    expect(f.family(wolf).life).toBe("alive");
    throwsRule("notDead", () => f.apply({ case: "override", _0: { case: "revive", _0: wolf } }, 30));
    throwsRule("wrongPhase", () => f.apply({ case: "override", _0: { case: "timerPaused", _0: "meeting" } }, 30));
    const end = f.apply({ case: "override", _0: { case: "endGame", _0: "villagers" } }, 40);
    expect(outcomeOf(end)).toEqual({ winner: "villagers", reason: "ocEnded" });
    throwsRule("gameEnded", () => f.apply({ case: "startMeeting" }, 50));
  });

  it("applies parity win on kill, but not in debug mode", () => {
    const f = new Fixture(3, 1);
    const events = f.apply({ case: "kill", killer: f.werewolves[0]!, victim: f.villagers[0]! }, 0);
    expect(outcomeOf(events)).toEqual({ winner: "werewolves", reason: "parity" });
    const d = new Fixture(3, 1, settings({ debugMode: true }));
    expect(outcomeOf(d.apply({ case: "kill", killer: d.werewolves[0]!, victim: d.villagers[0]! }, 0))).toBeUndefined();
    expect(d.family(d.werewolves[0]!).killReadyAt).toBe(0);
  });
});

describe("persistence of engine state", () => {
  it("round-trips through the codec and continues identically", () => {
    const f = new Fixture();
    f.apply({ case: "startMeeting" }, 100);
    const json = JSON.parse(JSON.stringify(codec.gameEngine.enc(f.engine)));
    const restored = codec.gameEngine.dec(json);
    expect(restored.advance(500)).toEqual(f.advance(500));
    expect(restored.state).toEqual(f.engine.state);
  });

  it("does not encode ballots", () => {
    const f = new Fixture();
    f.apply({ case: "startMeeting" }, 100);
    f.advance(220);
    f.apply({ case: "castVote", by: f.villagers[0]!, choice: skip }, 230);
    const json = codec.gameEngine.enc(f.engine) as { state: Record<string, unknown> };
    expect(json.state.votes).toBeUndefined();
    expect(json.state.skipVotes).toBeUndefined();
  });
});
