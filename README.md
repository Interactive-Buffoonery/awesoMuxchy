# awesoMux Linux

This private repository is the working home for the Linux edition of awesoMux.
The active implementation is one native SwiftGtk4 application backed by the
shared awesoMux-owned Ghostty shim:

- `swift-gtk/` is the active application.
- `rust-gtk/` is a dormant fallback. Activate it only after Sarah explicitly
  decides to switch tracks.

The Electron prototype is a historical behavior reference, not a second
development track or a required checkout. Its evidence and preservation are
recorded in [the Electron handoff](docs/electron-behavior-handoff.md) and
[the Linux consolidation note](docs/linux-consolidation.md). The macOS awesoMux
project remains the read-only authority for product behavior and wording.

Shared product contracts, exact wording, visual references, resources, the
canonical Ghostty pin, and the Ghostty GTK shim remain language-neutral for
the dormant Rust fallback.

Read `AGENT_PROMPT.md` first, then the prompt inside the selected track. Start
with `swift-gtk/AGENT_PROMPT.md`. Do not work on both tracks at the same time
unless Sarah explicitly asks for a comparison.

Progress screenshots are stored under:

```text
artifacts/visual-qa/swift-gtk/
artifacts/visual-qa/rust-gtk/
```

## Visual QA index

| Date | Track | Milestone | Evidence |
| --- | --- | --- | --- |
| 2026-08-28 | SwiftGtk4 | Pinned Ghostty renders two independent terminal surfaces in one native GTK4 window. Prompts are intentionally sanitized. | [Open full-resolution PNG](artifacts/visual-qa/swift-gtk/progress/04-terminal-lifecycle/real-terminal-split-x11.png) |

![SwiftGtk4 terminal integration milestone](artifacts/visual-qa/swift-gtk/progress/04-terminal-lifecycle/real-terminal-split-x11.png)

Near-term work reconciles the recorded GTK baseline, makes terminal lifecycle
reliable, then integrates `amx`, real agent state, and daily-use validation.
Full macOS feature and visual parity remains the product goal. See
[ADR 0004](docs/adr/0004-consolidate-linux-development.md) for the sequence
and boundaries.

This repository intentionally has no CI. All builds, tests, packaging checks,
and visual QA run locally. Desktop behavior and visual evidence must be checked
on the target i5GamingPC under the relevant display system. The current
development workspace is `~/development/awesomux-linux-gtk` on pinguchy;
build and source checks that do not require a desktop can run there. Do not add
GitHub Actions or another remote build service.
