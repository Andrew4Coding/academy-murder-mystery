import { SeededGenerator } from "../src/engine/rng.js";
import { GameEngine } from "../src/engine/engine.js";
import { defaultSettings, type Family, type GameCommand, type GameEvent, type GameSettings } from "../src/codec/schemas.js";

export const settings = (overrides: Partial<GameSettings> = {}): GameSettings => ({ ...defaultSettings(), ...overrides });

export class Fixture {
  engine: GameEngine;
  werewolves: number[];
  villagers: number[];

  constructor(families = 6, werewolves = 1, gameSettings: GameSettings = settings(), seed = 7) {
    const { engine } = GameEngine.start(
      Array.from({ length: families }, (_, i) => i + 1),
      werewolves,
      gameSettings,
      0,
      new SeededGenerator(seed)
    );
    this.engine = engine;
    const all = [...engine.state.families.values()];
    this.werewolves = all.filter((f) => f.role === "werewolf").map((f) => f.id).sort((a, b) => a - b);
    this.villagers = all.filter((f) => f.role === "villager").map((f) => f.id).sort((a, b) => a - b);
  }

  apply(command: GameCommand, at: number): GameEvent[] {
    return this.engine.apply(command, at);
  }

  advance(to: number): GameEvent[] {
    return this.engine.advance(to);
  }

  family(id: number): Family {
    return this.engine.state.families.get(id)!;
  }
}

export const kinds = (events: GameEvent[]) => events.map((e) => e.kind);

export const outcomeOf = (events: GameEvent[]) => {
  for (const e of events) if (e.kind.case === "gameEnded") return e.kind._0;
  return undefined;
};

export const fam = (id: number) => ({ case: "family" as const, _0: id });
export const skip = { case: "skip" as const };
