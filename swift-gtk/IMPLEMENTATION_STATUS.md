# SwiftGtk4 implementation status

Updated: 2026-08-28

## Current phase

Viability, defensive restoration, and the enriched sidebar/terminal footer
milestone are complete and locally verified. The terminal footer's reference
geometry and state styling have also passed a real-window visual correction.

## Completed

- Swift 6.3.3 builds the pinned SwiftGtk dependency graph without warnings in
  owned Swift code or concurrency-suppression flags.
- `AwesoMuxTerminal` contains every raw Ghostty handle and exposes owned Swift
  runtime/surface objects to the app and integration harnesses.
- Two concurrent real terminals render on X11/GLX, receive focus and resize,
  and support UTF-8 input plus GTK clipboard read/write callbacks.
- GTK signals are disconnected before release; pending clipboard reads keep
  the host allocation alive and cannot complete against a destroyed core.
- GTK focus-enter/leave events cross the language-neutral callback table and
  update Swift pane ownership; sidebar selection and direct pane clicks now
  converge on the same focused-surface route.
- The standalone terminal integration harness passes pane independence,
  process exit, callbacks from both focused surfaces, resize, Unicode, and
  clipboard read/write.
- Three 100-cycle, two-busy-surface stress runs pass with stable warmed peak
  memory.
- Accessible pane labels/descriptions and keyboard-operable sidebar buttons
  establish a usable AT-SPI path for the first slice.
- Debug and release executables link outside `swift run` through the staged
  shim and pinned Ghostty runtime.
- The real screenshot, direct GitHub link, and comparison notes are uploaded.
- Sidebar rows switch complete workspaces through a native GTK stack. The
  Development workspace owns a two-pane split and Review owns an independent
  terminal, all without exposing Ghostty handles to application code.
- Thirty-three state tests cover grouped snapshots, defensive limits, selection,
  ordering, split/focus/close mutations, command chords, round trips,
  profile-scoped paths, owner-only persistence, quarantine, and recovery.
- The app renders its GTK stack/sidebar directly from `SessionSnapshot`, and
  native GTK actions plus accelerators share `CommandCatalog` with tests.
- A real two-launch check restored profile state and maintained `0600`
  current/previous snapshots; invalid and oversized files are moved into a
  `0700` quarantine with `0600` file permissions.
- A fixed 188-point native sidebar now has a separate header, scrolling group
  body, and pinned 38-point idle footer. Search, disclosure, workspace creation,
  row selection, hover/focus styling, density, and metadata use the live
  `SessionSnapshot` state.
- Every workspace page owns a 38-point path bar below its real Ghostty surface.
  Direct pane focus and sidebar switching update sanitized focused-pane context;
  generation checks reject stale publication. Validated local repositories add
  branch, dirty/ahead/behind, PR, and failing/running CI chips plus branch,
  browser, copy, Files, and discovered-editor actions. Remote panes suppress
  local actions and show a remote indicator.
- The pinned sidebar footer now includes Quick Settings, Help & Feedback,
  state-prioritized agent counts, and an expandable activity list that returns
  to the exact workspace/pane. System/Light/Dark and notification mute persist
  in owner-only profile-scoped JSON.
- Footer resolution runs concurrently off the GTK thread and publishes through
  GLib's main context. Git/`gh` execution is non-shell, bounded, prompt-free,
  output-capped, HTTPS-validated, and guarded against stale pane identity.
- The path control and status chips now use the reference's intrinsic sizing,
  spacing, radii, opacity, tone-specific borders, and 10/11-point monospaced
  hierarchy. Repository roots render as `repo root`; nested directories render
  repo-relative, and disappearing Git/PR/CI state clears stale chips.
- The fixed 188-point host has been replaced by a native GTK split using the
  reference 296-point expanded default, 60-point collapsed settlement, and
  250-point mode threshold while reserving at least 480 points for terminal
  content. The committed width and last expanded width persist defensively and
  legacy preference files load with reference defaults. Configured right-side
  host mode mirrors split children, divider math, titlebar order, resize
  ownership, and edge borders. Hidden mode reparents the live sidebar into a
  GTK overlay so the 40-point edge reveal preserves terminal geometry, holds
  while occupied, and dismisses after the reference 220 ms grace. Needs
  Attention exposes a tested, side-aware dormant edge tab. Collapse/Expand
  Sidebar and Hide/Show Sidebar are native GTK
  actions with reference Linux-mapped shortcuts; hiding restores terminal
  focus and persists the hidden state.
- Collapsed mode now renders a dedicated 60-point GTK rail instead of a clipped
  expanded hierarchy. Its 40-point search control opens a working filtered
  command palette, its create control and workspace buttons route through the
  authoritative session state, and its footer cycles through live agent panes.
  The expanded search text node has an owned theme style and the exact
  `Search sessions` placeholder. Full visual acceptance remains pending.
- Search visibility is now driven by a pure `SidebarSearchProjection` that
  normalizes whitespace/diacritics and searches group/workspace/pane titles,
  paths, local/remote identity, agent/provider names, and state vocabulary in
  deterministic render order. The expanded sidebar includes the reference
  no-matches copy and a working `Clear search` action. Escape clears or returns
  focus to the terminal, Up/Down moves a distinct current-result outline, and
  Return selects that workspace using projection order. Substring highlight
  ranges remain pending.

## Remaining vertical-slice hardening

- Native Wayland GL context creation on the current NVIDIA/COSMIC stack.
- Real desktop IME preedit/commit and Orca inspection.
- Automated pointer selection, hover, scroll, primary selection, and pending
  clipboard teardown tests.
- Close/recreate actions in the product UI rather than only the stress harness.
- Collapsed/hidden/right-side presentation, Arrow/Home/End list navigation,
  Orca state inspection, richer group actions,
  foreground-shell detection, full settings panes, and agent runtime event
  ingestion remain after this footer milestone.

See `VIABILITY.md` for the checkpoint decision and evidence.
