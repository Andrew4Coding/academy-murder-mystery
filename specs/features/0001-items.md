---
id: 0001
title: Items reference feature
status: deprecated
owner: AND
app: all
created: 2026-10-22
updated: 2026-10-22
related: [decisions/0001-project-foundation.md]
---

# 0001: Items reference feature

## Summary

A small list, detail and editor feature that exercises every architectural layer: SwiftData schema, repository, view models, views, and tests. It is the pattern new features copy. Replace it, or delete it with its tests, once real features exist.

## User stories

- As a **user**, I want to add, edit and delete items, so that I can keep a simple list.

## Acceptance criteria

- [x] **AC1**: Given saved items, when the list loads, then all items appear, newest first. (`ItemListViewModelTests.loadPopulatesItems`)
- [x] **AC2**: Given the list, when I delete an item, then it disappears. (`ItemListViewModelTests.deleteRemovesItem`)
- [x] **AC3**: Given the editor, when the title is blank, then Save is disabled. (`ItemEditorViewModelTests.blankTitleCannotBeSaved`)
- [x] **AC4**: Given an existing item, when I edit and save it, then it updates in place. (`ItemEditorViewModelTests.savingExistingItemUpdatesInPlace`)
- [x] **AC5**: Given the SwiftData store, when an item is inserted, then it can be fetched back. (`SwiftDataItemRepositoryTests.insertThenFetchRoundTrips`)

## UX

| State | What the user sees |
|---|---|
| Empty | "No Items" with a hint to tap + |
| Content | list of titles with notes previews |
| Error | alert "Something went wrong" |

## Implementation notes

- `Shared/Features/Items/*`, `Shared/Data/ItemRepository.swift`, `Shared/Data/Schema/SchemaV1.swift`
- Navigation is per target, in each target's `App/RootView.swift`.
