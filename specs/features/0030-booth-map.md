---
id: 0030
title: Booth map
status: approved
owner: AND
app: all
created: 2026-10-30
updated: 2026-10-30
related: [0003-lan-host-transport.md, 0004-lobby-and-roles.md, 0012-join-and-families.md, 0016-oc-station-rework.md]
---

# 0030: Booth map

## Summary

The OC uploads a picture of the booth layout in Setup on the Mac. Every joined player sees it on their phone as a tappable card, and opens a full-screen viewer to pinch, pan and zoom. The OC iPad can open the same viewer, read-only. Players can find booths without asking an organiser.

## User stories

- As an **OC**, I want to upload the booth map once in Setup, so that every player has it on their phone.
- As a **player**, I want to open the map and zoom into it, so that I can find the next booth.
- As an **OC on the iPad**, I want to open the map, so that I can point a player to a booth.

## Acceptance criteria

- [ ] **AC1 Upload**: Given Setup on the Mac, when the OC chooses a PNG, JPEG or HEIC image, then it becomes the booth map, with a preview in the Booth map section.
- [ ] **AC2 Downscale**: Given an image larger than 3000 px on its long side, when it is imported, then it is stored as a JPEG with its long side at most 3000 px, and the aspect ratio is kept.
- [ ] **AC3 Reject**: Given a file that is not an image, when it is imported, then the map is unchanged and the OC sees an error.
- [ ] **AC4 Remove and replace**: Given a map, when the OC removes or replaces it, then every connected device updates and the old map is gone.
- [ ] **AC5 Persistence**: Given a map, when the host restarts or a new game starts, then the map is still there.
- [ ] **AC6 Delivery**: Given a map, when a player or the iPad signs in or reconnects, then it receives the map, and the map is pushed to connected devices when it changes.
- [ ] **AC7 No resend**: Given a client that already holds the map with the same hash, when it reconnects, then the host does not need the client to download it again (the client keeps the map it has and the hash shown is the same).
- [ ] **AC8 Optional**: Given no map, then Setup lists no issue about it, the game starts, and no card appears on any device.
- [ ] **AC9 Player card**: Given a map, when a player is in the lobby or the game (alive, killed or expelled), then the Family tab and the lobby show a Booth map card with a thumbnail, and tapping it opens the viewer.
- [ ] **AC10 Viewer**: Given the viewer, when the user pinches, drags or double-taps, then the image zooms between fit-to-screen and 6x, pans within its bounds, and double-tap resets to fit; Close dismisses it.
- [ ] **AC11 iPad**: Given a signed-in OC iPad and a map, then the Dashboard shows the card and opens the same viewer; the iPad cannot upload.
- [ ] **AC12 No leak**: The map is public venue information. It never appears on the Public Display, and carries no role, family or player data.

## UX

| State | What the user sees |
|---|---|
| Empty (Mac) | Booth map section with a Choose Image button and a note that it is optional |
| Content (Mac) | Preview, size in pixels, Replace and Remove buttons |
| Error (Mac) | Alert: "That file isn't an image the map can use." |
| Empty (phone, iPad) | No card |
| Content (phone, iPad) | Card with a thumbnail and the title "Booth map"; tap opens the full-screen viewer |
| Viewer | Black backdrop, image fitted, Close button at the top |

Accessibility notes: the card is one VoiceOver element labelled "Booth map, opens full screen"; the viewer image has the label "Booth map" and the hint "Pinch to zoom, double tap to reset"; Close and zoom controls are at least 44 pt. Zoom animation honours Reduce Motion. The viewer also has zoom in, zoom out and reset buttons so it works without a pinch gesture.

## Data

No SwiftData change and no schema version bump. The Mac keeps the map as one JPEG file in Application Support (`BoothMapStore`), outside `GameState`, so a new game never clears it. `ServerMessage.map(BoothMap?)` carries it, with a SHA-256 hash of the JPEG. `WireVersion` goes to 2 because older clients cannot decode the new message.

## Constraints check

- [x] Fits `specs/constraints.md` and the iOS and admin constraints: no cloud, Swift 6, no new dependency (ImageIO and CryptoKit only), no personal data.
- [x] No new dependency, no ADR needed.

## Out of scope

- Markers, "you are here", family positions or drawing on the map.
- PDF import.
- Showing the map on the Public Display.
- Uploading from the iPad or a phone.

## Open questions

-

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
