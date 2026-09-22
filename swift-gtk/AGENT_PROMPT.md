# Build the SwiftGtk4 edition of awesoMux Linux

Read the repository-root `AGENT_PROMPT.md` completely before following this
track-specific prompt. All root source, safety, GitHub, screenshot, parity, and
macOS read-only boundaries apply here.

You are implementing the active Linux application in `swift-gtk/` of this
repository. The current development workspace is on pinguchy; i5GamingPC is
the target for desktop and visual verification.

## Goal

Build the complete Linux edition of awesoMux as a native Swift and GTK4
application using SwiftGtk4 and the repository's shared awesoMux-owned Ghostty
GTK shim. It must feel like the current macOS awesoMux, not like a GTK sample or
a renamed Ghostty window.

SwiftGtk4 is an intentional experiment with a real path to production. Do not
stop after proving that a window opens. First prove the risky lifecycle and
toolchain boundaries, then continue into the full product if they hold.

## Required stack

- The current stable Swift toolchain supported on Ubuntu/Pop!_OS 24.04
- Swift Package Manager
- SwiftGtk's GTK4 branch or an awesoMux-controlled fork, pinned to exact commits
- GTK4, not GTK3
- the shared `ghostty-shim/` through its narrow C ABI
- canonical Ghostty pinned once at the repository root
- Swift Testing for new pure logic where practical
- XCTest only where a required tool lacks Swift Testing integration

Do not use SwiftUI, AppKit, Catalyst, Electron, xterm.js, or a web-rendered
application shell. Do not recreate the Ghostty shim inside this folder.

## Dependency safeguards

SwiftGtk currently relies on generated bindings and branch-based dependencies.
Make the build reproducible:

- pin SwiftGtk and every related binding/generator dependency to exact commits
- commit `Package.resolved`
- record the pins and licenses in `DEPENDENCIES.md`
- do not float on `main`, `gtk4`, or another moving branch after evaluation
- do not suppress warnings repository-wide
- do not add CI or GitHub Actions; all Swift and GTK verification runs locally
  and desktop verification runs on i5GamingPC
- treat a missing generated binding as a real integration gap
- prefer a small local C bridge for a missing GTK function over a broad fork
- if a SwiftGtk fork becomes necessary, document every carried change and why

Do not install Swift, GTK development packages, or generator dependencies with
`sudo` until Sarah approves the exact package list.

## Swift and GTK design

- Keep all GTK object creation, mutation, and destruction on one documented UI
  executor or main-thread boundary.
- Do not pass GTK objects into background Swift tasks.
- Do not declare generated GTK types `Sendable` merely to silence Swift 6.
- Isolate any unavoidable `@unchecked Sendable` declaration, explain its
  safety argument, and test it under concurrent terminal output.
- Contain `OpaquePointer`, `UnsafeMutableRawPointer`, `Unmanaged`, C function
  pointers, and GObject ownership inside a thin wrapper layer.
- Disconnect GTK signals before releasing their Swift owners.
- Ensure Ghostty wakeups cannot call a pane after that pane begins teardown.
- Avoid global mutable terminal state. Every pane owns an explicit surface
  handle and lifecycle state.
- Use Swift value types for durable product models when that remains clear and
  efficient.
- Do not imitate SwiftUI architecture mechanically. Use GTK patterns where
  they are required while preserving awesoMux's product model.

## Vertical-slice baseline

Reconcile the existing implementation and evidence against this baseline
before continuing broad product work. Do not assume an item is complete from
a screenshot or source inspection alone:

1. A SwiftPM executable opens a real GTK4 application window.
2. It links to the shared Ghostty shim through a stable C module.
3. One real Ghostty terminal renders inside a GTK4 surface.
4. A second terminal surface can run concurrently.
5. Both surfaces accept keyboard, composed Unicode input, mouse, clipboard,
   scroll, focus, and resize events.
6. The application can create, close, and recreate surfaces repeatedly.
7. Closing one busy terminal cannot crash or freeze the other.
8. Ghostty background wakeups are delivered safely to the GTK thread.
9. A minimal sidebar changes the focused terminal and action routing follows
   that focus.
10. The window and terminal have useful AT-SPI names, roles, and focus state.
11. The executable launches outside `swift run` with all resources found.
12. A real screenshot and comparison note are recorded under
    `artifacts/visual-qa/swift-gtk/` and uploaded to the verified private
    repository under the existing visual-QA authorization.

Add a repeatable lifecycle stress test. Exercise at least 100 create/use/close
cycles and multiple busy surfaces. Check for crashes, hangs, callbacks after
destruction, and steadily increasing memory.

## Swift viability checkpoint

After the vertical slice, write `VIABILITY.md` with evidence for:

- build reproducibility
- GTK API coverage
- Ghostty callback safety
- GObject and Swift ownership clarity
- Swift 6 concurrency warnings and resolutions
- input-method correctness
- accessibility feasibility
- debug experience
- clean packaging feasibility
- remaining unsafe or raw C code
- known SwiftGtk changes we would have to maintain

SwiftGtk passes when the lifecycle code is understandable, repeatably stable,
and does not require widespread unsafe escape hatches or permanent suppression
of compiler warnings.

If it passes, continue through terminal reliability, `amx` persistent
sessions, real agent integration, and daily-use validation before extending
the remaining full-parity work. Do not stop at the checkpoint. See
`../docs/adr/0004-consolidate-linux-development.md`.

If it appears unsuitable, do not delete or hide the Swift work and do not
silently switch languages. Capture the failing evidence, update the root and
track status documents, upload the latest screenshots, and ask Sarah whether
to activate `rust-gtk/`.

## Porting from macOS Swift

The macOS repository remains read-only. You may port project-owned MIT logic
into this repository when it is genuinely platform-independent, preserving
license and attribution requirements. Do not assume a file is portable merely
because it is Swift.

Classify reference code before porting:

- pure value models and algorithms: candidates for careful porting
- Foundation-only services: audit every API on Linux
- Swift concurrency: audit executor and platform assumptions
- SwiftUI/AppKit/Combine/UserNotifications/Keychain/macOS menu code: rewrite
  behind Linux-specific interfaces
- user-facing strings and assets: use the shared product contract rather than
  maintaining a second hand-copied set in this folder

Do not edit the source macOS files to make them portable.

## Verification

Provide track-local commands for build, test, run, lifecycle stress, and
package checks. The root preflight must call them. At minimum run:

- `swift build`
- `swift test`
- strict compiler warnings for code owned by this repository
- GTK/Ghostty lifecycle integration tests
- a clean-build test with dependency pins resolved
- the root source-license and submodule checks
- real Wayland and X11 UI runs on i5GamingPC

Do not create a workflow to run these commands remotely. Record the local
command and result in the implementation status instead.

Keep `swift-gtk/IMPLEMENTATION_STATUS.md` current throughout the work.

Begin by checking installed Swift and GTK versions without modifying the
machine, reading the root product contract, and reconciling the vertical-slice
evidence with the current checkout. Build and source checks can run on
pinguchy. Record i5GamingPC desktop evidence as pending until a real target
run is possible.
