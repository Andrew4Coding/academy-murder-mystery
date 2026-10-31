import * as codec from "../codec/schemas.js";
import { DecodeError } from "../codec/combinators.js";
import { makeBoothMap, type Snapshot } from "../host/host.js";

export function parseSnapshot(body: unknown): Snapshot {
  if (typeof body !== "object" || body === null) throw new DecodeError("snapshot must be an object");
  const raw = body as Record<string, unknown>;
  const state = codec.hostState.dec(raw.state, "state");
  const selfies = new Map<string, Buffer>();
  if (raw.selfies !== undefined && raw.selfies !== null) {
    for (const selfie of codec.selfieList.dec(raw.selfies, "selfies")) selfies.set(selfie.player, selfie.jpeg);
  }
  let map: Snapshot["map"];
  if (raw.map !== undefined && raw.map !== null) {
    map = makeBoothMap(codec.boothMap.dec(raw.map, "map").jpeg);
  } else if (typeof raw.mapJPEG === "string") {
    map = makeBoothMap(Buffer.from(raw.mapJPEG, "base64"));
  }
  return { state, selfies, map };
}

export function serializeSnapshot(snapshot: Snapshot): unknown {
  return {
    state: codec.hostState.enc(snapshot.state),
    selfies: [...snapshot.selfies].map(([player, jpeg]) => codec.selfie.enc({ player, jpeg })),
    map: snapshot.map ? codec.boothMap.enc(snapshot.map) : null,
    mapJPEG: snapshot.map ? snapshot.map.jpeg.toString("base64") : null
  };
}
