import { randomUUID } from "node:crypto";
import * as codec from "../src/codec/schemas.js";
import type { ClientMessage, ServerMessage } from "../src/codec/schemas.js";
import { SeededGenerator } from "../src/engine/rng.js";
import { GameHost } from "../src/host/host.js";
import { IpLimiter } from "../src/host/ratelimit.js";
import { Db } from "../src/store/db.js";

export class ManualClock {
  constructor(public t = 1000) {}
  now = () => this.t;
  advance(seconds: number) {
    this.t += seconds;
  }
}

export class FakeClient {
  inbox: ServerMessage[] = [];
  closed = false;
  readonly id = randomUUID().toUpperCase();

  constructor(private host: GameHost, ip = "10.0.0.1") {
    host.connect(this.id, { send: (m) => this.inbox.push(m), close: () => (this.closed = true) }, ip);
  }

  send(message: ClientMessage) {
    this.host.receive(message, this.id);
  }

  cases(): string[] {
    return this.inbox.map((m) => m.case);
  }

  last<K extends ServerMessage["case"]>(kind: K): Extract<ServerMessage, { case: K }> | undefined {
    return [...this.inbox].reverse().find((m) => m.case === kind) as Extract<ServerMessage, { case: K }> | undefined;
  }

  lastRejected(): string | undefined {
    return this.last("rejected")?._0;
  }

  lastView() {
    return this.last("state")?._0;
  }

  resumeID(): string {
    return this.last("welcome")!._0.resumeID;
  }

  join(code: string, name: string) {
    this.send({ case: "hello", _0: hello({ familyCode: code }, name) });
  }

  oc(pin: string, station: codec.OCStation = { case: "admin" }) {
    this.send({ case: "hello", _0: { ...hello({ ocPin: pin }), station } });
  }

  admin(command: codec.AdminCommand) {
    this.send({ case: "admin", _0: command });
  }
}

export function hello(credential: { familyCode?: string; ocPin?: string; resume?: string }, name?: string, mapHash?: string): codec.Hello {
  const c: codec.Hello["credential"] = credential.familyCode !== undefined
    ? { case: "familyCode", _0: credential.familyCode }
    : credential.ocPin !== undefined
      ? { case: "ocPin", _0: credential.ocPin }
      : { case: "resume", _0: credential.resume! };
  return { version: 2, credential: c, name, station: undefined, mapHash };
}

export function makeHost(options: { dbPath?: string; clock?: ManualClock; active?: () => boolean; bootstrapPin?: string; db?: Db } = {}) {
  const clock = options.clock ?? new ManualClock();
  const db = options.db ?? new Db(options.dbPath ?? ":memory:");
  const ipLimiter = new IpLimiter(clock.now);
  const host = new GameHost({
    db, clock: clock.now, rng: new SeededGenerator(5), isActive: options.active, ipLimiter,
    bootstrapPin: options.bootstrapPin ?? "4242"
  });
  return { host, db, clock, ipLimiter };
}

export function lobbyWithPlayers(count: number, harness = makeHost()) {
  const { host } = harness;
  const players: FakeClient[] = [];
  for (let i = 1; i <= count; i++) {
    const client = new FakeClient(host);
    client.join(host.state.gameCode!, `Player ${i}`);
    players.push(client);
  }
  const admin = new FakeClient(host);
  admin.oc(host.state.ocPin);
  return { ...harness, players, admin };
}
