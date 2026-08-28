# 0001 — SwiftGtk4 is the active Linux track

- Status: Accepted
- Date: 2026-08-28
- Deciders: Sarah (repository prompt)

## Context

The repository contains SwiftGtk4 and Rust/gtk4-rs tracks. The root phase list
contains one stale “Rust workspace” phrase, while all track-selection rules say
SwiftGtk4 is first and Rust is an explicit fallback.

## Decision

Build only `swift-gtk/`. Shared product contracts and `ghostty-shim/` remain
language-neutral. Rust stays untouched unless Sarah activates it after an
evidence-backed failed Swift viability checkpoint.

## Consequences

Phase 2 means the SwiftPM/GTK4 workspace. No language switch may hide or delete
Swift evidence.
