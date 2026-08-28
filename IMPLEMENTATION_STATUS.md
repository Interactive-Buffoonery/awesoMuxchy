# Implementation status

Updated: 2026-08-28

## Current phase

SwiftGtk4 passed its language/toolkit viability checkpoint. Phase 4 terminal
lifecycle is verified and production workspace/sidebar implementation is
active.

## Completed evidence

- The private origin, pinned read-only macOS baseline, Ghostty/zmx submodules,
  wording baseline, parity matrix, ADRs, and no-CI policy are verified.
- Verified repo-local Swift 6.3.3 and Zig 0.16.0 toolchains build the pinned
  dependency graph. The canonical Ghostty and zmx submodules remain clean.
- The staged Ghostty build, minimal Linux embedder patch, generated OpenGL
  loader, language-neutral C shim, and Swift wrapper module build and link.
- A native GTK4 window renders three independent real Ghostty surfaces on the
  supported X11/GLX path. Sidebar rows switch whole workspaces; Development
  owns a two-pane split and Review owns a separate terminal page.
- GTK IM context, keyboard, pointer, focus, resize, title, close, clipboard,
  accessibility-label, and main-thread wakeup bridges exist in the shim.
- Real GTK focus-enter/leave callbacks now cross the shim into Swift and update
  pane identity before awesoMux routes focused-pane actions.
- The standalone integration executable passed input, Unicode/emoji/combining
  and wide-character data, focus, resize, clipboard read/write, exit, and
  second-pane independence.
- Three standalone stress runs each passed 100 cycles with two concurrently
  busy, successfully realized surfaces. Peak RSS was 307,208 KiB on the first
  driver-cache warm-up and 245,056/244,844 KiB on the following runs.
- Nine Swift model, mutation, validation, and owner-only persistence tests
  pass.
- The release integration harness asserts both real terminal surfaces publish
  focus callbacks; the full local preflight passes after this routing change.
- A real inspected screenshot and comparison index were pushed in focused
  visual-QA commits `4149963` and `01cc8d7`.

## Active constraints

- Native GTK Wayland cannot create the required desktop OpenGL context on the
  current COSMIC/NVIDIA GTX 1080 Ti stack. X11/GLX under XWayland is the current
  runtime path; the failed native path is recorded in
  `PLATFORM_DIFFERENCES.md` and remains a high-priority investigation.
- `libatk1.0-dev` is not installed system-wide while Sarah is away. The build
  uses only its downloaded development archive in `.build/sysroot`; the system
  can be normalized later without blocking work.
- Real desktop IME composition, mouse selection/hover, primary selection,
  Orca/AT-SPI inspection, and close-during-pending-clipboard tests still need
  explicit runtime coverage.

## Next work

1. Finish product-level focus/close/recreate and teardown-race coverage.
2. Connect the workspace/sidebar UI to persisted state and command routing.
3. Implement defensive profile-scoped session restoration and crash recovery.
4. Continue through the root implementation order, capturing each required
   visual milestone.

No implementation source has been committed or pushed; only the explicitly
allowed visual-QA screenshot/index commits are on the remote.
