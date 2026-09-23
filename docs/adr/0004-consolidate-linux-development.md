# 0004 — Consolidate Linux development in the GTK repository

- Status: Accepted
- Date: 2026-09-22
- Deciders: Sarah

Updated by [ADR 0005](0005-awesomuxchy-omarchy-edition.md) for the shared
Omarchy edition, public repository rename, and Sarah-authorized code-review
tools. The consolidation and shared implementation decisions remain active.

## Context

Linux work has lived in a SwiftGtk4 repository and an earlier Electron
prototype. Maintaining two apparent implementation paths obscures the active
product direction and makes it easy to repeat discovery or treat prototype
behavior as the current authority. The GTK repository already has a shared
Ghostty shim and accepted decisions for SwiftGtk4 as the active track and JSON
session snapshots.

## Decision

This repository is the single working home for Linux awesoMux. `swift-gtk/`
is the sole GTK4 application, using the shared awesoMux-owned Ghostty shim.
The Electron prototype remains historical
product and behavior evidence; it is not a second implementation track, and
future GTK work does not require an Electron working checkout. Preserve its
useful evidence and repository history here before any later deletion of that
checkout. See [the behavior handoff](../electron-behavior-handoff.md) and
[the consolidation record](../linux-consolidation.md).

The macOS awesoMux reference remains read-only and authoritative for product
behavior, wording, and visual identity. Historical Electron behavior can
inform Linux-specific cases but does not override that reference. Existing
no-hosted-CI, source-license, Ghostty pin, privacy, and publishing boundaries
continue to apply; this decision grants no new remote publishing permission.

The current development workspace is `~/development/awesomux-linux-gtk` on
pinguchy. Local build, source, and documentation checks may run there. Real
desktop behavior, visual comparisons, and daily-use evidence must be gathered
in a real Omarchy/Hyprland session, as required by ADR 0005. If that evidence
is unavailable, record acceptance as pending. Other desktop runs, including
X11, are supplementary.

## Sequence and consequences

1. Reconcile the recorded GTK baseline, repository state, and inherited
   Electron behavior evidence, including any unresolved differences between
   local and remote commits.
2. Make embedded Ghostty terminal lifecycle, input, resize, focus, and recovery
   reliable under representative multi-pane use.
3. Integrate `amx` persistent sessions and verify attach, detach, restore,
   send, history, and recovery against the product contract.
4. Integrate real agent state and actions for Claude Code, Codex, and Grok,
   scoped to the focused pane.
5. Validate sustained daily use on Omarchy/Hyprland, then continue the full feature,
   accessibility, packaging, and visual parity program.

This sequence narrows the next milestone without reducing the final macOS
parity goal. Keep `IMPLEMENTATION_STATUS.md`, the Swift track status, and
`FEATURE_PARITY_MATRIX.md` honest about implemented, tested, and pending work.
