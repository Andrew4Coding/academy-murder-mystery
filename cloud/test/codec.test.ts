import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import * as codec from "../src/codec/schemas.js";
import { DecodeError } from "../src/codec/combinators.js";
import { freshHostState } from "../src/host/host.js";
import { Fixture, fam } from "./support.js";

const dir = new URL("./fixtures/", import.meta.url);
const files = readdirSync(dir).filter((f) => f.startsWith("wire-") && f.endsWith(".json"));

const codecs = {
  ClientMessage: codec.clientMessage,
  ServerMessage: codec.serverMessage,
  AdminCommand: codec.adminCommand
} as const;

describe("wire fixtures", () => {
  it("has fixtures", () => {
    expect(files.length).toBeGreaterThan(40);
  });

  it.each(files)("%s decodes and re-encodes to equal JSON", (file) => {
    const fixture = JSON.parse(readFileSync(new URL(file, dir), "utf8")) as { type: keyof typeof codecs; json: unknown };
    const c = codecs[fixture.type] as { dec(j: unknown): unknown; enc(v: unknown): unknown };
    expect(JSON.parse(JSON.stringify(c.enc(c.dec(fixture.json))))).toEqual(fixture.json);
  });

  it("covers every enum case of the three wire enums", () => {
    const seen: Record<string, Set<string>> = { ClientMessage: new Set(), ServerMessage: new Set(), AdminCommand: new Set() };
    for (const file of files) {
      const fixture = JSON.parse(readFileSync(new URL(file, dir), "utf8")) as { type: string; json: object };
      seen[fixture.type]!.add(Object.keys(fixture.json)[0]!);
    }
    expect(seen.ClientMessage!.size).toBe(14);
    expect(seen.ServerMessage!.size).toBe(8);
    expect(seen.AdminCommand!.size).toBe(23);
  });
});

describe("swift encoding conventions", () => {
  it("encodes FamilyID as a struct and dictionaries as flat arrays", () => {
    const state = freshHostState("1234");
    state.families.set(2, { id: 2, name: "Family 2", joinCode: "AAAAAA" });
    const json = codec.hostState.enc(state) as Record<string, unknown>;
    expect(json.families).toEqual([{ rawValue: 2 }, { id: { rawValue: 2 }, name: "Family 2", joinCode: "AAAAAA" }]);
    expect(json.players).toEqual([]);
    expect(json.gameCode).toBeUndefined();
    expect("engine" in json).toBe(false);
  });

  it("encodes enums with and without payloads", () => {
    expect(codec.voteChoice.enc(fam(3))).toEqual({ family: { _0: { rawValue: 3 } } });
    expect(codec.voteChoice.enc({ case: "skip" })).toEqual({ skip: {} });
    expect(codec.phase.enc({ case: "voting", until: 5, isFinal: true })).toEqual({ voting: { until: 5, isFinal: true } });
    expect(codec.gameEventKind.enc({ case: "familyKilled", _0: 2, by: undefined })).toEqual({ familyKilled: { _0: { rawValue: 2 } } });
    expect(codec.serverMessage.enc({ case: "map", _0: undefined })).toEqual({ map: {} });
  });

  it("accepts null for optional values and normalises uuids", () => {
    const decoded = codec.serverMessage.dec({ map: { _0: null } });
    expect(decoded).toEqual({ case: "map", _0: undefined });
    const probe = codec.serverMessage.dec({ probe: { _0: "6f1c2b4a-0d3e-4f55-9a11-2b7c8d9e0f10" } });
    expect(probe).toEqual({ case: "probe", _0: "6F1C2B4A-0D3E-4F55-9A11-2B7C8D9E0F10" });
  });

  it("rejects malformed input", () => {
    expect(() => codec.clientMessage.dec({ nope: {} })).toThrow(DecodeError);
    expect(() => codec.clientMessage.dec({ kill: { victim: 3 } })).toThrow(DecodeError);
    expect(() => codec.clientMessage.dec({ sync: {}, leave: {} })).toThrow(DecodeError);
    expect(() => codec.adminCommand.dec({ extendMeeting: {} })).toThrow(DecodeError);
    expect(() => codec.gameCommand.dec({ adjustTimer: { _0: "bad", seconds: 1 } })).toThrow(DecodeError);
  });

  it("round-trips a full host state with a running engine", () => {
    const f = new Fixture();
    f.apply({ case: "startMeeting" }, 100);
    const state = freshHostState("4242");
    state.engine = f.engine;
    const once = JSON.parse(JSON.stringify(codec.hostState.enc(state)));
    const twice = JSON.parse(JSON.stringify(codec.hostState.enc(codec.hostState.dec(once))));
    expect(twice).toEqual(once);
  });
});
