import { createHash } from "node:crypto";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import * as codec from "../src/codec/schemas.js";
import { Db } from "../src/store/db.js";
import { defaultBooths } from "../src/host/booth-defaults.js";
import { parseSnapshot, serializeSnapshot } from "../src/server/snapshot.js";
import { FakeClient, hello, lobbyWithPlayers, makeHost } from "./harness.js";

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);

describe("hello flow", () => {
  it("answers a family code hello with welcome, selfies and state", () => {
    const { host } = makeHost();
    const client = new FakeClient(host);
    client.join(host.state.gameCode!, "  Sam ");
    expect(client.cases()).toEqual(["welcome", "selfies", "booths", "state"]);
    const view = client.lastView()!;
    expect(view.identity.case).toBe("player");
    expect(view.lobby?.playerName).toBe("Sam");
    expect(view.game).toBeUndefined();
    expect(client.last("welcome")!._0.resumeID).toBe(view.lobby!.playerID);
    expect(host.state.families.size).toBe(1);
  });

  it("sends the map only when the hash differs", () => {
    const { host } = makeHost();
    const admin = new FakeClient(host);
    admin.oc("4242");
    admin.admin({ case: "setBoothMap", _0: JPEG });
    const hash = host.boothMap!.hash;
    expect(hash).toMatch(/^[0-9a-f]{64}$/);

    const stale = new FakeClient(host);
    stale.send({ case: "hello", _0: hello({ familyCode: host.state.gameCode! }, "A", "old") });
    expect(stale.cases()).toEqual(["welcome", "selfies", "map", "booths", "state"]);

    const fresh = new FakeClient(host);
    fresh.send({ case: "hello", _0: hello({ familyCode: host.state.gameCode! }, "B", hash, host.boothCatalog.revision) });
    expect(fresh.cases()).toEqual(["welcome", "selfies", "state"]);
  });

  it("rejects bad codes, versions and missing names without signing in", () => {
    const { host } = makeHost();
    const client = new FakeClient(host);
    client.join("ZZZZZZ", "Sam");
    expect(client.lastRejected()).toBe("That code isn't valid. Check it and try again.");
    client.send({ case: "hello", _0: { ...hello({ familyCode: host.state.gameCode! }, "Sam"), version: 1 } });
    expect(client.lastRejected()).toBe("This app version is too old or too new for the host. Update the app.");
    client.send({ case: "hello", _0: hello({ familyCode: host.state.gameCode! }) });
    expect(client.lastRejected()).toBe("Enter your name to join.");
    client.join(host.state.gameCode!, "x".repeat(25));
    expect(client.lastRejected()).toBe("Family names need 1 to 24 characters.");
    expect(host.state.families.size).toBe(0);
    client.send({ case: "sync" });
    expect(client.lastRejected()).toBe("Join a family or enter the OC PIN first.");
  });

  it("requires a station with the OC PIN", () => {
    const { host } = makeHost();
    const client = new FakeClient(host);
    client.send({ case: "hello", _0: hello({ ocPin: "4242" }) });
    expect(client.lastRejected()).toBe("That code isn't valid. Check it and try again.");
  });

  it("resumes with the same identity and evicts the older session", () => {
    const { host } = makeHost();
    const first = new FakeClient(host);
    first.join(host.state.gameCode!, "Sam");
    const resume = first.resumeID();
    const second = new FakeClient(host);
    second.send({ case: "hello", _0: hello({ resume }) });
    expect(second.resumeID()).toBe(resume);
    expect(first.closed).toBe(true);
    expect(host.sessions.has(first.id)).toBe(false);

    const stranger = new FakeClient(host);
    stranger.send({ case: "hello", _0: hello({ resume: "00000000-0000-4000-8000-000000000000" }) });
    expect(stranger.lastRejected()).toBe("This device isn't registered with the host any more.");
  });

  it("gives every joiner their own family and refuses joins after the start", () => {
    const { host, players, admin } = lobbyWithPlayers(4);
    expect([...host.state.families.keys()]).toEqual([1, 2, 3, 4]);
    admin.admin({ case: "startGame" });
    expect(host.state.engine).toBeDefined();
    const late = new FakeClient(host);
    late.join(host.state.gameCode!, "Late");
    expect(late.lastRejected()).toBe("The game has already started.");
    expect(players).toHaveLength(4);
  });
});

describe("lockouts", () => {
  it("locks a connection after five bad credentials", () => {
    const { host, clock } = makeHost();
    const client = new FakeClient(host);
    for (let i = 0; i < 5; i++) client.join("BAD", "Sam");
    client.join(host.state.gameCode!, "Sam");
    expect(client.lastRejected()).toBe("Too many attempts. Wait a moment and try again.");
    clock.advance(31);
    const other = new FakeClient(host, "10.9.9.9");
    other.join(host.state.gameCode!, "Sam");
    expect(other.last("welcome")).toBeDefined();
  });

  it("locks an IP across connections with escalating delay", () => {
    const { host, clock, ipLimiter } = makeHost();
    const attempt = () => {
      const c = new FakeClient(host, "1.2.3.4");
      c.join("BAD", "Sam");
      return c;
    };
    for (let i = 0; i < 5; i++) attempt();
    expect(ipLimiter.retryAfter("1.2.3.4")).toBe(30);
    const blocked = new FakeClient(host, "1.2.3.4");
    blocked.join(host.state.gameCode!, "Sam");
    expect(blocked.lastRejected()).toBe("Too many attempts. Wait a moment and try again.");
    clock.advance(31);
    for (let i = 0; i < 5; i++) attempt();
    expect(ipLimiter.retryAfter("1.2.3.4")).toBe(60);
    clock.advance(61);
    for (let i = 0; i < 5; i++) attempt();
    expect(ipLimiter.retryAfter("1.2.3.4")).toBe(120);
    for (let round = 0; round < 6; round++) {
      clock.advance(1000);
      for (let i = 0; i < 5; i++) attempt();
    }
    expect(ipLimiter.retryAfter("1.2.3.4")).toBe(900);
    const innocent = new FakeClient(host, "5.6.7.8");
    innocent.join(host.state.gameCode!, "Sam");
    expect(innocent.last("welcome")).toBeDefined();
  });

  it("does not count unknown resume ids as failures", () => {
    const { host, ipLimiter } = makeHost();
    for (let i = 0; i < 8; i++) {
      const c = new FakeClient(host, "7.7.7.7");
      c.send({ case: "hello", _0: hello({ resume: "00000000-0000-4000-8000-000000000000" }) });
    }
    expect(ipLimiter.isLocked("7.7.7.7")).toBe(false);
  });
});

describe("registry gating", () => {
  it("rejects every hello when the cloud is not the active host", () => {
    let active = false;
    const { host } = makeHost({ active: () => active });
    const client = new FakeClient(host);
    client.join(host.state.gameCode!, "Sam");
    expect(client.lastRejected()).toBe("The game is hosted elsewhere right now. Reconnect to the active host.");
    client.oc("4242");
    expect(client.last("welcome")).toBeUndefined();
    active = true;
    client.join(host.state.gameCode!, "Sam");
    expect(client.last("welcome")).toBeDefined();
  });
});

describe("selfies", () => {
  it("stores selfies in the lobby and fans them out", () => {
    const { host, players } = lobbyWithPlayers(3);
    players[0]!.send({ case: "selfie", _0: JPEG });
    expect(host.selfies.size).toBe(1);
    for (const p of players) expect(p.last("selfies")!._0).toHaveLength(1);
  });

  it("rejects photos over 150000 bytes", () => {
    const { host, players } = lobbyWithPlayers(3);
    players[0]!.send({ case: "selfie", _0: Buffer.alloc(150_001) });
    expect(players[0]!.lastRejected()).toBe("That photo is too large.");
    players[0]!.send({ case: "selfie", _0: Buffer.alloc(150_000) });
    expect(host.selfies.size).toBe(1);
  });

  it("rejects selfies after the game started and from non-players", () => {
    const { host, players, admin } = lobbyWithPlayers(4);
    admin.send({ case: "selfie", _0: JPEG });
    expect(admin.lastRejected()).toBe("Only players can do that.");
    admin.admin({ case: "startGame" });
    players[0]!.send({ case: "selfie", _0: JPEG });
    expect(players[0]!.lastRejected()).toBe("The game has already started.");
    expect(host.selfies.size).toBe(0);
  });
});

describe("admin role gating", () => {
  it("only an OC device on the admin station may send admin commands", () => {
    const { host, players } = lobbyWithPlayers(3);
    players[0]!.admin({ case: "startGame" });
    expect(players[0]!.lastRejected()).toBe("Only organisers can do that.");
    const town = new FakeClient(host);
    town.oc("4242", { case: "townHall" });
    town.admin({ case: "regenerateOCPIN" });
    expect(town.lastRejected()).toBe("Only organisers can do that.");
    expect(host.state.ocPin).toBe("4242");
    const admin = new FakeClient(host);
    admin.oc("4242");
    admin.admin({ case: "regenerateOCPIN" });
    expect(host.state.ocPin).not.toBe("4242");
  });

  it("rejects commands that the engine refuses, with the Swift messages", () => {
    const { admin } = lobbyWithPlayers(2);
    admin.admin({ case: "startMeeting" });
    expect(admin.lastRejected()).toBe("That isn't allowed right now.");
    admin.admin({ case: "startGame" });
    expect(admin.lastRejected()).toBe("Create at least 3 families.");
  });
});

describe("game flow and views", () => {
  function started() {
    const ctx = lobbyWithPlayers(5);
    ctx.admin.admin({ case: "updateSettings", werewolfCount: 2, settings: ctx.host.state.settings });
    ctx.admin.admin({ case: "startGame" });
    return ctx;
  }

  it("starts the engine ten seconds in the future", () => {
    const { host, clock } = started();
    expect(host.state.engine!.state.startedAt).toBe(clock.t + 10);
  });

  it("shows roles and allies only to the right viewers", () => {
    const { host, players, admin } = started();
    const wolves = [...host.state.engine!.state.families.values()].filter((f) => f.role === "werewolf").map((f) => f.id);
    expect(wolves).toHaveLength(2);
    for (const p of players) {
      const game = p.lastView()!.game!;
      const family = game.family;
      if (wolves.includes(family)) {
        expect(game.role).toBe("werewolf");
        expect(game.allies!.map((a) => a.id)).toEqual(wolves.filter((w) => w !== family));
        expect(game.killReadyAt).toBeDefined();
        expect(game.sabotageReadyAt).toBeDefined();
      } else {
        expect(game.role).toBe("villager");
        expect(game.allies).toBeUndefined();
        expect(game.killReadyAt).toBeUndefined();
      }
      expect(game.bleToken).toHaveLength(6);
    }
    const adminView = admin.lastView()!.admin!;
    expect(adminView.families.filter((r) => r.role === "werewolf")).toHaveLength(2);
    expect(adminView.isLobby).toBe(false);
  });

  it("runs a meeting through votes with timers driven by tick", () => {
    const { host, players, admin, clock } = started();
    clock.advance(11);
    host.tick();
    admin.admin({ case: "startMeeting" });
    expect(admin.lastView()!.admin!.phase.case).toBe("discussion");
    clock.advance(121);
    host.tick();
    expect(admin.lastView()!.admin!.phase.case).toBe("voting");
    players[0]!.send({ case: "vote", _0: { case: "skip" } });
    expect(players[0]!.lastView()!.game!.myVote).toEqual({ case: "skip" });
    expect(players[0]!.lastView()!.game!.votesCast).toBe(1);
    players[1]!.send({ case: "vote", _0: { case: "family", _0: 99 } });
    expect(players[1]!.lastRejected()).toBe("Unknown family.");
    clock.advance(121);
    host.tick();
    expect(host.state.engine!.state.phase.case).toBe("running");
  });

  it("only allows a kill after a sighting and a body report with a sighting", () => {
    const { host, players, clock } = started();
    clock.advance(11);
    const wolfClient = players.find((p) => p.lastView()!.game!.role === "werewolf")!;
    const victimClient = players.find((p) => p.lastView()!.game!.role === "villager")!;
    const victim = victimClient.lastView()!.game!.family;
    wolfClient.send({ case: "kill", victim });
    expect(wolfClient.lastRejected()).toBe("That family isn't close enough.");
    const token = victimClient.lastView()!.game!.bleToken;
    wolfClient.send({ case: "sightings", _0: [{ token, rssi: -90 }] });
    wolfClient.send({ case: "kill", victim });
    expect(wolfClient.lastRejected()).toBe("That family isn't close enough.");
    wolfClient.send({ case: "sightings", _0: [{ token, rssi: -50 }] });
    expect(wolfClient.lastView()!.game!.nearby.map((s) => s.id)).toEqual([victim]);
    wolfClient.send({ case: "kill", victim });
    expect(host.state.engine!.state.families.get(victim)!.life).toBe("killed");
    expect(victimClient.lastView()!.game!.life).toBe("killed");
    expect(victimClient.lastView()!.game!.bodyActive).toBe(true);
  });

  it("answers probes and reports device connectivity", () => {
    const { host, players, admin, clock } = lobbyWithPlayers(3);
    admin.admin({ case: "checkConnectivity" });
    const probe = players[0]!.last("probe")!._0;
    players[0]!.send({ case: "probeReply", _0: probe });
    clock.advance(4);
    const devices = host.view({ case: "oc", _0: admin.resumeID() })!.admin!.devices;
    const states = Object.fromEntries(devices.map((d) => [d.label, d.connection]));
    expect(states["Player 1"]).toBe("online");
    expect(states["Player 2"]).toBe("unreachable");
  });

  it("new game resets players and keeps OC devices", () => {
    const { host, players, admin } = lobbyWithPlayers(3);
    players[0]!.send({ case: "selfie", _0: JPEG });
    const oldCode = host.state.gameCode;
    admin.admin({ case: "newGame" });
    expect(players[0]!.cases()).toContain("reset");
    expect(host.state.players.size).toBe(0);
    expect(host.state.ocDevices.size).toBe(1);
    expect(host.selfies.size).toBe(0);
    expect(host.state.gameCode).not.toBe(oldCode);
    players[0]!.send({ case: "sync" });
    expect(players[0]!.lastRejected()).toBe("Join a family or enter the OC PIN first.");
  });

  it("leave removes the player and family in the lobby", () => {
    const { host, players } = lobbyWithPlayers(3);
    players[2]!.send({ case: "leave" });
    expect(players[2]!.cases()).toContain("reset");
    expect(host.state.families.has(3)).toBe(false);
  });

  it("renames families in the lobby only", () => {
    const { host, players, admin } = lobbyWithPlayers(4);
    players[0]!.send({ case: "renameFamily", _0: "Foxes" });
    expect(host.state.families.get(1)!.name).toBe("Foxes");
    expect(players[0]!.lastView()!.familyName).toBe("Foxes");
    admin.admin({ case: "startGame" });
    players[0]!.send({ case: "renameFamily", _0: "Owls" });
    expect(players[0]!.lastRejected()).toBe("The game has already started.");
  });
});

describe("public display stream", () => {
  it("streams display state to admin stations only and follows the game", () => {
    const { host, players, admin, clock } = lobbyWithPlayers(5);
    const displays = () => admin.inbox.filter((m) => m.case === "display") as { case: "display"; _0: codec.PublicDisplayState }[];
    expect(displays().at(-1)!._0.screen.case).toBe("waiting");
    expect(displays().at(-1)!._0.lobbyFamilies).toHaveLength(5);
    for (const p of players) expect(p.cases()).not.toContain("display");

    admin.admin({ case: "startGame" });
    expect(displays().at(-1)!._0.screen).toEqual({ case: "starting", at: clock.t + 10 });
    const count = displays().length;
    host.tick();
    expect(displays().length).toBe(count);
    clock.advance(11);
    host.tick();
    expect(displays().at(-1)!._0.screen.case).toBe("playing");
    expect(displays().at(-1)!._0.familiesRemaining).toBe(5);
  });

  it("includes the selfie in the lobby display and the reveal after a werewolf win", () => {
    const { host, players, admin, clock } = lobbyWithPlayers(3);
    players[0]!.send({ case: "selfie", _0: JPEG });
    const lastDisplay = () => (admin.last("display") as { _0: codec.PublicDisplayState }) ._0;
    expect(lastDisplay().lobbyFamilies[0]!.selfie).toEqual(JPEG);
    admin.admin({ case: "startGame" });
    clock.advance(11);
    host.tick();
    admin.admin({ case: "endGame", _0: "werewolves" });
    expect(lastDisplay().screen).toEqual({ case: "ended", _0: { winner: "werewolves", reason: "ocEnded" } });
    expect(lastDisplay().reveal).toHaveLength(3);
    expect(lastDisplay().reveal.filter((r) => r.isWerewolf)).toHaveLength(1);
  });
});

describe("booth map", () => {
  it("validates, hashes with sha256 and pushes to clients", () => {
    const { host, players, admin } = lobbyWithPlayers(3);
    admin.admin({ case: "setBoothMap", _0: Buffer.from("not an image") });
    expect(admin.lastRejected()).toBe("That file isn't an image the map can use.");
    admin.admin({ case: "setBoothMap", _0: Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), Buffer.alloc(8 * 1024 * 1024)]) });
    expect(admin.lastRejected()).toBe("That file isn't an image the map can use.");
    admin.admin({ case: "setBoothMap", _0: JPEG });
    const map = players[0]!.last("map")!._0!;
    expect(map.jpeg).toEqual(JPEG);
    expect(map.hash).toBe(createHash("sha256").update(JPEG).digest("hex"));
    admin.admin({ case: "removeBoothMap" });
    expect(players[0]!.last("map")!._0).toBeUndefined();
    expect(host.boothMap).toBeUndefined();
  });
});

describe("persistence", () => {
  it("restores state, selfies, map and events after a restart", () => {
    const path = join(mkdtempSync(join(tmpdir(), "moonfall-")), "db.sqlite");
    const first = lobbyWithPlayers(4, makeHost({ dbPath: path }));
    first.players[0]!.send({ case: "selfie", _0: JPEG });
    first.admin.admin({ case: "setBoothMap", _0: JPEG });
    first.admin.admin({ case: "startGame" });
    const gameID = first.host.gameID;
    const code = first.host.state.gameCode;
    const roles = [...first.host.state.engine!.state.families.values()].map((f) => [f.id, f.role]);
    const resume = first.players[1]!.resumeID();
    first.db.close();

    const second = makeHost({ dbPath: path });
    expect(second.host.gameID).toBe(gameID);
    expect(second.host.state.gameCode).toBe(code);
    expect([...second.host.state.engine!.state.families.values()].map((f) => [f.id, f.role])).toEqual(roles);
    expect(second.host.selfies.size).toBe(1);
    expect(second.host.selfies.get(first.players[0]!.resumeID())).toEqual(JPEG);
    expect(second.host.boothMap!.hash).toBe(first.host.boothMap!.hash);
    expect(second.host.recentEvents.map((e) => e.kind.case)).toEqual(["gameStarted"]);

    const back = new FakeClient(second.host);
    back.send({ case: "hello", _0: hello({ resume }) });
    expect(back.lastView()!.game!.family).toBe(2);
  });

  it("starts fresh with the bootstrap PIN", () => {
    const { host } = makeHost({ db: new Db(":memory:"), bootstrapPin: "9876" });
    expect(host.state.ocPin).toBe("9876");
    expect(host.state.gameCode).toMatch(/^[A-HJ-NP-Z2-9]{6}$/);
  });
});

describe("booth catalog", () => {
  const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.from([1, 2, 3])]);
  const blank = (id: string, title: string): codec.Booth => ({
    id, title, location: "", capacity: "", duration: "", task: "", steps: [], stampRequirement: "", staffNotes: [], image: undefined
  });
  const titles = (host: { boothCatalog: codec.BoothCatalog }) => host.boothCatalog.booths.map((b) => b.title);
  const NEW_ID = "0A1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D";

  it("seeds a fresh host with the four guide booths", () => {
    const { host } = makeHost();
    expect(titles(host)).toEqual(["Tarot Reading", "Pumpkin Pipe Cleaner Challenge", "Copy the Artist", "Movie"]);
    expect(host.boothCatalog.booths.every((b) => b.steps.length > 0 && b.task !== "")).toBe(true);
    expect(host.boothCatalog.booths.map((b) => b.id)).toEqual(defaultBooths().map((b) => b.id));
  });

  it("persists edits across a new game and a restart", () => {
    const path = join(mkdtempSync(join(tmpdir(), "moonfall-")), "db.sqlite");
    const first = lobbyWithPlayers(3, makeHost({ dbPath: path }));
    const { host, admin } = first;
    admin.admin({ case: "saveBooth", _0: { ...host.boothCatalog.booths[0]!, title: "Tarot" } });
    admin.admin({ case: "saveBooth", _0: blank(NEW_ID, "Extra") });
    admin.admin({ case: "deleteBooth", _0: host.boothCatalog.booths[1]!.id });
    admin.admin({ case: "reorderBooths", _0: host.boothCatalog.booths.map((b) => b.id).reverse() });
    admin.admin({ case: "newGame" });
    expect(admin.lastRejected()).toBeUndefined();
    first.db.close();

    const second = makeHost({ dbPath: path });
    expect(second.host.boothCatalog).toEqual(host.boothCatalog);
    expect(titles(second.host)[0]).toBe("Extra");
    expect(titles(second.host)).toContain("Tarot");
    expect(second.host.boothCatalog.booths).toHaveLength(4);
  });

  it("keeps the stored image on save and ignores a client-supplied one", () => {
    const { host, admin } = lobbyWithPlayers(3);
    const id = host.boothCatalog.booths[0]!.id;
    admin.admin({ case: "setBoothImage", _0: id, _1: PNG });
    const image = host.boothCatalog.booths[0]!.image!;
    expect(image.jpeg).toEqual(PNG);
    expect(image.hash).toBe(createHash("sha256").update(PNG).digest("hex"));

    admin.admin({ case: "saveBooth", _0: { ...host.boothCatalog.booths[0]!, image: undefined, task: "New task" } });
    expect(host.boothCatalog.booths[0]!.image).toEqual(image);
    expect(host.boothCatalog.booths[0]!.task).toBe("New task");

    admin.admin({ case: "saveBooth", _0: { ...blank(NEW_ID, "Extra"), image } });
    expect(host.boothCatalog.booths.at(-1)!.image).toBeUndefined();

    admin.admin({ case: "removeBoothImage", _0: id });
    expect(host.boothCatalog.booths[0]!.image).toBeUndefined();
  });

  it("rejects non-images and unknown booths", () => {
    const { host, admin } = lobbyWithPlayers(3);
    const id = host.boothCatalog.booths[0]!.id;
    admin.admin({ case: "setBoothImage", _0: id, _1: Buffer.from("nope") });
    expect(admin.lastRejected()).toBe("That file isn't an image the map can use.");
    admin.admin({ case: "setBoothImage", _0: id, _1: Buffer.concat([PNG, Buffer.alloc(8 * 1024 * 1024)]) });
    expect(admin.lastRejected()).toBe("That file isn't an image the map can use.");
    const revision = host.boothCatalog.revision;
    admin.admin({ case: "deleteBooth", _0: NEW_ID });
    expect(admin.lastRejected()).toBe("That booth no longer exists.");
    admin.admin({ case: "removeBoothImage", _0: NEW_ID });
    expect(admin.lastRejected()).toBe("That booth no longer exists.");
    admin.admin({ case: "setBoothImage", _0: NEW_ID, _1: PNG });
    expect(admin.lastRejected()).toBe("That booth no longer exists.");
    expect(host.boothCatalog.revision).toBe(revision);
  });

  it("reorders listed booths first and appends the rest in the old order", () => {
    const { host, admin } = lobbyWithPlayers(3);
    const [a, b, c, d] = host.boothCatalog.booths.map((x) => x.id);
    admin.admin({ case: "reorderBooths", _0: [c!, NEW_ID, a!] });
    expect(host.boothCatalog.booths.map((x) => x.id)).toEqual([c, a, b, d]);
  });

  it("restores the defaults and keeps images of booths with the same id", () => {
    const { host, admin } = lobbyWithPlayers(3);
    const id = host.boothCatalog.booths[0]!.id;
    admin.admin({ case: "setBoothImage", _0: id, _1: PNG });
    admin.admin({ case: "saveBooth", _0: blank(NEW_ID, "Extra") });
    admin.admin({ case: "saveBooth", _0: { ...host.boothCatalog.booths[0]!, title: "Changed" } });
    admin.admin({ case: "restoreBoothDefaults" });
    expect(titles(host)).toEqual(defaultBooths().map((b) => b.title));
    expect(host.boothCatalog.booths[0]!.image).toBeDefined();
    expect(host.boothCatalog.booths[1]!.image).toBeUndefined();
  });

  it("gives players no staff notes and the admin station full notes, on sign-in and on change", () => {
    const { host, players, admin } = lobbyWithPlayers(3);
    expect(host.boothCatalog.booths.some((b) => b.staffNotes.length > 0)).toBe(true);
    const fromPlayer = players[0]!.last("booths")!._0;
    expect(fromPlayer.booths).toHaveLength(4);
    expect(fromPlayer.booths.every((b) => b.staffNotes.length === 0)).toBe(true);
    expect(admin.last("booths")!._0.booths.some((b) => b.staffNotes.length > 0)).toBe(true);

    admin.admin({ case: "saveBooth", _0: { ...host.boothCatalog.booths[0]!, task: "Updated for everyone" } });
    const update = players[0]!.last("booths")!._0;
    expect(update.booths[0]!.task).toBe("Updated for everyone");
    expect(update.booths.every((b) => b.staffNotes.length === 0)).toBe(true);
    expect(update.revision).toBe(host.boothCatalog.revision);
    expect(admin.last("booths")!._0.booths[0]!.staffNotes).toEqual(host.boothCatalog.booths[0]!.staffNotes);
  });

  it("does not let non-admin stations or players edit booths", () => {
    const { host, players } = lobbyWithPlayers(3);
    const before = host.boothCatalog.revision;
    players[0]!.admin({ case: "restoreBoothDefaults" });
    expect(players[0]!.lastRejected()).toBe("Only organisers can do that.");
    const town = new FakeClient(host);
    town.oc(host.state.ocPin, { case: "townHall" });
    town.admin({ case: "deleteBooth", _0: host.boothCatalog.booths[0]!.id });
    expect(town.lastRejected()).toBe("Only organisers can do that.");
    expect(host.boothCatalog.revision).toBe(before);
  });

  it("skips the catalog when the hello carries the current revision", () => {
    const { host } = makeHost();
    const same = new FakeClient(host);
    same.send({ case: "hello", _0: hello({ familyCode: host.state.gameCode! }, "A", undefined, host.boothCatalog.revision) });
    expect(same.cases()).not.toContain("booths");
    const stale = new FakeClient(host);
    stale.send({ case: "hello", _0: hello({ familyCode: host.state.gameCode! }, "B", undefined, "old") });
    expect(stale.cases()).toContain("booths");
  });

  it("carries the catalog through snapshot export and import", () => {
    const { host, admin } = lobbyWithPlayers(3);
    admin.admin({ case: "setBoothImage", _0: host.boothCatalog.booths[0]!.id, _1: PNG });
    admin.admin({ case: "saveBooth", _0: blank(NEW_ID, "Extra") });
    const body = JSON.parse(JSON.stringify(serializeSnapshot(host.exportSnapshot())));
    expect(body.booths.revision).toBe(host.boothCatalog.revision);

    const target = makeHost();
    target.host.importSnapshot(parseSnapshot(body));
    expect(target.host.boothCatalog).toEqual(host.boothCatalog);

    const kept = target.host.boothCatalog;
    const legacy = { ...body };
    delete legacy.booths;
    target.host.importSnapshot(parseSnapshot(legacy));
    expect(target.host.boothCatalog).toEqual(kept);
  });
});
