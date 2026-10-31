---
id: 0037
title: Booth details
status: implemented
owner: AND
app: all
created: 2026-10-31
updated: 2026-10-31
related: [0030-booth-map.md, 0035-cloud-host-server.md, 0036-host-switching.md, 0024-dead-families-keep-tasks.md]
---

# 0037: Booth details

## Summary

The booths from the participant booth guide (Booth 1 Decipher Clue to Booth 7 Gate Unlock, plus Sabotage Booth 6 Scary Memory and Sabotage Booth 7A Heist Plan) become editable data instead of a hardcoded list. Players tap a booth on their phone and get a sheet with a picture, how many families fit, the time limit, the task, numbered steps and when the booth counts as done. The OC edits all of it, and the pictures, in a new Booths view on the Mac and the OC iPad.

## User stories

- As a **player**, I want to tap a booth and read exactly what to do there, so that I don't have to ask a committee member.
- As an **OC**, I want to edit booth text and pictures in the app, so that the guide stays right without a new build.
- As an **OC**, I want staff notes that players never see, so that reminders for the MC live next to the booth.

## Acceptance criteria

- [x] **AC1 Seed**: Given a fresh host, then the nine booths from the participant guide exist, in English, with capacity, duration, task, steps and a done-when line. Each has a default picture (flat abstract art in the logo palette, 16:9, no text; the two sabotage booths use a red alarm variant). The guide has no locations or staff notes, so those start empty.
- [x] **AC2 Detail sheet**: Given a booth row on the phone, when the player taps it, then a sheet shows the picture (if any), the title, location, capacity and duration (when set), task, numbered steps and "Done when".
- [x] **AC3 Where**: The booth list is on the Role tab ("Your tasks", every family, alive or not) and in the family lobby.
- [x] **AC4 Edit**: Given the Booths view (Mac sidebar, iPad tab), when the OC changes any text field, steps or notes and saves, then every connected device updates.
- [x] **AC5 CRUD and order**: The OC can add, delete and reorder booths, and restore the guide defaults (this also resets every picture to the default one).
- [x] **AC6 Picture**: The OC can set, replace and remove one picture per booth (any image, stored as JPEG, long side at most 1600 px).
- [x] **AC7 Staff notes**: Staff notes are sent only to the admin OC station. Phones and other OC stations receive them empty.
- [x] **AC8 Admin only**: Only the Mac and the admin iPad station can edit. Editing works at any time, including during a game, and open sheets follow the edit.
- [x] **AC9 Persistence**: Booths survive `newGame` and a host restart. They are not part of `GameState`.
- [x] **AC10 No resend**: A client that holds the host's current revision is not sent the booths again.
- [x] **AC11 Cloud**: The cloud host stores and serves the same catalog, and a snapshot takeover carries it.

## UX

| State | What the user sees |
|---|---|
| Phone, list | the booth title (it carries its own number, e.g. "Booth 1 – Decipher Clue") with the task as subtitle and a chevron; one VoiceOver element per row, hint "Opens the booth details" |
| Phone, sheet | Picture on top (when set), title, facts card (location, capacity, duration; empty ones hidden), Task, How to join (numbered), Done when, Done button |
| Mac and iPad, Booths | Booth list on the left (drag to reorder, swipe or menu to delete), editor on the right with Picture, Details, Task, How to join, Staff notes, Preview, Revert, Save |
| Empty list | "No booths", with Add and Restore Defaults in the toolbar |

Accessibility: text carries meaning on its own, section titles are headers, the editor's step and note remove buttons are 44 pt capable icon buttons with labels, and nothing relies on colour.

## Data

No SwiftData change. `GameState`, `Family.tasks`, `GameView.tasks` and `AdminFamilyRow.tasks` are gone: every family always sees every booth, so there was nothing left to track per family (the field decodes from stored games because unknown keys are ignored). `WireVersion` goes to 3 because older clients cannot decode the new `GameView` or `ServerMessage.booths`.

The Mac keeps the catalog as `booths.json` in Application Support (`FileBoothStore`) with a random `revision` that changes on every edit. `Hello.boothsRevision` lets the host skip the catalog for an up-to-date client. `HostSnapshot.booths` carries it to the cloud and back.

## Constraints check

- [x] Fits `specs/constraints.md`: no new dependency (ImageIO, CryptoKit, PhotosUI), no personal data, no roles or families in booth data.
- [x] Booth data is public venue information, like the map. It is never sent to the Public Display.

## Out of scope

- Several pictures per booth, markdown or rich text, translations.
- Per-family booth progress or stamping (ADR 0008).
- Importing from the PDF.

## Open questions

-

## Implementation notes

- Model, defaults and store: `Shared/Booths/`. Host: `GameHost+Booths.swift` (`catalog(for:)` strips staff notes). Wire: `ServerMessage.booths`, `AdminCommand.saveBooth/deleteBooth/reorderBooths/setBoothImage/removeBoothImage/restoreBoothDefaults`.
- UI: `Shared/Features/Booths/` (`BoothDetailView`, `BoothsView`, `BoothEditorView`), `iOS/Features/Booths/BoothListSection.swift`, `Admin/Features/Booths/BoothsAdminView.swift`, `AdminiPad/BoothsTab.swift`. The iPad downsizes a picked image before sending.
- Default pictures: `scripts/booth-art/` (`generate.py` writes the SVGs in `svg/`, `render.sh` renders them to `Shared/Resources/BoothArt/*.jpg` and to `cloud/src/host/booth-art.ts`). Swift loads the JPEGs from the app bundle, the cloud embeds them as base64, so both hosts seed byte-identical pictures. A host that already stored its catalog keeps it until Restore Defaults.
- Saving a booth ignores the `image` it carries: pictures change only through the image commands.
- Tests: `Tests/Shared/BoothCatalogTests.swift`; wire fixtures regenerated for the cloud port.
