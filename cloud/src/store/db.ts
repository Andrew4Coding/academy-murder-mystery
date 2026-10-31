import Database from "better-sqlite3";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";

export type Mode = "cloud" | "local";

export interface RegistryRow {
  mode: Mode;
  updatedAt: number;
}

export interface SnapshotRow {
  body: string;
  at: number;
}

export const MAX_STORED_EVENTS = 1000;

export class Db {
  private db: Database.Database;

  constructor(path: string) {
    if (path !== ":memory:") mkdirSync(dirname(path), { recursive: true });
    this.db = new Database(path);
    this.db.pragma("journal_mode = WAL");
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS host_state (id INTEGER PRIMARY KEY CHECK (id = 1), game_id TEXT NOT NULL, json TEXT NOT NULL, updated_at REAL NOT NULL);
      CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY AUTOINCREMENT, game_id TEXT NOT NULL, json TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS selfies (player TEXT PRIMARY KEY, jpeg BLOB NOT NULL);
      CREATE TABLE IF NOT EXISTS booth_map (id INTEGER PRIMARY KEY CHECK (id = 1), hash TEXT NOT NULL, jpeg BLOB NOT NULL);
      CREATE TABLE IF NOT EXISTS booth_catalog (id INTEGER PRIMARY KEY CHECK (id = 1), json TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS registry (id INTEGER PRIMARY KEY CHECK (id = 1), mode TEXT NOT NULL, updated_at REAL NOT NULL);
      CREATE TABLE IF NOT EXISTS snapshot (id INTEGER PRIMARY KEY CHECK (id = 1), body TEXT NOT NULL, at REAL NOT NULL);
    `);
  }

  close(): void {
    this.db.close();
  }

  loadHostState(): { gameID: string; json: unknown } | undefined {
    const row = this.db.prepare("SELECT game_id, json FROM host_state WHERE id = 1").get() as
      | { game_id: string; json: string }
      | undefined;
    return row ? { gameID: row.game_id, json: JSON.parse(row.json) } : undefined;
  }

  saveHostState(gameID: string, json: unknown, events: unknown[], at: number): void {
    this.db.transaction(() => {
      this.db
        .prepare(
          "INSERT INTO host_state (id, game_id, json, updated_at) VALUES (1, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET game_id = excluded.game_id, json = excluded.json, updated_at = excluded.updated_at"
        )
        .run(gameID, JSON.stringify(json), at);
      if (events.length > 0) {
        const insert = this.db.prepare("INSERT INTO events (game_id, json) VALUES (?, ?)");
        for (const event of events) insert.run(gameID, JSON.stringify(event));
        this.db
          .prepare("DELETE FROM events WHERE id <= (SELECT MAX(id) FROM events) - ?")
          .run(MAX_STORED_EVENTS);
      }
    })();
  }

  loadEvents(gameID: string, limit: number): unknown[] {
    const rows = this.db
      .prepare("SELECT json FROM events WHERE game_id = ? ORDER BY id DESC LIMIT ?")
      .all(gameID, limit) as { json: string }[];
    return rows.reverse().map((r) => JSON.parse(r.json));
  }

  clearEventsExcept(gameID: string): void {
    this.db.prepare("DELETE FROM events WHERE game_id != ?").run(gameID);
  }

  loadSelfies(): Map<string, Buffer> {
    const rows = this.db.prepare("SELECT player, jpeg FROM selfies").all() as { player: string; jpeg: Buffer }[];
    return new Map(rows.map((r) => [r.player, r.jpeg]));
  }

  setSelfie(player: string, jpeg: Buffer): void {
    this.db
      .prepare("INSERT INTO selfies (player, jpeg) VALUES (?, ?) ON CONFLICT(player) DO UPDATE SET jpeg = excluded.jpeg")
      .run(player, jpeg);
  }

  deleteSelfie(player: string): void {
    this.db.prepare("DELETE FROM selfies WHERE player = ?").run(player);
  }

  replaceSelfies(selfies: Map<string, Buffer>): void {
    this.db.transaction(() => {
      this.db.prepare("DELETE FROM selfies").run();
      for (const [player, jpeg] of selfies) this.setSelfie(player, jpeg);
    })();
  }

  loadBoothMap(): { hash: string; jpeg: Buffer } | undefined {
    return this.db.prepare("SELECT hash, jpeg FROM booth_map WHERE id = 1").get() as
      | { hash: string; jpeg: Buffer }
      | undefined;
  }

  saveBoothMap(map: { hash: string; jpeg: Buffer } | undefined): void {
    if (!map) {
      this.db.prepare("DELETE FROM booth_map").run();
      return;
    }
    this.db
      .prepare(
        "INSERT INTO booth_map (id, hash, jpeg) VALUES (1, ?, ?) ON CONFLICT(id) DO UPDATE SET hash = excluded.hash, jpeg = excluded.jpeg"
      )
      .run(map.hash, map.jpeg);
  }

  loadBoothCatalog(): unknown | undefined {
    const row = this.db.prepare("SELECT json FROM booth_catalog WHERE id = 1").get() as { json: string } | undefined;
    return row ? JSON.parse(row.json) : undefined;
  }

  saveBoothCatalog(json: unknown): void {
    this.db
      .prepare("INSERT INTO booth_catalog (id, json) VALUES (1, ?) ON CONFLICT(id) DO UPDATE SET json = excluded.json")
      .run(JSON.stringify(json));
  }

  getRegistry(): RegistryRow | undefined {
    const row = this.db.prepare("SELECT mode, updated_at FROM registry WHERE id = 1").get() as
      | { mode: Mode; updated_at: number }
      | undefined;
    return row ? { mode: row.mode, updatedAt: row.updated_at } : undefined;
  }

  setRegistry(mode: Mode, updatedAt: number): void {
    this.db
      .prepare(
        "INSERT INTO registry (id, mode, updated_at) VALUES (1, ?, ?) ON CONFLICT(id) DO UPDATE SET mode = excluded.mode, updated_at = excluded.updated_at"
      )
      .run(mode, updatedAt);
  }

  getSnapshot(): SnapshotRow | undefined {
    return this.db.prepare("SELECT body, at FROM snapshot WHERE id = 1").get() as SnapshotRow | undefined;
  }

  setSnapshot(body: string, at: number): void {
    this.db
      .prepare(
        "INSERT INTO snapshot (id, body, at) VALUES (1, ?, ?) ON CONFLICT(id) DO UPDATE SET body = excluded.body, at = excluded.at"
      )
      .run(body, at);
  }
}
