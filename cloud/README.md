# Moonfall cloud host

TypeScript (Node 22, ESM) port of the Mac `GameHost` that speaks the same Codable JSON over WebSocket. See `CONTRACT.md` for the routes and wire rules, `deploy/README.md` for deployment, and specs 0035 and 0036.

```bash
npm install
npm test          # vitest: engine, codec fixtures, host, server end to end
npm run build     # tsc to dist/
npm run dev       # tsx, DATA_DIR=./data, PORT=8080
```

Environment: `DATA_DIR`, `PORT`, `TRUST_PROXY=1` (behind nginx), `MOONFALL_PAIRING_SECRET`, `MOONFALL_BOOTSTRAP_PIN`.

## Layout

- `src/codec`: combinators and schemas for every Swift Codable type that crosses the wire or is stored.
- `src/engine`: `GameEngine`, `SeededGenerator` (bit-exact with Swift, including `shuffle`), rule errors.
- `src/host`: `GameHost`, views per identity, `PublicDisplayState`, per-IP limiter.
- `src/store`: SQLite (`host_state`, `events`, `selfies`, `booth_map`, `registry`, `snapshot`).
- `src/server`: HTTP routes, `/ws`, snapshot parsing.
- `test/fixtures`: `wire-*.json` and `trace-*.json` (written by the Swift side; `wire-hand-*` are hand-written from the Swift source).

## Booth map

Swift downsamples to a 3000 px JPEG with CoreGraphics. There is no image library here, so `setBoothMap` accepts a JPEG or PNG up to 8 MB (magic bytes checked), stores it as received and sets `hash` to the lowercase hex SHA-256 of those bytes, as `BoothMap.init(jpeg:)` does. Anything else is rejected with `invalidImage`. The Mac should resize before sending in Cloud mode.
