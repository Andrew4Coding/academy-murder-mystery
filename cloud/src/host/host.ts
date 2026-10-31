import { createHash, randomInt, randomUUID } from "node:crypto";
import * as codec from "../codec/schemas.js";
import type {
  AdminCommand, BoothMap, ClientMessage, DeviceStatus, GameCommand, GameEvent, Hello, HostState,
  Identity, PublicDisplayState, SabotageKind, ServerMessage, Sighting, VoteChoice
} from "../codec/schemas.js";
import { WIRE_VERSION, defaultSettings } from "../codec/schemas.js";
import { GameEngine } from "../engine/engine.js";
import { HostError, RuleError } from "../engine/errors.js";
import { SystemRng, type Rng } from "../engine/rng.js";
import type { Db } from "../store/db.js";
import { systemClock, type Clock } from "./clock.js";
import type { IpLimiter } from "./ratelimit.js";
import { playerOf, publicDisplayState, setupIssues, stationTitle, viewFor, type ViewContext } from "./views.js";

export interface Conn {
  send(message: ServerMessage): void;
  close(): void;
}

interface Session {
  conn: Conn;
  ip: string;
  identity?: Identity;
  failures: number;
  lockedUntil?: number;
  lastSeen: number;
  probe?: { nonce: string; sentAt: number };
  lastReplyAt?: number;
  lastDisplay?: string;
}

interface SightingRecord {
  rssi: number;
  at: number;
}

export interface Snapshot {
  state: HostState;
  selfies: Map<string, Buffer>;
  map: BoothMap | undefined;
}

export interface HostOptions {
  db: Db;
  clock?: Clock;
  rng?: Rng;
  isActive?: () => boolean;
  ipLimiter?: IpLimiter;
  bootstrapPin?: string;
}

const MAX_FAMILIES = 40;
const JOIN_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const MAX_SELFIE_BYTES = 150_000;
const MAX_MAP_BYTES = 8 * 1024 * 1024;
const START_COUNTDOWN = 10;
const MAX_FAILURES = 5;
const LOCK_DURATION = 30;
const PROBE_TIMEOUT = 3;
const segmenter = new Intl.Segmenter();

const graphemes = (text: string): number => [...segmenter.segment(text)].length;
const uuid = (): string => randomUUID().toUpperCase();
const makePin = (): string => String(randomInt(0, 10000)).padStart(4, "0");

function makeJoinCode(excluding: Set<string>): string {
  for (;;) {
    let code = "";
    for (let i = 0; i < 6; i++) code += JOIN_ALPHABET[randomInt(0, JOIN_ALPHABET.length)];
    if (!excluding.has(code)) return code;
  }
}

function makeToken(): string {
  let token = "";
  for (let i = 0; i < 6; i++) token += "0123456789ABCDEF"[randomInt(0, 16)];
  return token;
}

export function freshHostState(ocPin: string): HostState {
  return {
    settings: defaultSettings(),
    werewolfCount: 1,
    gameCode: undefined,
    families: new Map(),
    players: new Map(),
    ocDevices: new Map(),
    ocPin,
    rssiThreshold: -75,
    sightingFreshness: 10,
    engine: undefined,
    simulated: false
  };
}

export function detectImage(bytes: Buffer): boolean {
  const jpeg = bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const png = bytes.length > 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  return jpeg || png;
}

export function makeBoothMap(bytes: Buffer): BoothMap {
  return { hash: createHash("sha256").update(bytes).digest("hex"), jpeg: bytes };
}

export class GameHost implements ViewContext {
  state: HostState;
  gameID: string;
  sessions = new Map<string, Session>();
  recentEvents: GameEvent[] = [];
  selfies = new Map<string, Buffer>();
  boothMap: BoothMap | undefined;
  revision = 0;
  bellRings = 0;

  private sightings = new Map<number, Map<number, SightingRecord>>();
  private lastNearby = new Map<number, Set<number>>();
  private lastBodies = new Map<number, Set<number>>();
  private connectivityCheckAt: number | undefined;
  private readonly db: Db;
  private readonly clock: Clock;
  private readonly rng: Rng;
  private readonly isActive: () => boolean;
  private readonly ipLimiter: IpLimiter | undefined;
  private readonly bootstrapPin: string | undefined;

  constructor(options: HostOptions) {
    this.db = options.db;
    this.clock = options.clock ?? systemClock;
    this.rng = options.rng ?? new SystemRng();
    this.isActive = options.isActive ?? (() => true);
    this.ipLimiter = options.ipLimiter;
    this.bootstrapPin = options.bootstrapPin;

    this.selfies = this.db.loadSelfies();
    this.boothMap = this.db.loadBoothMap();
    const stored = this.db.loadHostState();
    if (stored) {
      this.gameID = stored.gameID;
      this.state = codec.hostState.dec(stored.json);
      this.state.gameCode ??= makeJoinCode(new Set());
      this.recentEvents = this.db.loadEvents(stored.gameID, 200).map((e) => codec.gameEvent.dec(e));
    } else {
      this.gameID = uuid();
      this.state = freshHostState(this.bootstrapPin ?? makePin());
      this.state.gameCode = makeJoinCode(new Set());
    }
    this.persist([]);
  }

  now(): number {
    return this.clock();
  }

  connect(id: string, conn: Conn, ip: string): void {
    this.sessions.set(id, { conn, ip, failures: 0, lastSeen: this.now() });
  }

  disconnect(id: string): void {
    const session = this.sessions.get(id);
    if (!session) return;
    this.sessions.delete(id);
    this.revision += 1;
    if (session.identity) this.broadcastAdmins();
  }

  disconnectAll(): void {
    for (const [id, session] of [...this.sessions]) {
      this.sessions.delete(id);
      session.conn.close();
    }
  }

  receive(message: ClientMessage, id: string): void {
    const session = this.sessions.get(id);
    if (!session) return;
    session.lastSeen = this.now();
    try {
      switch (message.case) {
        case "hello": this.authenticate(message._0, id); break;
        case "probeReply":
          if (session.probe?.nonce === message._0) session.lastReplyAt = this.now();
          break;
        case "renameFamily": this.renameOwnFamily(this.signedIn(id), message._0); break;
        case "admin": this.adminCommand(message._0, this.signedIn(id)); break;
        case "reportBody": this.reportBody(this.signedIn(id), message._0); break;
        case "voteSkipDiscussion": this.voteSkipDiscussion(this.signedIn(id)); break;
        case "selfie": this.storeSelfie(message._0, this.signedIn(id)); break;
        case "vote": this.vote(this.signedIn(id), message._0); break;
        case "sightings": this.receiveSightings(message._0, this.signedIn(id)); break;
        case "kill": this.kill(this.signedIn(id), message.victim); break;
        case "requestSabotage": this.requestSabotage(this.signedIn(id), message._0); break;
        case "resolveSabotage": this.resolveSabotage(this.signedIn(id)); break;
        case "leave": this.leave(this.signedIn(id), id); break;
        case "sync": this.sync(id); break;
      }
    } catch (error) {
      if (error instanceof HostError || error instanceof RuleError) this.send(id, { case: "rejected", _0: error.message });
      else {
        console.error("unexpected host error", error);
        this.send(id, { case: "rejected", _0: "Something went wrong." });
      }
    }
  }

  tick(): void {
    const engine = this.state.engine;
    if (engine) {
      const events = engine.advance(this.now());
      if (events.length > 0) this.commit(events);
    }
    this.refreshNearby();
    if (this.connectivityCheckAt !== undefined && this.now() >= this.connectivityCheckAt) {
      this.connectivityCheckAt = undefined;
      this.broadcastAdmins();
    }
    this.pushDisplays();
  }

  checkConnectivity(): void {
    const nonce = uuid();
    const now = this.now();
    for (const [id, session] of this.sessions) {
      if (!session.identity) continue;
      session.probe = { nonce, sentAt: now };
      session.lastReplyAt = undefined;
      this.send(id, { case: "probe", _0: nonce });
    }
    this.revision += 1;
    this.connectivityCheckAt = now + PROBE_TIMEOUT + 0.5;
  }

  deviceStatuses(): DeviceStatus[] {
    const now = this.now();
    const online = new Map<string, Session>();
    for (const session of this.sessions.values()) {
      if (session.identity) online.set(session.identity._0, session);
    }
    const connection = (id: string): [DeviceStatus["connection"], number | undefined] => {
      const session = online.get(id);
      if (!session) return ["offline", undefined];
      const probe = session.probe;
      if (probe && session.lastReplyAt === undefined && now - probe.sentAt > PROBE_TIMEOUT) {
        return ["unreachable", session.lastSeen];
      }
      return ["online", session.lastSeen];
    };
    const players = [...this.state.players.values()].map((player): DeviceStatus => {
      const [status, seen] = connection(player.id);
      return {
        id: player.id,
        label: player.name,
        detail: this.state.families.get(player.family)?.name ?? "Unknown family",
        connection: status,
        lastSeen: seen,
        isOC: false
      };
    });
    const ocs = [...this.state.ocDevices.values()].map((device): DeviceStatus => {
      const [status, seen] = connection(device.id);
      return { id: device.id, label: "OC", detail: stationTitle(device.station), connection: status, lastSeen: seen, isOC: true };
    });
    return [...players, ...ocs].sort((a, b) =>
      a.detail !== b.detail ? (a.detail < b.detail ? -1 : 1) : a.label < b.label ? -1 : a.label > b.label ? 1 : 0
    );
  }

  get selfieList() {
    return [...this.selfies].map(([player, jpeg]) => ({ player, jpeg }));
  }

  view(identity: Identity) {
    return viewFor(this, identity);
  }

  displayState(): PublicDisplayState {
    return publicDisplayState(this);
  }

  broadcast(): void {
    for (const [id, session] of this.sessions) {
      if (!session.identity) continue;
      const view = this.view(session.identity);
      if (view) this.send(id, { case: "state", _0: view });
    }
    this.pushDisplays();
  }

  private broadcastAdmins(): void {
    for (const [id, session] of this.sessions) {
      if (!session.identity || !this.isAdmin(session.identity)) continue;
      const view = this.view(session.identity);
      if (view) this.send(id, { case: "state", _0: view });
    }
  }

  private isAdmin(identity: Identity): boolean {
    return identity.case === "oc" && this.state.ocDevices.get(identity._0)?.station.case === "admin";
  }

  private pushDisplays(): void {
    let json: string | undefined;
    for (const [id, session] of this.sessions) {
      if (!session.identity || !this.isAdmin(session.identity)) continue;
      json ??= JSON.stringify(codec.publicDisplayState.enc(this.displayState()));
      if (session.lastDisplay === json) continue;
      session.lastDisplay = json;
      this.send(id, { case: "display", _0: this.displayState() });
    }
  }

  private persist(events: GameEvent[]): void {
    this.db.saveHostState(this.gameID, codec.hostState.enc(this.state), events.map((e) => codec.gameEvent.enc(e)), this.now());
  }

  commit(events: GameEvent[] = []): void {
    this.revision += 1;
    this.recentEvents = [...this.recentEvents, ...events].slice(-200);
    this.persist(events);
    this.broadcast();
  }

  private send(id: string, message: ServerMessage): void {
    this.sessions.get(id)?.conn.send(message);
  }

  private signedIn(id: string): Identity {
    const identity = this.sessions.get(id)?.identity;
    if (!identity) throw new HostError("notSignedIn");
    return identity;
  }

  private authenticate(hello: Hello, id: string): void {
    const session = this.sessions.get(id)!;
    const now = this.now();
    if (session.lockedUntil !== undefined && now < session.lockedUntil) throw new HostError("tooManyAttempts");
    if (this.ipLimiter?.isLocked(session.ip)) throw new HostError("tooManyAttempts");
    if (!this.isActive()) throw new HostError("notActiveHost");
    if (hello.version !== WIRE_VERSION) throw new HostError("unsupportedVersion");

    let identity: Identity;
    try {
      identity = this.resolve(hello);
    } catch (error) {
      if (error instanceof HostError && error.kind === "invalidCredential") {
        this.registerFailure(id);
        this.ipLimiter?.recordFailure(session.ip);
      }
      throw error;
    }

    for (const [other, otherSession] of [...this.sessions]) {
      if (other !== id && otherSession.identity?.case === identity.case && otherSession.identity._0 === identity._0) {
        this.sessions.delete(other);
        otherSession.conn.close();
      }
    }
    session.failures = 0;
    session.identity = identity;
    this.ipLimiter?.recordSuccess(session.ip);
    this.send(id, { case: "welcome", _0: { resumeID: identity._0, serverTime: now } });
    this.send(id, { case: "selfies", _0: this.selfieList });
    if (hello.mapHash !== this.boothMap?.hash) this.send(id, { case: "map", _0: this.boothMap });
    this.commit();
  }

  private resolve(hello: Hello): Identity {
    const state = this.state;
    const credential = hello.credential;
    switch (credential.case) {
      case "familyCode": {
        const normalized = credential._0.trim().toUpperCase();
        const legacy = [...state.families.values()].find((f) => f.joinCode === normalized);
        if (!(normalized === state.gameCode || legacy)) throw new HostError("invalidCredential");
        if (state.engine) throw new HostError("gameAlreadyStarted");
        const name = hello.name?.trim();
        if (!name) throw new HostError("nameRequired");
        if (graphemes(name) < 1 || graphemes(name) > 24) throw new HostError("invalidName");
        let family: number;
        if (legacy) {
          if (playerOf(state, legacy.id)) throw new HostError("familyFull");
          family = legacy.id;
        } else {
          family = this.assignFamily();
        }
        const info = state.families.get(family);
        if (info) info.name = name;
        const player = { id: uuid(), name, family, bleToken: makeToken() };
        state.players.set(player.id, player);
        return { case: "player", _0: player.id };
      }
      case "ocPin": {
        if (credential._0 !== state.ocPin || !hello.station) throw new HostError("invalidCredential");
        const device = { id: uuid(), station: hello.station };
        state.ocDevices.set(device.id, device);
        return { case: "oc", _0: device.id };
      }
      case "resume": {
        const id = credential._0;
        if (state.players.has(id)) return { case: "player", _0: id };
        if (state.ocDevices.has(id)) return { case: "oc", _0: id };
        throw new HostError("unknownDevice");
      }
    }
  }

  private registerFailure(id: string): void {
    const session = this.sessions.get(id);
    if (!session) return;
    session.failures += 1;
    if (session.failures >= MAX_FAILURES) {
      session.lockedUntil = this.now() + LOCK_DURATION;
      session.failures = 0;
    }
  }

  private assignFamily(): number {
    const state = this.state;
    const open = [...state.families.keys()].sort((a, b) => a - b).find((id) => !playerOf(state, id));
    if (open !== undefined) return open;
    if (state.families.size >= MAX_FAMILIES) throw new HostError("familyFull");
    const number = Math.max(0, ...state.families.keys()) + 1;
    const used = new Set([...state.families.values()].map((f) => f.joinCode));
    state.families.set(number, { id: number, name: `Family ${number}`, joinCode: makeJoinCode(used) });
    return number;
  }

  replaceState(change: (state: HostState) => void): void {
    change(this.state);
    this.commit();
  }

  configure(familyCount: number, werewolfCount: number, settings: HostState["settings"]): void {
    if (this.state.engine) throw new HostError("gameAlreadyStarted");
    const current = [...this.state.families.keys()].sort((a, b) => a - b);
    if (familyCount < current.length) {
      for (const id of current.slice(familyCount)) {
        if (playerOf(this.state, id)) throw new HostError("familyHasMembers");
      }
    }
    this.replaceState((state) => {
      if (familyCount < current.length) {
        for (const id of current.slice(familyCount)) state.families.delete(id);
      } else if (familyCount > current.length) {
        const codes = new Set([...state.families.values()].map((f) => f.joinCode));
        for (let n = current.length + 1; n <= familyCount; n++) {
          const code = makeJoinCode(codes);
          codes.add(code);
          state.families.set(n, { id: n, name: `Family ${n}`, joinCode: code });
        }
      }
      state.werewolfCount = werewolfCount;
      state.settings = settings;
    });
  }

  updateSettings(werewolfCount: number, settings: HostState["settings"]): void {
    if (this.state.engine) throw new HostError("gameAlreadyStarted");
    this.replaceState((state) => {
      state.werewolfCount = werewolfCount;
      state.settings = settings;
    });
  }

  startGame(): void {
    const state = this.state;
    if (state.engine) throw new HostError("gameAlreadyStarted");
    const issue = setupIssues(state)[0];
    if (issue) throw new HostError("setup", issue);
    const debug = state.settings.debugMode ?? false;
    const { engine, events } = GameEngine.start(
      [...state.families.keys()].sort((a, b) => a - b),
      state.werewolfCount,
      state.settings,
      this.now() + (debug ? 0 : START_COUNTDOWN),
      this.rng
    );
    state.engine = engine;
    this.commit(events);
  }

  newGame(): void {
    const old = this.state;
    const fresh = freshHostState(old.ocPin);
    fresh.ocDevices = old.ocDevices;
    fresh.gameCode = makeJoinCode(new Set());
    fresh.settings = old.settings;
    fresh.werewolfCount = old.werewolfCount;
    fresh.rssiThreshold = old.rssiThreshold;
    fresh.sightingFreshness = old.sightingFreshness;
    this.gameID = uuid();
    this.state = fresh;
    this.selfies = new Map();
    this.db.replaceSelfies(this.selfies);
    this.db.clearEventsExcept(this.gameID);
    this.recentEvents = [];
    for (const [id, session] of this.sessions) {
      if (session.identity?.case === "player") {
        session.identity = undefined;
        this.send(id, { case: "reset" });
      }
    }
    this.commit();
  }

  private leave(identity: Identity, clientID: string): void {
    const player = identity.case === "player" ? this.state.players.get(identity._0) : undefined;
    if (!player) throw new HostError("notAPlayer");
    if (this.state.engine) throw new HostError("gameAlreadyStarted");
    this.state.players.delete(player.id);
    this.selfies.delete(player.id);
    this.db.deleteSelfie(player.id);
    this.state.families.delete(player.family);
    const session = this.sessions.get(clientID);
    if (session) session.identity = undefined;
    this.send(clientID, { case: "reset" });
    this.commit();
  }

  private sendSelfies(): void {
    const update: ServerMessage = { case: "selfies", _0: this.selfieList };
    for (const [id, session] of this.sessions) {
      if (session.identity) this.send(id, update);
    }
  }

  private removeDevice(id: string): void {
    let identity: Identity;
    if (this.state.ocDevices.has(id)) {
      this.state.ocDevices.delete(id);
      identity = { case: "oc", _0: id };
    } else if (this.state.players.has(id)) {
      if (this.state.engine) throw new HostError("gameAlreadyStarted");
      this.state.players.delete(id);
      this.selfies.delete(id);
      this.db.deleteSelfie(id);
      identity = { case: "player", _0: id };
    } else {
      throw new HostError("unknownDevice");
    }
    for (const [clientID, session] of this.sessions) {
      if (session.identity?.case === identity.case && session.identity._0 === identity._0) {
        session.identity = undefined;
        this.send(clientID, { case: "reset" });
      }
    }
    this.sendSelfies();
    this.commit();
  }

  private removeFamily(id: number): void {
    if (this.state.engine) throw new HostError("gameAlreadyStarted");
    if (!this.state.families.has(id)) throw new RuleError("unknownFamily");
    const removed = new Set([...this.state.players.values()].filter((p) => p.family === id).map((p) => p.id));
    for (const playerID of removed) {
      this.state.players.delete(playerID);
      this.selfies.delete(playerID);
      this.db.deleteSelfie(playerID);
    }
    for (const [clientID, session] of this.sessions) {
      if (session.identity?.case === "player" && removed.has(session.identity._0)) {
        session.identity = undefined;
        this.send(clientID, { case: "reset" });
      }
    }
    this.state.families.delete(id);
    this.sendSelfies();
    this.commit();
  }

  private sync(id: string): void {
    this.tick();
    const identity = this.signedIn(id);
    const view = this.view(identity);
    if (view) this.send(id, { case: "state", _0: view });
  }

  private renameOwnFamily(identity: Identity, name: string): void {
    const player = identity.case === "player" ? this.state.players.get(identity._0) : undefined;
    if (!player) throw new HostError("notAPlayer");
    this.renameFamily(player.family, name);
  }

  private renameFamily(family: number, name: string): void {
    if (this.state.engine) throw new HostError("gameAlreadyStarted");
    const trimmed = name.trim();
    const info = this.state.families.get(family);
    if (graphemes(trimmed) < 1 || graphemes(trimmed) > 24 || !info) throw new HostError("invalidName");
    info.name = trimmed;
    for (const player of this.state.players.values()) {
      if (player.family === family) player.name = trimmed;
    }
    this.commit();
  }

  private storeSelfie(bytes: Buffer, identity: Identity): void {
    const player = identity.case === "player" ? this.state.players.get(identity._0) : undefined;
    if (!player) throw new HostError("notAPlayer");
    if (this.state.engine) throw new HostError("gameAlreadyStarted");
    if (bytes.length > MAX_SELFIE_BYTES) throw new HostError("photoTooLarge");
    this.selfies.set(player.id, bytes);
    this.db.setSelfie(player.id, bytes);
    this.sendSelfies();
    this.pushDisplays();
  }

  private playerFor(identity: Identity) {
    const player = identity.case === "player" ? this.state.players.get(identity._0) : undefined;
    if (!player) throw new HostError("notAPlayer");
    return player;
  }

  private voteSkipDiscussion(identity: Identity): void {
    this.applyAsOC({ case: "voteSkipDiscussion", by: this.playerFor(identity).family });
  }

  private vote(identity: Identity, choice: VoteChoice): void {
    this.applyAsOC({ case: "castVote", by: this.playerFor(identity).family, choice });
  }

  applyAsOC(command: GameCommand): void {
    const engine = this.state.engine;
    if (!engine) throw new RuleError("wrongPhase");
    const events = engine.apply(command, this.now());
    this.commit(events);
  }

  private receiveSightings(list: Sighting[], identity: Identity): void {
    const observer = this.playerFor(identity);
    const owners = new Map<string, number>();
    for (const player of this.state.players.values()) {
      if (!owners.has(player.bleToken)) owners.set(player.bleToken, player.family);
    }
    const now = this.now();
    for (const sighting of list) {
      const target = owners.get(sighting.token);
      if (target === undefined || target === observer.family) continue;
      const current = this.sightings.get(observer.family)?.get(target);
      const isFresh = current ? now - current.at <= this.state.sightingFreshness : false;
      if (current && isFresh && current.rssi > sighting.rssi && now - current.at < 1) continue;
      let row = this.sightings.get(observer.family);
      if (!row) this.sightings.set(observer.family, (row = new Map()));
      row.set(target, { rssi: sighting.rssi, at: now });
    }
    this.refreshNearby();
  }

  nearbyFamilies(killer: number): number[] {
    const engine = this.state.engine;
    if (!engine) return [];
    const now = this.now();
    const out: number[] = [];
    for (const [target, record] of this.sightings.get(killer) ?? []) {
      const family = engine.state.families.get(target);
      if (family && family.role === "villager" && family.life === "alive" &&
          record.rssi >= this.state.rssiThreshold && now - record.at <= this.state.sightingFreshness) {
        out.push(target);
      }
    }
    return out.sort((a, b) => a - b);
  }

  nearbyBodies(viewer: number): number[] {
    const engine = this.state.engine;
    if (!engine || engine.state.families.get(viewer)?.life !== "alive") return [];
    const now = this.now();
    const out: number[] = [];
    for (const [target, record] of this.sightings.get(viewer) ?? []) {
      if (engine.state.families.get(target)?.life === "killed" &&
          engine.state.deadSinceLastMeeting.includes(target) &&
          record.rssi >= this.state.rssiThreshold && now - record.at <= this.state.sightingFreshness) {
        out.push(target);
      }
    }
    return out.sort((a, b) => a - b);
  }

  private reportBody(identity: Identity, body: number): void {
    const player = this.playerFor(identity);
    if (!this.state.engine) throw new HostError("notInGame");
    if (!this.nearbyBodies(player.family).includes(body)) throw new HostError("notNearBody");
    this.applyAsOC({ case: "reportBody", by: player.family, body });
    this.refreshNearby();
  }

  private refreshNearby(): void {
    const engine = this.state.engine;
    if (!engine) return;
    let changed = false;
    const same = (a: Set<number> | undefined, b: Set<number>) => !!a && a.size === b.size && [...b].every((x) => a.has(x));
    for (const family of engine.state.families.values()) {
      if (family.role !== "werewolf") continue;
      const current = new Set(this.nearbyFamilies(family.id));
      if (!same(this.lastNearby.get(family.id), current)) {
        changed = true;
        this.lastNearby.set(family.id, current);
      }
    }
    for (const family of engine.state.families.values()) {
      if (family.life !== "alive") continue;
      const current = new Set(this.nearbyBodies(family.id));
      if (!same(this.lastBodies.get(family.id) ?? new Set(), current)) {
        changed = true;
        this.lastBodies.set(family.id, current);
      }
    }
    if (changed) this.broadcast();
  }

  private kill(identity: Identity, victim: number): void {
    const player = this.playerFor(identity);
    if (!this.state.engine) throw new HostError("notInGame");
    if (!this.nearbyFamilies(player.family).includes(victim)) throw new HostError("notNearby");
    this.applyAsOC({ case: "kill", killer: player.family, victim });
    this.sightings.get(player.family)?.delete(victim);
    this.refreshNearby();
  }

  private requestSabotage(identity: Identity, kind: SabotageKind): void {
    const player = this.playerFor(identity);
    if (!this.state.engine) throw new HostError("notInGame");
    this.applyAsOC({ case: "requestSabotage", by: player.family, kind });
  }

  private resolveSabotage(identity: Identity): void {
    const device = identity.case === "oc" ? this.state.ocDevices.get(identity._0) : undefined;
    if (!device) throw new HostError("notOC");
    const active = this.state.engine?.state.sabotage;
    if (!active) throw new RuleError("noActiveSabotage");
    const station = device.station;
    const allowed = station.case === "townHall" || (station.case === "sabotage" && station._0 === active.kind);
    if (!allowed) throw new HostError("wrongStation");
    this.applyAsOC({ case: "resolveSabotage" });
  }

  setBoothMap(bytes: Buffer): void {
    if (bytes.length === 0 || bytes.length > MAX_MAP_BYTES || !detectImage(bytes)) throw new HostError("invalidImage");
    this.applyBoothMap(makeBoothMap(bytes));
  }

  removeBoothMap(): void {
    this.applyBoothMap(undefined);
  }

  private applyBoothMap(map: BoothMap | undefined): void {
    this.db.saveBoothMap(map);
    this.boothMap = map;
    for (const [id, session] of this.sessions) {
      if (session.identity) this.send(id, { case: "map", _0: map });
    }
  }

  private adminCommand(command: AdminCommand, identity: Identity): void {
    const device = identity.case === "oc" ? this.state.ocDevices.get(identity._0) : undefined;
    if (!device || device.station.case !== "admin") throw new HostError("notOC");
    switch (command.case) {
      case "ringBell": this.bellRings += 1; break;
      case "startMeeting": this.applyAsOC({ case: "startMeeting" }); break;
      case "extendMeeting": this.applyAsOC({ case: "extendMeeting", seconds: command.seconds }); break;
      case "adjustTimer": this.applyAsOC({ case: "adjustTimer", _0: command._0, seconds: command.seconds }); break;
      case "pauseTimer": this.applyAsOC({ case: "pauseTimer", _0: command._0 }); break;
      case "resumeTimer": this.applyAsOC({ case: "resumeTimer", _0: command._0 }); break;
      case "approveSkipDiscussion": this.applyAsOC({ case: "approveSkipDiscussion" }); break;
      case "resolveSabotage": this.applyAsOC({ case: "resolveSabotage" }); break;
      case "removeFamily": this.removeFamily(command._0); break;
      case "removeDevice": this.removeDevice(command._0); break;
      case "updateSettings": this.updateSettings(command.werewolfCount, command.settings); break;
      case "setProximity":
        this.replaceState((s) => {
          s.rssiThreshold = command.rssiThreshold;
          s.sightingFreshness = command.sightingFreshness;
        });
        break;
      case "startGame": this.startGame(); break;
      case "newGame": this.newGame(); break;
      case "renameFamily": this.renameFamily(command._0, command._1); break;
      case "regenerateOCPIN":
        this.state.ocPin = makePin();
        this.commit();
        break;
      case "setBoothMap": this.setBoothMap(command._0); break;
      case "removeBoothMap": this.removeBoothMap(); break;
      case "eliminate":
        for (const family of command._0) this.applyAsOC({ case: "override", _0: { case: "forceKill", _0: family } });
        break;
      case "revive":
        for (const family of command._0) this.applyAsOC({ case: "override", _0: { case: "revive", _0: family } });
        break;
      case "proxyVote": this.applyAsOC({ case: "proxyVote", for: command.family, choice: command.choice }); break;
      case "endGame": this.applyAsOC({ case: "override", _0: { case: "endGame", _0: command._0 } }); break;
      case "checkConnectivity": this.checkConnectivity(); break;
    }
  }

  exportSnapshot(): Snapshot {
    return { state: this.state, selfies: new Map(this.selfies), map: this.boothMap };
  }

  importSnapshot(snapshot: Snapshot): void {
    this.disconnectAll();
    this.gameID = uuid();
    this.state = snapshot.state;
    this.state.gameCode ??= makeJoinCode(new Set());
    this.selfies = new Map(snapshot.selfies);
    this.boothMap = snapshot.map;
    this.sightings = new Map();
    this.lastNearby = new Map();
    this.lastBodies = new Map();
    this.recentEvents = [];
    this.db.replaceSelfies(this.selfies);
    this.db.saveBoothMap(this.boothMap);
    this.db.clearEventsExcept(this.gameID);
    this.persist([]);
  }
}
