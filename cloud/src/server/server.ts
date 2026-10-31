import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { createServer as createHttpServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";
import { WebSocketServer, type WebSocket } from "ws";
import * as codec from "../codec/schemas.js";
import { DecodeError } from "../codec/combinators.js";
import type { Rng } from "../engine/rng.js";
import { GameHost } from "../host/host.js";
import { systemClock, toUnix, type Clock } from "../host/clock.js";
import { IpLimiter } from "../host/ratelimit.js";
import { Db, type Mode } from "../store/db.js";
import { parseSnapshot, serializeSnapshot } from "./snapshot.js";
import { takeoverPage } from "./takeover-page.js";

export interface ServerConfig {
  dbPath: string;
  trustProxy?: boolean;
  pairingSecret?: string;
  bootstrapPin?: string;
  clock?: Clock;
  rng?: Rng;
  tickMs?: number;
}

const MAX_BODY = 64 * 1024 * 1024;
const MAX_WS_PAYLOAD = 12 * 1024 * 1024;
const PING_INTERVAL_MS = 25_000;

class HttpError extends Error {
  constructor(readonly status: number, message: string, readonly headers: Record<string, string> = {}) {
    super(message);
  }
}

const digest = (value: string) => createHash("sha256").update(value).digest();
const safeEqual = (a: string, b: string) => timingSafeEqual(digest(a), digest(b));

export class CloudServer {
  readonly db: Db;
  readonly host: GameHost;
  readonly ipLimiter: IpLimiter;
  private readonly http: Server;
  private readonly wss: WebSocketServer;
  private readonly clock: Clock;
  private ticker?: NodeJS.Timeout;
  private pinger?: NodeJS.Timeout;
  private snapshotPin?: string;

  constructor(private readonly config: ServerConfig) {
    this.clock = config.clock ?? systemClock;
    this.db = new Db(config.dbPath);
    this.ipLimiter = new IpLimiter(this.clock);
    this.host = new GameHost({
      db: this.db,
      clock: this.clock,
      rng: config.rng,
      isActive: () => this.mode === "cloud",
      ipLimiter: this.ipLimiter,
      bootstrapPin: config.bootstrapPin
    });
    this.snapshotPin = this.loadSnapshotPin();
    this.http = createHttpServer((req, res) => void this.handleHttp(req, res));
    this.wss = new WebSocketServer({ noServer: true, maxPayload: MAX_WS_PAYLOAD });
    this.http.on("upgrade", (req, socket, head) => {
      const path = (req.url ?? "").split("?")[0];
      if (path !== "/ws") {
        socket.destroy();
        return;
      }
      this.wss.handleUpgrade(req, socket, head, (ws) => this.onSocket(ws, req));
    });
  }

  get mode(): Mode {
    return this.db.getRegistry()?.mode ?? "local";
  }

  async start(port: number, hostname?: string): Promise<number> {
    await new Promise<void>((resolve) => this.http.listen(port, hostname, resolve));
    this.ticker = setInterval(() => {
      if (this.mode === "cloud") this.host.tick();
    }, this.config.tickMs ?? 500);
    this.pinger = setInterval(() => this.pingAll(), PING_INTERVAL_MS);
    return (this.http.address() as AddressInfo).port;
  }

  async stop(): Promise<void> {
    clearInterval(this.ticker);
    clearInterval(this.pinger);
    this.host.disconnectAll();
    for (const client of this.wss.clients) client.terminate();
    await new Promise<void>((resolve) => this.http.close(() => resolve()));
    this.db.close();
  }

  private alive = new WeakMap<WebSocket, boolean>();

  private pingAll(): void {
    for (const ws of this.wss.clients) {
      if (this.alive.get(ws) === false) {
        ws.terminate();
        continue;
      }
      this.alive.set(ws, false);
      ws.ping();
    }
  }

  private clientIp(req: IncomingMessage): string {
    if (this.config.trustProxy) {
      const forwarded = req.headers["x-forwarded-for"];
      const first = (Array.isArray(forwarded) ? forwarded[0] : forwarded)?.split(",")[0]?.trim();
      if (first) return first;
    }
    return req.socket.remoteAddress ?? "unknown";
  }

  private onSocket(ws: WebSocket, req: IncomingMessage): void {
    const id = randomUUID().toUpperCase();
    this.alive.set(ws, true);
    ws.on("pong", () => this.alive.set(ws, true));
    this.host.connect(
      id,
      {
        send: (message) => {
          if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(codec.serverMessage.enc(message)));
        },
        close: () => ws.close()
      },
      this.clientIp(req)
    );
    ws.on("message", (raw, isBinary) => {
      this.alive.set(ws, true);
      let message: codec.ClientMessage;
      try {
        message = codec.clientMessage.dec(JSON.parse(isBinary ? Buffer.from(raw as Buffer).toString("utf8") : raw.toString()));
      } catch {
        if (ws.readyState === ws.OPEN) {
          ws.send(JSON.stringify(codec.serverMessage.enc({ case: "rejected", _0: "Something went wrong." })));
        }
        return;
      }
      this.host.receive(message, id);
    });
    ws.on("close", () => this.host.disconnect(id));
    ws.on("error", () => ws.terminate());
  }

  private loadSnapshotPin(): string | undefined {
    const row = this.db.getSnapshot();
    if (!row) return undefined;
    try {
      return (JSON.parse(row.body) as { state?: { ocPin?: string } }).state?.ocPin;
    } catch {
      return undefined;
    }
  }

  private validPin(): string | undefined {
    if (this.mode === "cloud") return this.host.state.ocPin;
    return this.snapshotPin ?? this.config.bootstrapPin ?? this.host.state.ocPin;
  }

  private authorize(req: IncomingMessage, ip: string): void {
    const wait = this.ipLimiter.retryAfter(ip);
    if (wait > 0) throw new HttpError(429, "Too many attempts.", { "Retry-After": String(wait) });
    const pin = req.headers["x-moonfall-pin"];
    const secret = req.headers["x-moonfall-secret"];
    const pinValue = Array.isArray(pin) ? pin[0] : pin;
    const secretValue = Array.isArray(secret) ? secret[0] : secret;
    const expectedPin = this.validPin();
    const okPin = pinValue !== undefined && expectedPin !== undefined && safeEqual(pinValue, expectedPin);
    const okSecret =
      secretValue !== undefined && !!this.config.pairingSecret && safeEqual(secretValue, this.config.pairingSecret);
    if (okPin || okSecret) {
      this.ipLimiter.recordSuccess(ip);
      return;
    }
    this.ipLimiter.recordFailure(ip);
    throw new HttpError(401, "Not authorized.");
  }

  private registryJson() {
    const registry = this.db.getRegistry();
    const snapshot = this.db.getSnapshot();
    return {
      mode: this.mode,
      updatedAt: registry ? toUnix(registry.updatedAt) : 0,
      hasSnapshot: !!snapshot,
      snapshotAt: snapshot ? toUnix(snapshot.at) : null
    };
  }

  setMode(mode: Mode): void {
    this.db.setRegistry(mode, this.clock());
    if (mode === "local") this.host.disconnectAll();
  }

  private async readJson(req: IncomingMessage): Promise<unknown> {
    const chunks: Buffer[] = [];
    let size = 0;
    for await (const chunk of req) {
      size += (chunk as Buffer).length;
      if (size > MAX_BODY) throw new HttpError(413, "Body too large.");
      chunks.push(chunk as Buffer);
    }
    try {
      return JSON.parse(Buffer.concat(chunks).toString("utf8"));
    } catch {
      throw new HttpError(400, "Invalid JSON.");
    }
  }

  private reply(res: ServerResponse, status: number, body: unknown, headers: Record<string, string> = {}): void {
    const text = JSON.stringify(body);
    res.writeHead(status, { "Content-Type": "application/json", "Cache-Control": "no-store", ...headers });
    res.end(text);
  }

  private async handleHttp(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const ip = this.clientIp(req);
    const path = (req.url ?? "/").split("?")[0]!;
    const route = `${req.method} ${path}`;
    try {
      switch (route) {
        case "GET /health":
          return this.reply(res, 200, { ok: true });
        case "GET /registry":
          return this.reply(res, 200, this.registryJson());
        case "PUT /registry": {
          this.authorize(req, ip);
          const body = (await this.readJson(req)) as { mode?: unknown };
          if (body?.mode !== "cloud" && body?.mode !== "local") throw new HttpError(400, "mode must be cloud or local.");
          this.setMode(body.mode);
          return this.reply(res, 200, this.registryJson());
        }
        case "PUT /snapshot": {
          this.authorize(req, ip);
          const snapshot = this.parseBody(await this.readJson(req));
          const at = this.clock();
          this.db.setSnapshot(JSON.stringify(serializeSnapshot(snapshot)), at);
          this.snapshotPin = snapshot.state.ocPin;
          return this.reply(res, 200, { ok: true, snapshotAt: toUnix(at) });
        }
        case "GET /snapshot": {
          this.authorize(req, ip);
          const row = this.db.getSnapshot();
          if (!row) throw new HttpError(404, "No snapshot.");
          res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
          return void res.end(row.body);
        }
        case "GET /takeover":
          res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
          return void res.end(takeoverPage);
        case "POST /takeover": {
          const wait = this.ipLimiter.retryAfter(ip);
          if (wait > 0) throw new HttpError(429, "Too many attempts.", { "Retry-After": String(wait) });
          const body = (await this.readJson(req)) as { pin?: unknown };
          const expected = this.validPin();
          if (typeof body?.pin !== "string" || expected === undefined || !safeEqual(body.pin, expected)) {
            this.ipLimiter.recordFailure(ip);
            throw new HttpError(401, "Wrong PIN.");
          }
          this.ipLimiter.recordSuccess(ip);
          if (this.mode === "cloud") return this.reply(res, 200, { ok: true, alreadyActive: true });
          const row = this.db.getSnapshot();
          if (!row) throw new HttpError(404, "No snapshot to take over.");
          this.host.importSnapshot(parseSnapshot(JSON.parse(row.body)));
          this.setMode("cloud");
          return this.reply(res, 200, { ok: true });
        }
        case "PUT /import": {
          this.authorize(req, ip);
          const snapshot = this.parseBody(await this.readJson(req));
          this.host.importSnapshot(snapshot);
          this.setMode("cloud");
          return this.reply(res, 200, { ok: true });
        }
        case "GET /export": {
          this.authorize(req, ip);
          return this.reply(res, 200, serializeSnapshot(this.host.exportSnapshot()));
        }
        default:
          return this.reply(res, 404, { error: "Not found." });
      }
    } catch (error) {
      if (error instanceof HttpError) return this.reply(res, error.status, { error: error.message }, error.headers);
      if (error instanceof DecodeError) return this.reply(res, 400, { error: error.message });
      console.error("http error", error);
      this.reply(res, 500, { error: "Internal error." });
    }
  }

  private parseBody(body: unknown) {
    try {
      return parseSnapshot(body);
    } catch (error) {
      throw new HttpError(400, error instanceof Error ? error.message : "Invalid snapshot.");
    }
  }
}
