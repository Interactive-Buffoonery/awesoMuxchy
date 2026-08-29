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
  Return selects that workspace using projection order.
- Visible title/location search matches now use tested case- and
  diacritic-insensitive UTF-8 byte ranges, applied as bold underlined Pango
  attributes to regular and lifted rows. Hidden-token matches remain truthful
  without falsely highlighting unrelated visible text; multi-token/fuzzy
  highlight ranges remain pending.
- A tested empty-workspace presentation now drives the centered first-launch
  guidance, primary New Workspace action, conditional Reopen Closed Workspace,
  and the collapsed rail's dashed 40-point creation control. Sidebar
  width/visibility routing was lifted ahead of selected-workspace gating so
  empty-state users can still collapse, expand, hide, and show the host. Both
  expanded and collapsed empty states were run and inspected under X11/GLX.
- Group mutations now cover sanitized unique create/rename, explicit color,
  stable-ID reorder, cross-group workspace insertion, and populated close with
  replacement selection. Native GTK group menus expose only implemented
  routes, dynamically gate move/close during filtering, confirm destructive
  close, and keep a creation row after each expanded group's workspaces.
  Automatic tint cycling and the awesoMux/mauve exception are tested.
- The expanded header now uses separate 30-point primary and 24-point options
  segments; the collapsed rail uses a 40-point creation menu. Default versus
  current-directory creation resolve different directory/group contexts at
  activation and share a 400 ms duplicate guard. Quick Settings now applies
  persisted Standard/Compact sidebar density live.
- `SidebarLiftedProjection` now composes search, sticky Needs Input arrival
  order, and explicit Pinned order without duplicating origin rows. The schema
  additions decode absent legacy fields safely and validate every ordered ID.
  GTK renders non-collapsible Needs Input and Pinned sections above ownership
  groups, preserves origin tint/labels, mirrors order and semantic glyphs in
  the rail, and routes selection to the authoritative workspace. Secondary
  click exposes implemented `New Workspace Here`, rename, cross-group move,
  and `Pin`/`Unpin` actions. Pinned rows additionally expose bounded
  identity-based `Move Workspace Up/Down`; moves retain terminal runtimes.
  Pane-scoped acknowledgement IDs now persist backward-compatibly. A guarded
  500 ms focused-pane dwell, immediate `Acknowledge Workspace` row action and
  Ctrl-Shift-K route reconcile the lifted section and hidden edge cue. Exact
  per-workspace `Mute Notifications`/`Unmute Notifications` overrides persist.
  Unanswered-turn ingestion, reorder DnD, injected-clock UI coverage, and
  AT-SPI announcements remain pending.
- Non-pinned workspace menus now expose tested, bounded within-group Up/Down
  moves plus named previous/next-group and arbitrary-group alternatives.
  Mutations reuse the authoritative snapshot and existing terminal runtime,
  reorder regular/lifted/rail projections, and asynchronously rebuild affected
  menus so boundary enablement remains truthful after every move. Pointer DnD,
  insertion indicators, shortcuts, and announcements remain pending.
- `Close Workspace`, `Reopen Closed Workspace`, and `Clear Workspace` now have
  persistent model semantics and awesoMux-owned Ctrl-Shift-W, Ctrl-Shift-T,
  and Ctrl-Alt-Shift-W routing. Recovery is capped at 20 entries/24 hours,
  prunes expired snapshot data, and commits reopen only after terminal/UI
  reconstruction succeeds. Permanent clear always confirms and releases all
  pane surfaces without creating a recovery record.
- Chrome CSS is now isolated from the application controller and covers the
  reference Mocha/Latte ramps, state tints, focus geometry, high-contrast
  foregrounds, system/explicit theme resolution, density, and reduced-motion
  preference. A pure appearance policy covers GTK theme names and `GTK_THEME`
  overrides in tests. Four exact pinned Geist weights and their OFL license are
  SwiftPM resources registered process-locally through Fontconfig; real light
  and dark GTK windows were inspected after registration.
- The expanded sidebar now handles Up/Down/Home/End as one logical visible
  sequence across lifted sections, group disclosures, workspace rows, and
  creation rows using a pure tested navigation policy. Rows, rail controls,
  groups, edge attention, footer controls, and path/status controls publish
  GTK accessible names and descriptions; selected/expanded state updates with
  the authoritative model. Compact targets are at least 24 points. Footer
  state chips are real buttons that open a state-filtered activity panel, and
  Orca discovers the live app through AT-SPI.

## Remaining vertical-slice hardening

- Native Wayland GL context creation on the current NVIDIA/COSMIC stack.
- Real desktop IME preedit/commit and Orca inspection.
- Automated pointer selection, hover, scroll, primary selection, and pending
  clipboard teardown tests.
- Automated destructive-dialog interaction and restored daemon continuity.
- Collapsed/hidden/right-side presentation, Arrow/Home/End list navigation,
  Orca state inspection, richer group actions,
  foreground-shell detection, full settings panes, and agent runtime event
  ingestion remain after this footer milestone.

See `VIABILITY.md` for the checkpoint decision and evidence.
