# Build awesoMux for Linux with GTK and an awesoMux-owned Ghostty shim

The current development workspace is `~/development/awesomux-linux-gtk` on
pinguchy. i5GamingPC remains the target machine for desktop and visual QA.

Your mission is to build a production-quality Linux version of awesoMux that
matches the current macOS awesoMux as closely as Linux allows. Use GTK4 for the
application and an awesoMux-owned Linux embedding shim around canonical
Ghostty. This is a complete product port, not a visual mockup and not a small
terminal demonstration.

This repository contains one active application and one dormant fallback:

- `swift-gtk/` is the active first implementation.
- `rust-gtk/` is the prepared fallback implementation.

The former Electron prototype is a historical reference, not an active Linux
implementation or a required checkout. Its preserved evidence and behavior
handoff are documented in `docs/electron-behavior-handoff.md` and
`docs/linux-consolidation.md`. Follow
`docs/adr/0004-consolidate-linux-development.md` for the current consolidation
decision.

Start with SwiftGtk4. Do not build both applications in parallel and do not
silently switch to Rust. The shared product contract and Ghostty shim must stay
language-neutral so verified work survives a later switch if SwiftGtk4 proves
unsuitable.

Continue through the full implementation plan. Do not stop after creating a
window, rendering one terminal, or reproducing the broad layout. Keep an
honest, current parity matrix and implementation-status document so another
agent can continue the work without repeating discovery.

## Product goal

The goal is that Sarah can move between macOS awesoMux and Linux awesoMux and
feel that she is using the same product. The Linux application must provide the
same awesoMux mental model, workspace and pane behavior, terminal quality,
agent awareness, commands, wording, visual identity, persistence, and recovery
behavior. The implementation language and Linux toolkit details are means to
that goal; they must not become visible differences in how the product feels.

This is not a generic GTK terminal bearing the awesoMux name. It is not a
Ghostty demo with a sidebar added. It is the Linux edition of awesoMux.

The finished application should let Sarah use Linux as her daily awesoMux
machine for local development, persistent terminal sessions, Claude Code,
Codex, Grok, Git context, SSH workspaces, Markdown/document work, and all other
features present in the pinned macOS reference. It should be dependable enough
that closing, restoring, resizing, splitting, reconnecting, or switching busy
workspaces does not lose work or route an action to the wrong pane.

## Non-negotiable boundaries

1. Make no changes of any kind to the macOS awesoMux repository. Treat it as a
   read-only product and behavior reference. Do not create branches, edit
   files, format files, commit, push, open issues, or open pull requests there.
2. Work in this GTK repository for the Linux implementation, apart from a
   separate read-only reference checkout and normal build caches.
3. Before and after every reference pass, verify that the macOS reference
   checkout is clean with `git status --short`. If it is not clean, stop and do
   not alter or clean it.
4. Never copy or inspect GPL or AGPL source while implementing this product.
   In particular, do not inspect or copy `douglas/cmux-gtk`; it is AGPL. Do not
   use code from any GPL Ghostty embedding project.
5. Do not copy code from `patcito/testty`; it has no visible license. Do not
   copy the Linux shim implementation from third-party forks. Public product
   descriptions and discussions may be used to understand feasibility, but
   write the awesoMux shim independently from canonical MIT Ghostty sources.
6. The canonical Ghostty source is `ghostty-org/ghostty`, which is MIT. Pin it
   as a Git submodule. Never commit the submodule's contents directly.
7. Do not change canonical Ghostty in place. Keep awesoMux-owned Linux changes
   as a small, reviewable patch series or wrapper layer in this repository,
   applied to a staged build copy. Keep the submodule checkout clean.
8. Do not use Electron, Chromium, xterm.js, node-pty, or the former Electron
   prototype as the implementation foundation. Use its preserved handoff and
   archive for historical Linux behavior evidence when needed.
9. Do not silently substitute `libghostty-vt` plus a new renderer. The chosen
   direction is the full embedded Ghostty runtime and renderer through an
   awesoMux-owned GTK shim.
10. The private GitHub repository and progress-screenshot uploads described
    below are authorized. Do not publish packages, open issues, open pull
    requests, post comments, change repository visibility, or push unrelated
    work without Sarah's explicit approval for that exact action. Local
    implementation and verification are authorized.
11. Do not install system packages or use `sudo` without first showing Sarah
    the exact packages and why each is required.
12. Do not weaken sandboxing, permissions, signing, or security boundaries to
    make development easier.
13. Do not add or configure CI. This repository must have no GitHub Actions,
    hosted CI, self-hosted runners, automated build services, required CI
    checks, workflow badges, or dependency-update automation. Do not create
    files under `.github/workflows/`. Run every build, test, lint, lifecycle,
    packaging, and license checks locally. Checks without a desktop requirement
    may run on pinguchy. Real desktop, Wayland/X11, and visual evidence must
    come from i5GamingPC. No CI does not mean no testing.

## Repository state

The private repository is:

`Interactive-Buffoonery/awesomux-linux-gtk`

`https://github.com/Interactive-Buffoonery/awesomux-linux-gtk`

Verify that `origin` points to this exact repository and that it remains
private before every push. Do not substitute another owner or repository.

If this folder is not already a Git repository, initialize it with `main` as
the branch. Screenshot and visual-QA index commits and pushes are explicitly
approved below. Do not commit or push other work without separate approval.

## Required reference material

Use a separate read-only checkout of the macOS reference. Do not assume a
machine-specific path; record the checkout location locally.

Clone from:

`https://github.com/Interactive-Buffoonery/awesomux.git`

Fetch the remote and use the current remote default branch as the product
reference. Record its exact commit in `REFERENCE_BASELINE.md`. Verify the
actual default branch instead of assuming it is `main`.

Read all instructions in that repository before using it. At minimum, read:

- `AGENTS.md`
- `.agents/AGENTS.md`, if present
- `CONTEXT.md`
- `README.md`
- `Package.swift`
- `docs/architecture.md`
- every ADR under `docs/adr/`
- `docs/ghostty-integration.md`
- `docs/amx-automation.md`
- `docs/shortcuts.md`
- `docs/ci.md`
- `docs/code-review.md`
- the relevant sources under `Sources/`
- the design tokens under `Sources/DesignSystem/`
- user-facing resources, localization files, icons, fonts, templates, and
  licenses under `Resources/`
- current GitHub issues only when a behavior is not settled in code, docs, or
  an ADR

Use `docs/electron-behavior-handoff.md` and the preserved prototype archive
only as secondary historical evidence. An Electron working checkout is not
required. The macOS reference is the authority for product behavior, wording,
command names, and visual identity.

## Define exact parity before implementation

Create `FEATURE_PARITY_MATRIX.md` before broad implementation. Inventory every
user-visible and behavioral feature in the current macOS reference. Each row
must include:

- feature or surface
- macOS source-of-truth file or documentation link
- exact user-facing wording involved
- expected behavior
- Linux implementation location
- parity status: `not started`, `partial`, `verified`, or `blocked`
- verification method and evidence
- any unavoidable platform difference

The matrix must cover at least:

- single-window application behavior
- vertical workspace sidebar
- workspace groups and ordering
- terminal panes and split-pane layouts
- focused-pane identity and routing
- persistent shell sessions through `amx`
- session manager and recovery flows
- new, close, rename, move, duplicate, and reorder behavior
- command palette and every command
- application menus and context menus
- keyboard shortcuts and keyboard cheat sheet
- settings and every setting currently exposed on macOS
- terminal search and navigation
- Git repository, branch, changes, and pull-request context
- bottom-bar behavior bound to the focused pane
- Claude Code, Codex, and Grok integrations
- agent running, waiting, completed, failed, and attention states
- notifications and notification actions
- scripted pane automation, including `amx send`, `amx history`,
  `AWESOMUX_AMX`, and `$ZMX_SESSION`
- remote SSH workspaces and both persistence modes described by the macOS ADRs
- Markdown and document panes
- file handoffs and Linux remote helper behavior where applicable
- accessibility names, descriptions, focus order, and keyboard operation
- confirmation dialogs, warnings, empty states, errors, and recovery language
- bundled fonts, icons, templates, and third-party licenses
- application launch, quit, restore, crash recovery, and update behavior
- packaging and desktop integration

Do not mark parity based only on appearance. A feature is verified only when
its real interaction works.

## Exact wording and visual identity

Use the exact current awesoMux product name, capitalization, command labels,
settings labels, dialog text, help text, accessibility wording, and error
language. Do not paraphrase or invent replacement copy when the macOS product
already defines it.

Maintain `shared/resources/text-baseline.json` containing the Linux app's required
user-facing text and its source location in the pinned macOS reference. Add an
automated check that detects accidental wording drift. Preserve plural forms
and localization boundaries rather than building strings through manual
singular/plural conditions.

Match the current macOS layout, spacing, colors, typography, iconography,
selection states, hover states, focused states, pane dividers, sidebar,
bottom bar, sheets, popovers, settings, and empty states as closely as GTK4
allows. Use the existing macOS screenshots and create comparable Linux
screenshots at the same window sizes.

### Screenshot progress loop

Screenshots are a required part of implementation, not final polish. After
every meaningful visual milestone:

1. Run the real GTK application on i5GamingPC. If the target machine is
   unavailable, mark desktop evidence pending and do not claim the milestone.
2. Put the app into representative states, including populated and empty
   states where both exist.
3. Capture screenshots at a recorded window size.
4. Save them under
   `artifacts/visual-qa/<track>/progress/<phase>/<descriptive-name>.png`, where
   `<track>` is `swift-gtk` or `rust-gtk`.
5. Compare them directly with the equivalent pinned macOS reference
   screenshots.
6. Inspect the actual image rather than assuming a successful launch means it
   looks correct.
7. Attach the screenshots to the active agent conversation so Sarah can see
   progress as it happens, following the same feedback loop used for
   `awesomux-linux-prototype`.
8. Update `artifacts/visual-qa/README.md` with the reference screenshot, Linux
   screenshot, window size, tested display system, implemented behavior,
   visible differences, and next correction.
9. Commit the new screenshots and their comparison notes with a focused
   Conventional Commit such as
   `docs(visual-qa): add split-pane progress shots`.
10. Push that screenshot commit to the private
    `Interactive-Buffoonery/awesomux-linux-gtk` repository so Sarah can inspect
    the images directly on GitHub as development proceeds.

Capture progress at minimum for the initial shell, real terminal, sidebar and
workspace groups, split panes, focused-pane bottom bar, settings, command
palette, session manager, keyboard cheat sheet, agent states, Git context, SSH,
Markdown/document panes, recovery states, and final parity pass.

The GitHub repository must remain private. Screenshot files and their visual-QA
index are explicitly approved for commit and push as work progresses. This
does not authorize changing visibility, posting screenshots to issues or pull
requests, publishing releases, or pushing unrelated code without separate
approval.

Use platform-native Linux behavior only where macOS behavior cannot be
reproduced correctly. Record every deliberate difference in
`PLATFORM_DIFFERENCES.md` with the reason and user effect. Do not use
"platform-native" as a reason for broad visual drift.

## Two-track implementation architecture

The repository has one shared product contract, one shared Ghostty shim, and
two isolated GTK application folders. SwiftGtk4 is the active choice. Rust is a
fallback that can use the same shim and product evidence without disrupting or
deleting the Swift work.

Use:

- GTK4 through SwiftGtk4 in `swift-gtk/`
- GTK4 through `gtk4-rs` in `rust-gtk/` if Sarah activates that track
- plain GTK4 widgets with an awesoMux-owned design system and CSS
- Libadwaita only for a narrowly justified platform facility; do not let its
  default visual language replace awesoMux's design
- canonical Ghostty as a pinned Git submodule at `vendor/ghostty`
- one shared, awesoMux-owned shim under `ghostty-shim/`
- a narrow C ABI between the shared shim and either application
- the maintained `Interactive-Buffoonery/zmx` fork, branded and invoked as
  `amx`, for persistent sessions where the macOS architecture requires it
- defensive, profile-scoped JSON session snapshots, as decided in
  `docs/adr/0003-json-session-snapshots.md`
- structured logging without commands, terminal contents, secrets, or private
  paths leaking by default

Use this repository shape:

```text
AGENTS.md
README.md
AGENT_PROMPT.md
REFERENCE_BASELINE.md
FEATURE_PARITY_MATRIX.md
IMPLEMENTATION_STATUS.md
PLATFORM_DIFFERENCES.md
shared/
  product-contract/
  resources/
    css/
    fonts/
    icons/
    text-baseline.json
ghostty-shim/
  include/
  src/
  tests/
swift-gtk/
  AGENT_PROMPT.md
  Package.swift
  Sources/
  Tests/
  IMPLEMENTATION_STATUS.md
rust-gtk/
  AGENT_PROMPT.md
  Cargo.toml
  crates/
  IMPLEMENTATION_STATUS.md
script/
patches/
  ghostty-linux-embedded/
vendor/
  ghostty/
  zmx/
tests/
artifacts/
  visual-qa/
    swift-gtk/
    rust-gtk/
```

Do not place Swift build products inside `rust-gtk/` or Rust build products
inside `swift-gtk/`. Do not duplicate the Ghostty patch series, copied product
text, fonts, icons, or reference screenshots between tracks. Each application
may have a thin language-specific wrapper around the shared C ABI.

Read the selected track's `AGENT_PROMPT.md` in full after this root prompt.
Start in `swift-gtk/`. Leave `rust-gtk/` as a prompt and clean fallback until
Sarah explicitly activates it.

## Build the shim independently

The shim must be awesoMux-owned code written from the canonical Ghostty source
and public API requirements. Its job is to make the full embedded Ghostty
runtime usable inside a GTK4 surface on Linux.

Keep its public interface small and stable. It should cover:

- global Ghostty initialization and shutdown
- configuration creation, loading, finalization, and release
- application runtime callbacks
- one Ghostty surface per awesoMux terminal pane
- a GTK4 `GtkGLArea` or another proven GTK4 OpenGL surface
- realization and OpenGL initialization
- correct cleanup when the GL display or widget is unrealized
- frame scheduling and Ghostty wakeups on the GTK main thread
- size, scale factor, and monitor changes
- Wayland and X11 operation
- keyboard press/release and modifier translation
- GTK input-method composition and committed text
- mouse buttons, movement, selection, hover, and scroll
- focus changes
- clipboard read, write, and confirmation flows
- title, working-directory, child-exit, bell, and other runtime actions
- terminal search and selection APIs needed by the product
- surface lifecycle safety during close, split changes, workspace switches,
  session restoration, and application quit
- multiple simultaneously active surfaces
- error reporting that does not crash the whole application

Do not expose GTK or Ghostty raw pointers broadly through either application.
Contain Zig and C interop inside the shared shim and each track's thin wrapper,
document why each unsafe operation is valid, and test lifecycle boundaries.

Keep the Ghostty patch series as small as possible. Prefer a wrapper using
existing public hooks. When a Ghostty internal change is unavoidable, place it
in a separately named patch with:

- purpose
- upstream Ghostty pin
- files affected
- reason a wrapper was insufficient
- test coverage
- expected rebase risk

Add a script that stages canonical Ghostty into a build directory, applies the
patches, builds `libghostty.so`, stages its resources, and verifies that the
submodule remains clean. Add a pin-update check that fails clearly when the
patches no longer apply.

## Product architecture rules inherited from awesoMux

- awesoMux is a native single-window sidebar and session shell. It is not a
  multi-window manager and not a tmux replacement.
- The focused pane owns repository, branch, agent, changes, pull-request, and
  action context.
- Model pane execution explicitly. Preserve the intent of
  `PaneExecutionPlan`, including local and remote identity.
- App, window, workspace, and pane commands belong to awesoMux menus, the
  command palette, and the shortcut catalog. Do not route Ghostty application
  actions as a second command system.
- Preserve the current persistence and runtime composition decisions unless a
  Linux platform constraint makes one impossible. Record any such constraint
  before changing behavior.
- Do not add compatibility layers for designs that have never shipped. This is
  pre-1.0 software.

## Implementation order

The immediate sequence is baseline reconciliation, terminal reliability,
`amx`, real agents, and daily-use validation. The full parity plan below remains
the product goal; work in dependency order and keep the application runnable
after each stage. Reconcile already completed work before repeating a phase:

1. Repository rules, documentation, baseline commit, full parity matrix, and
   architecture decision records.
2. SwiftPM workspace, GTK4 application shell, design tokens, resources, logging,
   and test harness.
3. Canonical Ghostty pin, staged build system, independently written Linux GTK
   shim, and one reliable terminal surface.
4. Multiple terminal surfaces, split layouts, focus routing, resize, close,
   cleanup, and stress tests.
5. Workspace sidebar, groups, ordering, commands, menus, and exact shortcuts.
6. State persistence, restoration, crash recovery, and versioned migrations.
7. `amx` persistent sessions, session manager, send/history automation, and
   terminal recovery.
8. Settings, command palette, search, keyboard cheat sheet, and supporting
   surfaces.
9. Agent integrations, pane-scoped agent state, notifications, and actions.
10. Git and pull-request context bound to the focused pane.
11. SSH workspaces, remote persistence modes, and file handoffs.
12. Markdown and document panes.
13. Complete accessibility pass with keyboard-only and screen-reader testing.
14. Linux desktop integration, packaging, licenses, security review, and
    release checks.
15. Full behavioral and visual parity audit against the pinned macOS baseline.

Do not declare a later phase complete while foundational terminal lifecycle or
data-loss issues remain unresolved.

## Testing and verification

Create automated tests for non-trivial logic and integration tests for risky
boundaries. At minimum verify:

- shell launch, output, input, exit, and restart
- Unicode, emoji, combining marks, wide characters, and input methods
- terminal resize and text reflow
- rapid resize and repeated split creation/removal
- multiple busy terminals producing output concurrently
- surface close during output and during GTK callbacks
- repeated workspace switching
- clipboard permission and confirmation paths
- keyboard shortcuts and command routing
- focus never being sent to the wrong pane
- persistence after clean quit and forced termination
- `amx` attach, detach, restore, send, and history
- agent state transitions and notification actions
- SSH disconnect, reconnect, host-key, and authentication failure paths
- Wayland and X11
- scaling at 100%, 125%, 150%, and 200% where the desktop permits it
- keyboard-only navigation
- AT-SPI names, roles, descriptions, focus order, and state changes
- packaging from a clean checkout
- Ghostty patch application from a clean submodule at the recorded pin

Provide a single local verification command, such as `./script/preflight.sh`,
that formats only owned files, runs static checks, tests, license checks,
submodule/patch checks, and a release build. Do not use repository-wide
formatters against vendored code.

`./script/preflight.sh` is the authority for verification. Do not mirror it in
a CI workflow or add remote automation to run it.

Maintain before/after screenshots under `artifacts/visual-qa/`. Do not claim
visual parity without actually running and inspecting the GTK application.

## Security and privacy

- Keep terminal contents and typed commands out of normal logs and crash
  reports.
- Keep the GTK/FFI boundary narrow and validate all lengths, pointers, enum
  values, and ownership rules.
- Avoid shell-string construction. Pass argument arrays to child processes.
- Treat repository paths, SSH destinations, clipboard data, notification
  contents, and agent output as untrusted input.
- Preserve SSH host-key verification. Never silently accept changed keys.
- Do not expose broad filesystem or process-control access through loosely
  typed message channels.
- Inventory every bundled dependency and reproduce all required third-party
  notices.

## Progress records

Keep the root `IMPLEMENTATION_STATUS.md` and the active track's own
`IMPLEMENTATION_STATUS.md` updated with:

- current phase
- completed work with verification evidence
- incomplete work
- known defects
- exact blockers
- commands run and results
- next dependency-ordered tasks

Update `FEATURE_PARITY_MATRIX.md` whenever behavior changes. A missing,
inaccessible, or untested area is a coverage gap, never a successful result.

## Definition of done

The selected production track is done only when:

- the Linux app is a real GTK4 application using the awesoMux-owned embedded
  Ghostty shim
- it builds from a clean checkout using documented commands
- it runs on Sarah's Pop!_OS 24.04 machine under both Wayland and X11
- all current macOS awesoMux user-facing features are implemented or an
  unavoidable Linux difference is explicitly documented and approved
- current macOS wording is reproduced exactly
- visual comparisons show a close match at equivalent window sizes
- terminal lifecycle, persistence, multi-pane use, agents, SSH, documents,
  accessibility, and packaging are verified
- the complete automated test suite and preflight pass
- all checks run locally, with desktop and visual verification on i5GamingPC,
  and the repository contains no CI workflows or remote build automation
- canonical Ghostty and zmx submodules remain clean and correctly pinned
- licenses and notices are complete
- the macOS awesoMux repository remains byte-for-byte untouched by this work
- no issue, pull request, package, release, visibility setting, or unrelated
  remote content has been created or changed without Sarah's explicit approval

Begin by reconciling the recorded GTK baseline against the checkout and the
preserved Electron behavior handoff. Then resolve terminal lifecycle and
reliability, integrate `amx` persistence, integrate real agent state, and
validate daily use on i5GamingPC. Continue toward the full parity matrix after
those foundations. Read `swift-gtk/AGENT_PROMPT.md` before implementation and
keep verification evidence current. Do not claim desktop work completed from
source inspection alone.
