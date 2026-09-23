# awesoMuxchy

This public repository is the working home for the shared Linux awesoMux app
and its planned Omarchy edition, **awesoMuxchy**. The edition shares the runtime
and product implementation; Omarchy appearance, shortcuts, desktop integration,
and packaging are tracked in the
[awesoMuxchy Linear project](https://linear.app/interactive-buffoonery/project/awesomuxchy-190ce1959bdf).
See [the edition decision](docs/adr/0005-awesomuxchy-omarchy-edition.md).
The active implementation is one native SwiftGtk4 application backed by the
shared awesoMux-owned Ghostty shim:

`swift-gtk/` is the sole application implementation.

The Electron prototype is a historical behavior reference, not a second
development track or a required checkout. Its evidence and preservation are
recorded in [the Electron handoff](docs/electron-behavior-handoff.md) and
[the Linux consolidation note](docs/linux-consolidation.md). The macOS awesoMux
project remains the read-only authority for product behavior and wording.

Shared product contracts, exact wording, visual references, resources, the
canonical Ghostty pin, and the Ghostty GTK shim are shared across editions.
The shim retains a narrow, language-neutral C ABI.

Read `AGENT_PROMPT.md` first, then `swift-gtk/AGENT_PROMPT.md`.

## Build and run locally

The setup below is on `chore/consolidate-linux-development` until merged.
Clone that branch with its pinned Ghostty and zmx submodules (or run
`git submodule update --init --recursive` in an existing clone):

```sh
git clone --branch chore/consolidate-linux-development --recurse-submodules https://github.com/Interactive-Buffoonery/awesoMuxchy.git
cd awesoMuxchy
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

Existing checkouts may keep their `awesomux-linux-gtk` folder name. Only the
remote URL needs to change; build scripts locate the repository relative to
their own paths. The executable is still named `awesomux`.

The development app uses `.build/dev-profile/` for its configuration and state.
Shells opened inside it currently inherit that profile and the local build
environment, so their normal CLI configuration can differ. The complete
preflight gate includes desktop checks and needs a suitable display; see the
development guide for prerequisites and the exact scope. A debug build and
native Wayland launch with a real Ghostty shell have been checked on pinguchy.
Omarchy is the baseline Linux platform. Acceptance requires real desktop and
daily-use validation on Omarchy/Hyprland; if it does not run well there, it does
not pass. The recorded smoke check alone does not establish acceptance.

Progress screenshots are stored under:

```text
artifacts/visual-qa/swift-gtk/
```

## Visual QA index

| Date | Track | Milestone | Evidence |
| --- | --- | --- | --- |
| 2026-08-28 | SwiftGtk4 | Pinned Ghostty renders two independent terminal surfaces in one native GTK4 window. Prompts are intentionally sanitized. | [Open full-resolution PNG](artifacts/visual-qa/swift-gtk/progress/04-terminal-lifecycle/real-terminal-split-x11.png) |

![SwiftGtk4 terminal integration milestone](artifacts/visual-qa/swift-gtk/progress/04-terminal-lifecycle/real-terminal-split-x11.png)

Near-term work reconciles the recorded GTK baseline, makes terminal lifecycle
reliable, then integrates `amx`, real agent state, and daily-use validation.
Shared product behavior follows the macOS reference, with deliberate Omarchy
presentation and integration differences documented under
[ADR 0005](docs/adr/0005-awesomuxchy-omarchy-edition.md). See
[ADR 0004](docs/adr/0004-consolidate-linux-development.md) for the foundation
sequence and boundaries.

Build and test verification remains local. All builds, tests, packaging checks,
and visual QA run locally. Desktop behavior and visual evidence must be checked
in a real Omarchy/Hyprland session. The current
development workspace is `~/development/awesomux-linux-gtk` on pinguchy;
build and source checks that do not require a desktop can run there. Do not add
GitHub Actions or another remote build service. Sarah's separately authorized
repository code-review tools are an exception to the automation restriction;
they do not replace `./script/preflight.sh`.
