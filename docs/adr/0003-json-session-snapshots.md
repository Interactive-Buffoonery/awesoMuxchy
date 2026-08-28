# 0003 — Linux preserves JSON session snapshots

- Status: Accepted
- Date: 2026-08-28
- Deciders: macOS ADR-0005; Linux port contract

## Context

The current macOS product persists a nested, versioned `SessionSnapshot` as
profile-scoped JSON with defensive decoding, quarantine, owner-only storage,
and bounded recovery archives.

## Decision

Linux keeps the JSON snapshot model and semantics. It does not introduce SQLite
for the existing restore graph. Linux paths follow XDG conventions, but schema,
migrations, size/depth limits, atomic replacement, archive retention, and the
recovery write gate remain product contracts.

## Consequences

The storage path is a recorded platform difference; restore behavior is not.
Files and directories must be owner-only (`0600`/`0700`).
