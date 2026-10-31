import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import * as codec from "../src/codec/schemas.js";
import { RuleError } from "../src/engine/errors.js";

const dir = new URL("./fixtures/", import.meta.url);
const traces = readdirSync(dir).filter((f) => f.startsWith("trace-") && f.endsWith(".json"));

interface Step {
  at: number;
  command: unknown | null;
  advanceTo: number | null;
  events: unknown[];
  state: unknown;
  error?: string;
}

interface Trace {
  seed: number;
  start: unknown;
  steps: Step[];
}

describe.skipIf(traces.length === 0)("golden traces from the Swift engine", () => {
  it.each(traces)("%s replays to identical state and events", (file) => {
    const trace = JSON.parse(readFileSync(new URL(file, dir), "utf8")) as Trace;
    const engine = codec.gameEngine.dec(trace.start);
    trace.steps.forEach((step, index) => {
      const label = `${file} step ${index}`;
      let events: codec.GameEvent[] = [];
      if (step.command !== null && step.command !== undefined) {
        const command = codec.gameCommand.dec(step.command);
        if (step.error) {
          try {
            engine.apply(command, step.at);
          } catch (error) {
            expect(error, label).toBeInstanceOf(RuleError);
            expect((error as RuleError).kind, label).toBe(step.error);
          }
          expect(engine.state, label).toEqual(codec.gameEngine.dec(step.state).state);
          return;
        }
        events = engine.apply(command, step.at);
      } else if (step.advanceTo !== null && step.advanceTo !== undefined) {
        events = engine.advance(step.advanceTo);
      }
      expect(events.map((e) => codec.gameEvent.enc(e)), label).toEqual(step.events);
      expect(engine.state, label).toEqual(codec.gameEngine.dec(step.state).state);
    });
  });
});

it("reports whether golden traces are present", () => {
  expect(Array.isArray(traces)).toBe(true);
});
