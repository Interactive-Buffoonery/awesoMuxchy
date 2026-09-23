# 0001 — SwiftGtk4 is the active Linux track

- Status: Accepted
- Date: 2026-08-28
- Amended: 2026-09-23, by Sarah: SwiftGtk4 is the sole implementation.
- Deciders: Sarah (repository prompt)

## Context

The Linux application uses SwiftGtk4 with a shared Ghostty shim. Sarah has
chosen to keep a single application implementation in this repository.

## Decision

Build only `swift-gtk/`. Shared product contracts and `ghostty-shim/` remain
language-neutral. Maintain one SwiftGtk4 implementation shared across editions.

## Consequences

Phase 2 means the SwiftPM/GTK4 workspace. No language switch may hide or delete
Swift evidence.
