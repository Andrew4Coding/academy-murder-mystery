import { afterEach, beforeEach, describe, expect, it } from "vitest";
import WebSocket from "ws";
import * as codec from "../src/codec/schemas.js";
import { CloudServer } from "../src/server/server.js";
import { serializeSnapshot } from "../src/server/snapshot.js";
import { SeededGenerator } from "../src/engine/rng.js";
import { hello, lobbyWithPlayers } from "./harness.js";

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 9, 8, 7]);

class WsClient {
  inbox: codec.ServerMessage[] = [];
  private waiters: (() => void)[] = [];
  closed = false;

  private constructor(private ws: WebSocket) {
    ws.on("message", (raw) => {
      this.inbox.push(codec.serverMessage.dec(JSON.parse(raw.toString())));
      this.waiters.splice(0).forEach((w) => w());
    });
    ws.on("close", () => {
      this.closed = true;
      this.waiters.splice(0).forEach((w) => w());
    });
  }

  static async connect(port: number, headers: Record<string, string> = {}) {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/ws`, { headers });
    await new Promise<void>((resolve, reject) => {
      ws.once("open", () => resolve());
      ws.once("error", reject);
    });
    return new WsClient(ws);
  }

  send(message: codec.ClientMessage) {
    this.ws.send(JSON.stringify(codec.clientMessage.enc(message)));
  }

  sendRaw(text: string) {
    this.ws.send(text);
  }

  async waitFor<T>(find: (inbox: codec.ServerMessage[]) => T | undefined, timeout = 3000): Promise<T> {
    const deadline = Date.now() + timeout;
    for (;;) {
      const found = find(this.inbox);
      if (found !== undefined) return found;
      if (Date.now() > deadline) throw new Error(`timeout; inbox: ${this.inbox.map((m) => m.case).join(",")}`);
      await new Promise<void>((resolve) => {
        this.waiters.push(resolve);
        setTimeout(resolve, 50);
      });
    }
  }

  last<K extends codec.ServerMessage["case"]>(kind: K) {
    return [...this.inbox].reverse().find((m) => m.case === kind) as Extract<codec.ServerMessage, { case: K }> | undefined;
  }

  close() {
    this.ws.close();
  }
}

let server: CloudServer;
let port: number;
const base = () => `http://127.0.0.1:${port}`;
const secret = { "X-Moonfall-Secret": "s3cret" };

async function http(method: string, path: string, body?: unknown, headers: Record<string, string> = {}) {
  const res = await fetch(base() + path, {
    method,
    headers: { "Content-Type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body)
  });
  const text = await res.text();
  let json: any;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { status: res.status, json, headers: res.headers };
}

beforeEach(async () => {
  server = new CloudServer({
    dbPath: ":memory:",
    trustProxy: true,
    pairingSecret: "s3cret",
    bootstrapPin: "0000",
    rng: new SeededGenerator(11),
    tickMs: 50
  });
  port = await server.start(0, "127.0.0.1");
});

afterEach(async () => {
  await server.stop();
});

function macSnapshot() {
  const { host, players, admin } = lobbyWithPlayers(4);
  players[0]!.send({ case: "selfie", _0: JPEG });
  admin.admin({ case: "setBoothMap", _0: JPEG });
  admin.admin({ case: "startGame" });
  return { body: serializeSnapshot(host.exportSnapshot()), host, players };
}

describe("registry", () => {
  it("serves the registry and health without auth, defaulting to local", async () => {
    expect((await http("GET", "/health")).json).toEqual({ ok: true });
    const registry = (await http("GET", "/registry")).json;
    expect(registry).toEqual({ mode: "local", updatedAt: 0, hasSnapshot: false, snapshotAt: null });
  });

  it("accepts writes only with the OC PIN or the pairing secret (AC8)", async () => {
    expect((await http("PUT", "/registry", { mode: "cloud" })).status).toBe(401);
    expect((await http("PUT", "/registry", { mode: "cloud" }, { "X-Moonfall-Pin": "1111" })).status).toBe(401);
    expect((await http("PUT", "/registry", { mode: "bogus" }, secret)).status).toBe(400);
    const viaPin = await http("PUT", "/registry", { mode: "cloud" }, { "X-Moonfall-Pin": "0000" });
    expect(viaPin.status).toBe(200);
    expect(viaPin.json.mode).toBe("cloud");
    expect(viaPin.json.updatedAt).toBeGreaterThan(1_700_000_000);
    const viaSecret = await http("PUT", "/registry", { mode: "local" }, secret);
    expect(viaSecret.json.mode).toBe("local");
  });

  it("locks an IP out of HTTP auth after repeated failures", async () => {
    const headers = { "X-Forwarded-For": "9.9.9.9, 1.1.1.1", "X-Moonfall-Pin": "bad" };
    for (let i = 0; i < 5; i++) expect((await http("PUT", "/registry", { mode: "cloud" }, headers)).status).toBe(401);
    const locked = await http("PUT", "/registry", { mode: "cloud" }, { ...headers, "X-Moonfall-Pin": "0000" });
    expect(locked.status).toBe(429);
    expect(Number(locked.headers.get("retry-after"))).toBeGreaterThan(0);
    const other = await http("PUT", "/registry", { mode: "cloud" }, { "X-Forwarded-For": "8.8.8.8", "X-Moonfall-Pin": "0000" });
    expect(other.status).toBe(200);
  });
});

describe("snapshots and takeover", () => {
  it("stores a cold snapshot without acting on it", async () => {
    const { body, host } = macSnapshot();
    expect((await http("PUT", "/snapshot", body)).status).toBe(401);
    expect((await http("PUT", "/snapshot", { state: {} }, secret)).status).toBe(400);
    const put = await http("PUT", "/snapshot", body, secret);
    expect(put.status).toBe(200);
    const registry = (await http("GET", "/registry")).json;
    expect(registry.hasSnapshot).toBe(true);
    expect(registry.mode).toBe("local");
    expect(server.host.state.engine).toBeUndefined();
    const got = await http("GET", "/snapshot", undefined, secret);
    expect(got.json.state.ocPin).toBe(host.state.ocPin);
    expect(got.json.selfies).toHaveLength(1);
    expect(got.json.map.jpeg).toBe(JPEG.toString("base64"));
  });

  it("switches the registry PIN to the snapshot's OC PIN once one exists", async () => {
    const { body } = macSnapshot();
    await http("PUT", "/snapshot", body, secret);
    expect((await http("PUT", "/registry", { mode: "cloud" }, { "X-Moonfall-Pin": "0000" })).status).toBe(401);
    expect((await http("PUT", "/registry", { mode: "cloud" }, { "X-Moonfall-Pin": "4242" })).status).toBe(200);
  });

  it("serves an accessible take-over page", async () => {
    const page = await http("GET", "/takeover");
    expect(page.status).toBe(200);
    expect(page.json).toContain('<label for="pin">');
    expect(page.json).toContain('aria-live="polite"');
  });

  it("activates the latest snapshot on take-over and lets phones resume (AC4, AC6)", async () => {
    const { body, players } = macSnapshot();
    expect((await http("POST", "/takeover", { pin: "0000" })).status).toBe(404);
    await http("PUT", "/snapshot", body, secret);
    expect((await http("POST", "/takeover", { pin: "0000" })).status).toBe(401);
    expect((await http("POST", "/takeover", { pin: "4242" })).json).toEqual({ ok: true });
    expect((await http("GET", "/registry")).json.mode).toBe("cloud");

    const phone = await WsClient.connect(port);
    phone.send({ case: "hello", _0: hello({ resume: players[1]!.resumeID() }) });
    const view = await phone.waitFor((m) => m.find((x) => x.case === "state"));
    expect(view.case === "state" && view._0.game?.family).toBe(2);
    expect(phone.last("selfies")!._0).toHaveLength(1);
    expect(phone.last("map")!._0!.jpeg).toEqual(JPEG);
    phone.close();
  });

  it("does not overwrite a live game when take-over is repeated", async () => {
    const { body } = macSnapshot();
    await http("PUT", "/snapshot", body, secret);
    await http("POST", "/takeover", { pin: "4242" });
    server.host.state.settings.discussionDuration = 77;
    const again = await http("POST", "/takeover", { pin: "4242" });
    expect(again.json.alreadyActive).toBe(true);
    expect(server.host.state.settings.discussionDuration).toBe(77);
  });

  it("imports a planned switch and exports it back", async () => {
    const { body } = macSnapshot();
    expect((await http("PUT", "/import", body)).status).toBe(401);
    expect((await http("PUT", "/import", body, secret)).json).toEqual({ ok: true });
    expect((await http("GET", "/registry")).json.mode).toBe("cloud");
    const exported = await http("GET", "/export", undefined, secret);
    expect(exported.json).toEqual(JSON.parse(JSON.stringify(body)));
  });

  it("disconnects every socket when the registry flips to local", async () => {
    await http("PUT", "/registry", { mode: "cloud" }, secret);
    const phone = await WsClient.connect(port);
    phone.send({ case: "hello", _0: hello({ familyCode: server.host.state.gameCode! }, "Sam") });
    await phone.waitFor((m) => m.find((x) => x.case === "welcome"));
    await http("PUT", "/registry", { mode: "local" }, secret);
    await phone.waitFor(() => (phone.closed ? true : undefined));
  });
});

describe("websocket host", () => {
  it("rejects game credentials while the registry says local (AC6)", async () => {
    const phone = await WsClient.connect(port);
    phone.send({ case: "hello", _0: hello({ familyCode: server.host.state.gameCode! }, "Sam") });
    const rejected = await phone.waitFor((m) => m.find((x) => x.case === "rejected"));
    expect(rejected.case === "rejected" && rejected._0).toMatch(/hosted elsewhere/);
    phone.close();
  });

  it("answers garbage frames with a rejection and keeps the socket open", async () => {
    await http("PUT", "/registry", { mode: "cloud" }, secret);
    const phone = await WsClient.connect(port);
    phone.sendRaw("not json");
    phone.sendRaw(JSON.stringify({ nope: {} }));
    await phone.waitFor((m) => (m.length >= 2 ? true : undefined));
    expect(phone.last("rejected")!._0).toBe("Something went wrong.");
    phone.send({ case: "sync" });
    await phone.waitFor((m) => (m.length >= 3 ? true : undefined));
    expect(phone.last("rejected")!._0).toBe("Join a family or enter the OC PIN first.");
    phone.close();
  });

  it("drives a lobby to a running game with ws clients and streams the display (AC3, AC8)", async () => {
    await http("PUT", "/registry", { mode: "cloud" }, secret);
    const code = server.host.state.gameCode!;
    const phones: WsClient[] = [];
    for (let i = 1; i <= 4; i++) {
      const phone = await WsClient.connect(port);
      phone.send({ case: "hello", _0: hello({ familyCode: code }, `Player ${i}`) });
      await phone.waitFor((m) => m.find((x) => x.case === "state"));
      expect(phone.inbox.slice(0, 3).map((m) => m.case)).toEqual(["welcome", "selfies", "state"]);
      phones.push(phone);
    }
    phones[0]!.send({ case: "selfie", _0: JPEG });
    await phones[3]!.waitFor((m) => {
      const s = [...m].reverse().find((x) => x.case === "selfies");
      return s && s.case === "selfies" && s._0.length === 1 ? true : undefined;
    });

    const admin = await WsClient.connect(port);
    admin.send({ case: "hello", _0: { ...hello({ ocPin: "0000" }), station: { case: "admin" } } });
    const display = await admin.waitFor((m) => m.find((x) => x.case === "display"));
    expect(display.case === "display" && display._0.screen.case).toBe("waiting");
    expect(display.case === "display" && display._0.lobbyFamilies).toHaveLength(4);

    admin.send({ case: "admin", _0: { case: "startGame" } });
    await admin.waitFor((m) => m.find((x) => x.case === "display" && x._0.screen.case === "starting"));
    for (const phone of phones) {
      const view = await phone.waitFor((m) => {
        const s = [...m].reverse().find((x) => x.case === "state");
        return s && s.case === "state" && s._0.game ? s._0 : undefined;
      });
      expect(["villager", "werewolf"]).toContain(view.game!.role);
    }
    const adminState = await admin.waitFor((m) => {
      const s = [...m].reverse().find((x) => x.case === "state");
      return s && s.case === "state" && s._0.admin && !s._0.admin.isLobby ? s._0.admin : undefined;
    });
    expect(adminState.families.filter((f) => f.role === "werewolf")).toHaveLength(1);
    expect(phones.every((p) => !p.inbox.some((m) => m.case === "display"))).toBe(true);

    phones.forEach((p) => p.close());
    admin.close();
  });
});
