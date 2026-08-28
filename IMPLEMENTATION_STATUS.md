# Implementation status

Updated: 2026-08-28

## Current phase

SwiftGtk4 passed its language/toolkit viability checkpoint. Terminal lifecycle
and defensive snapshot recovery are verified. The permanent workspace sidebar
and both footer surfaces now carry live focused-pane, Git, GitHub, settings,
help, and agent context while preserving the compact reference geometry.

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
- Thirty-three Swift tests cover model mutations, exact command-catalog chord
  uniqueness, defensive snapshot limits, XDG profile paths, owner-only writes,
  current/previous recovery, and corrupt-file quarantine.
- Native GTK application actions and accelerators are generated from the same
  command catalog used by tests. Workspace and pane navigation route through
  the shared snapshot rather than a parallel UI-only selection model.
- The real app restored a profile-scoped snapshot across two launches and
  created owner-only current and previous files.
- The release integration harness asserts both real terminal surfaces publish
  focus callbacks; the full local preflight passes after this routing change.
- The real app now uses the reference sidebar hierarchy and shared
  38-point footer rhythm. Search, group disclosure, new-workspace creation,
  whole-workspace selection, focused-pane path routing, and the truthful
  zero-agent idle state are live rather than mock controls.
- Pure chrome projections keep fixed header/footer geometry for zero, one, and
  many rows; focused-pane context publication is identity/generation guarded,
  sanitized, and covered against stale results and long text.
- The focused-pane footer now resolves validated local repository roots,
  branches, dirty/ahead/behind state, open pull requests, actionable CI runs,
  installed editors, Files, and copy actions off the GTK thread. Git and `gh`
  use argv-only bounded processes with prompts disabled, capped output, hard
  timeout fallback, HTTPS-only remote actions, and stale-identity rejection.
- The sidebar footer now matches the reference control set: Quick Settings,
  Help & Feedback, live thinking/output/attention chips, total agents, and an
  expandable agent activity panel that routes back to the exact pane. Theme
  and notification-mute preferences persist as owner-only profile JSON.
- Real inspected footer screenshots cover a working Git repository and a
  two-agent thinking/needs-attention fixture. The full local preflight passes
  33 tests after the GLib main-loop publication and resolver hardening; the
  focused visual-QA commit is pushed as `e89d3bb`.
- The focused-pane footer now follows the reference's compact intrinsic
  geometry: 24-point path control, 10/11-point monospaced type hierarchy,
  5-point radii, low-opacity fills, state-colored half-point-equivalent
  hairlines, grouped branch/PR icons, and vertically centered chips. Repository
  roots display the exact `repo root` wording and nested paths become
  repo-relative; a real 1440 × 860 X11 capture was inspected and pushed in the
  focused visual-QA commit `9a092c9`.
- The sidebar host now uses a native GTK horizontal split with the reference
  296-point default, 60-point rail settlement, 250-point mode threshold, and a
  480-point terminal minimum. Width and last-expanded width are defensively
  normalized in the existing owner-only profile preferences, including
  backward-compatible loading of pre-width preference files. Dedicated rail
  contents, hover reveal, and side switching remain in progress. Native
  Collapse/Expand Sidebar and Hide/Show Sidebar commands use the reference
  Linux-mapped shortcuts; hiding first returns focus to the active terminal.
- The 60-point mode now owns a separate GTK rail rather than clipping expanded
  controls. It includes 40-point search/command-palette and creation controls,
  live workspace selection buttons, and a collapsed footer whose total-agent
  control cycles through the live pane roster. The expanded search field uses
  the exact `Search sessions` placeholder and an owned dark-theme text-node
  style. A trustworthy collapsed screenshot is still pending because the
  available raw X11 window capture does not composite client-side GTK damage.
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

1. Add the foreground-shell capability signal needed to gate inserted Git/gh
   commands as precisely as macOS does.
2. Implement product-level split/close/recreate commands and teardown-race coverage.
3. Complete collapsed/hidden/right-side sidebar presentation, then group
   creation, ordering controls, and dynamic menu enablement.
4. Add bounded/coalesced persistence writes, recovery UI, and forced-termination tests.
5. Continue through the root implementation order, capturing each required
   visual milestone.

The verified SwiftGtk4 baseline is committed locally as `260e917`. No
implementation source commit has been pushed; only explicitly allowed
visual-QA commits are on the remote.
