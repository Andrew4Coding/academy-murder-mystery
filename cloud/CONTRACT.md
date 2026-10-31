# Moonfall cloud host contract

Shared between the TypeScript server (`cloud/`) and the Swift apps. Specs: 0035, 0036, ADR 0009. Base URL in production: `https://moonfall.andrewaryo.com` (`wss://` for the socket).

## 1. JSON conventions (identical to Swift's default `JSONEncoder`)

| Swift | JSON |
|---|---|
| `Date` | number, seconds since 2001-01-01 UTC (reference date). Unix seconds = value + 978307200 |
| `UUID` | uppercase string. The server accepts any case and writes uppercase |
| `Data` | base64 string |
| `FamilyID` (struct) | `{"rawValue":3}` |
| Optional | key omitted when nil (also inside enum payloads) |
| `[FamilyID: V]`, `[UUID: V]`, `[TimerTarget: V]` | flat array `[k1, v1, k2, v2, ...]` (order not significant) |
| `Set<T>` | array (order not significant) |
| `RawRepresentable` enums (`Role`, `LifeState`, `Booth`, `SabotageKind`, `TimerTarget`, `Side`, ...) | raw value (`"werewolf"`, `3`) |
| Enum with associated values | `{"case":{...}}`; unlabeled payload is `_0`, `_1`, ...; labeled payload uses the label; no payload is `{}` |

Examples: `VoteChoice.family(3)` is `{"family":{"_0":{"rawValue":3}}}`; `.skip` is `{"skip":{}}`; `Phase.discussion(until:)` is `{"discussion":{"until":812345.5}}`; `GameEvent.Kind.familyKilled(2, by: nil)` is `{"familyKilled":{"_0":{"rawValue":2}}}`; `ClientMessage.kill(victim:)` is `{"kill":{"victim":{"rawValue":2}}}`; `AdminCommand.adjustTimer(.meeting, seconds: 5)` is `{"adjustTimer":{"_0":"meeting","seconds":5}}`.

`GameState` does not encode `votes` or `skipVotes` (as in Swift), so a restored or imported game starts with empty ballots.

## 2. WebSocket `/ws`

One JSON `ClientMessage` per text frame, one JSON `ServerMessage` per text frame (UTF-8, no length prefix). Behaviour follows `GameHost`: `hello` -> `welcome`, `selfies`, `map` (only when `mapHash` differs), `state`. Wire version is `2`.

### New `ServerMessage` case: `display`

```
{"display":{"_0": <PublicDisplayState>}}
```

`PublicDisplayState` is the exact Swift Codable shape (`Shared/Host/PublicDisplayState.swift`, with `screen`, `familiesRemaining`, `alarm`, `announcedDeaths`, `joinCode`, `lobbyFamilies`, `reveal`). The server sends it only to connections signed in as an OC device with station `admin`: once right after the first `state` of a connection, then whenever it changes (checked after every commit and on the 500 ms tick, because `starting` -> `playing` and the 30 s result window depend on time). The Swift side must add `case display(PublicDisplayState)` to `ServerMessage` and feed the Mac Public Display from it in Cloud mode. `hostOffline` is never sent by the server. Other stations never receive it.

### Close behaviour

- The server never closes a socket on a bad message; it replies `rejected(String)` with the Swift `HostError` / `RuleError` messages.
- A second hello with the same identity evicts the older connection (socket closed).
- Registry mode `local`: every `hello` is answered with `rejected("The game is hosted elsewhere right now. Reconnect to the active host.")` and the socket stays open until the client leaves. Switching the registry to `local` closes all sockets.
- `unknownDevice` on a `resume` hello does not count as a failed attempt.

### Rate limiting

Per connection, as in Swift: 5 invalid credentials -> locked 30 s (`tooManyAttempts`). Per IP, across connections: 5 failures -> 30 s lock, each further lock doubles (30, 60, 120, ... capped at 900 s); a locked IP is refused even with a valid credential; the level decays after 30 minutes without failures. The IP is the first `X-Forwarded-For` hop when `TRUST_PROXY=1`, otherwise the socket address. HTTP auth failures count toward the same IP limit (HTTP answers 429 with `Retry-After`).

### Admin commands are role-gated

`ClientMessage.admin` is accepted only from an OC device whose station is `admin` (Swift: `GameHost.adminCommand`, `HostError.notOC` otherwise). The Mac in Cloud mode and the iPad admin both sign in with `hello{credential:{"ocPin":{"_0":"<pin>"}}, station:{"admin":{}}}`.

## 3. HTTP routes (JSON, CORS not enabled)

Auth, where marked: header `X-Moonfall-Pin: <ocPin>` or `X-Moonfall-Secret: <pairing secret>` (server env `MOONFALL_PAIRING_SECRET`). The valid PIN is: the live host's `ocPin` when registry mode is `cloud`; the stored snapshot's `ocPin` when mode is `local` and a snapshot exists; otherwise env `MOONFALL_BOOTSTRAP_PIN`. Failure: `401 {"error":"..."}`; locked IP: `429`.

| Route | Auth | Request | Response |
|---|---|---|---|
| `GET /health` | none | | `{"ok":true}` |
| `GET /registry` | none | | `{"mode":"cloud"\|"local","updatedAt":<unix s>,"hasSnapshot":bool,"snapshotAt":<unix s>\|null}` |
| `PUT /registry` | pin or secret | `{"mode":"cloud"\|"local"}` | the registry object. `local` disconnects all sockets. `cloud` without an imported state keeps whatever live state exists |
| `PUT /snapshot` | pin or secret | snapshot body (below) | `{"ok":true,"snapshotAt":<unix s>}`. Cold backup only, never acted on |
| `GET /snapshot` | pin or secret | | snapshot body, or `404` |
| `POST /takeover` | none (PIN in body) | `{"pin":"1234"}` | `{"ok":true}`. Loads the latest snapshot as live state, sets mode `cloud`. `404` with no snapshot, `401` for a wrong PIN |
| `GET /takeover` | none | | accessible HTML page with a PIN field posting to `POST /takeover` |
| `PUT /import` | pin or secret | snapshot body | `{"ok":true}`. Loads it as live state and sets mode `cloud` (planned switch Mac -> cloud) |
| `GET /export` | pin or secret | | snapshot body of the live state (planned switch cloud -> Mac) |

Planned switch Mac -> cloud: `PUT /import` (with the secret or PIN), then `PUT /registry {"mode":"cloud"}` is optional (import already sets it); the Mac then stops listening. Cloud -> Mac: `GET /export`, load it into the Mac host, then `PUT /registry {"mode":"local"}`.

### Snapshot body

```
{
  "state": <HostState JSON exactly as Swift encodes it>,
  "selfies": [{"player":"<UUID>","jpeg":"<base64>"}],
  "map": <BoothMap JSON {"hash":"...","jpeg":"<base64>"}> | null,
  "mapJPEG": "<base64>" | null
}
```

`map` and `mapJPEG` are alternatives: the server uses `map.jpeg` if present, else `mapJPEG`, and always recomputes the hash. `GET /export` and `GET /snapshot` emit both. Body limit 64 MB.

## 4. Booth map

The server does not decode or resize images. `AdminCommand.setBoothMap(Data)` accepts JPEG or PNG (magic bytes) up to 8 MB, stores the bytes as received, and `BoothMap.hash` is the lowercase hex SHA-256 of the stored bytes (as `BoothMap.init(jpeg:)`; the field is named `jpeg` even for PNG). Anything else is `rejected("That file isn't an image the map can use.")`. The Mac should downscale before sending, as `BoothMapImporter` does.

## 5. Test fixtures the Swift side produces (`cloud/test/fixtures/`)

- `wire-*.json`: `{"type":"ClientMessage"|"ServerMessage"|"AdminCommand","json":<value as Swift encodes>}`. The TypeScript codec must decode and re-encode it to equal JSON.
- `trace-*.json`: `{"seed":N,"start":<GameEngine JSON>,"steps":[{"at":<reference-date seconds>,"command":<GameCommand JSON>|null,"advanceTo":<reference-date seconds>|null,"events":[<GameEvent JSON>],"state":<GameEngine JSON after the step>}]}`. A step with `command` runs `apply(command, at)`; a step with only `advanceTo` runs `advance(to:)`. A step that throws may carry `"error":"<RuleError case name>"`; state must then be unchanged. Set and dictionary order is not significant in comparisons.
