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

## Build and run locally

The setup below is on `chore/consolidate-linux-development` until merged.
Clone that branch with its pinned Ghostty and zmx submodules (or run
`git submodule update --init --recursive` in an existing clone):

```sh
git clone --branch chore/consolidate-linux-development --recurse-submodules https://github.com/Interactive-Buffoonery/awesomux-linux-gtk.git
cd awesomux-linux-gtk
```

Follow [development setup](docs/development.md) to prepare repository-local
Swift 6.3.3, Zig 0.16.0, and the documented GTK/GIR and compatibility
dependencies. The scripts check prerequisites; they do not install system
packages. From the repository root, choose the command you need:

```sh
./script/dev.sh --build-only  # Compile the Swift/GTK app and Ghostty shim
./script/dev.sh --run-only    # Launch the existing debug build immediately
./script/dev.sh               # Build and launch the isolated development app
./script/dev.sh --test        # Run the local Swift package tests
./script/preflight.sh         # Run the complete local verification gate
```

The development app uses `.build/dev-profile/` for its configuration and state.
Shells opened inside it currently inherit that profile and the local build
environment, so their normal CLI configuration can differ. The complete
preflight gate includes desktop checks and needs a suitable display; see the
development guide for prerequisites and the exact scope. A debug build and
native Wayland launch with a real Ghostty shell have been checked on pinguchy.
Target i5GamingPC desktop and daily-use validation remain pending.

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
