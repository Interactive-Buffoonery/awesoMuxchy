# SwiftGtk4 implementation status

Updated: 2026-08-29

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
- The language-neutral shim forwards Ghostty title and PWD actions. Swift
  surfaces expose typed callbacks, and the application accepts them only when
  the pane/workspace/generation still names the live surface. One GTK-main
  publication updates the authoritative snapshot and every title/location
  consumer; explicit workspace renames opt out of live-title replacement.
- The shim also owns copied language-neutral environment key/value pairs for
  each surface. The app creates a `0600` pane-specific
  `awesomux-agent-v1` JSONL endpoint beneath a `0700` profile directory and
  injects only its protocol/session/pane/file coordinates. A capped background
  reader rejects non-owner files, symlinks, oversized/malformed/version-mismatched
  lines, and unknown providers; accepted explicit states cross the GTK-main
  generation guard into the authoritative snapshot, regular/rail/lifted tiles,
  activity footer, attention ordering, and persistence. The release harness
  verifies child environment delivery, and a real Grok blocking-input event
  was visually inspected at 1440×852.
- Multi-pane rows now own a 240-point transient pane card matching the reference
  180 ms reveal and 220 ms row-to-card grace. A pure projection preserves pane
  tree order, active identity, provider/state wording, remote identity, and
  sanitized title/cwd values. The GTK host is reconciled onto regular, Needs
  Input, or Pinned rows as projections change; pointer cards remain outside the
  keyboard focus chain while row context actions expose every pane through the
  same exact focus route. A real Pinned-row X11/GLX capture was inspected.
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
  A separate valid zero-group profile verifies the no-focused-pane boundary:
  no path bar or context chips are fabricated, the centered recovery action is
  exposed, fixed sidebar chrome remains, and the footer reports `0 agents`.
- The pinned sidebar footer now includes Quick Settings, Help & Feedback,
  state-prioritized agent counts, and an expandable activity list that returns
  to the exact workspace/pane. System/Light/Dark and notification mute persist
  in owner-only profile-scoped JSON.
- Quick Settings and feedback menus now expose only implemented behavior.
  Placeholder Welcome Tour and More settings windows were removed rather than
  presenting informational stand-ins as functioning product routes. Their real
  GTK popovers were opened through AT-SPI and captured; every visible choice is
  named and sensitive. The mute check row now owns theme contrast, keyboard
  focus treatment, and a 24-point minimum target. Real HighContrast captures
  cover Quick Settings and the full group action/color menu; all labels,
  selections, checks, and boundary enablement remain distinct.
- Expanded agent activity is now one priority-grouped pane-grained projection
  shared with the footer counts. Rows preserve sidebar traversal order, expose
  live pane/session titles plus sanitized local/remote locations, publish
  selected state, and close with exact-pane focus handoff. The collapsed rail
  renders 32-point state-specific controls that cycle only matching panes;
  model tests cover matching, wraparound, priority groups, stable order, and
  selected identity. Real X11 inspection covers the grouped panel and the
  collapsed state controls.
  Accessible count wording matches the reference plural catalog and keeps the
  total count label separate from its Expanded/Collapsed description.
  Full preflight passes 67 Swift tests, real release terminal integration, and
  100 two-surface lifecycle cycles after these changes.
- Regular and lifted workspace rows now open the same complete native context
  action surface through Menu or Shift+F10. Controller ownership is cleaned up
  and recreated with row/menu identity during moves, lifted reprojection,
  close/clear, and group teardown.
- Footer resolution runs concurrently off the GTK thread and publishes through
  GLib's main context. Git/`gh` execution is non-shell, bounded, prompt-free,
  output-capped, HTTPS-validated, and guarded against stale pane identity.
- The path control and status chips now use the reference's intrinsic sizing,
  spacing, radii, opacity, tone-specific borders, and 10/11-point monospaced
  hierarchy. Repository roots render as `repo root`; nested directories render
  repo-relative, and disappearing Git/PR/CI state clears stale chips.
- The path/project priority and branch chip now handle pathological footer text
  without displacing adjacent controls. The branch label follows the reference
  240-point cap and middle truncation while the short ahead/behind hint remains
  whole; GTK status menus and long branch-list entries are shrinkable/bounded.
  Draft and review PR chips now show the exact reference suffixes. A 1440 × 852
  synthetic long-repository/branch/dirty capture was inspected with two live
  Ghostty panes and no overlap or clipping.
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
  focus and persists the hidden state. Real X11 pointer QA now covers the
  hidden attention tab, mirrored left/right 296-point overlay reveal, and
  leave-grace retraction while the terminal keeps its full hidden-mode
  allocation. AT-SPI exposes the hidden attention tab as the focusable
  `Show Sidebar` button with its needs-input description and click action.
- Collapsed mode now renders a dedicated 60-point GTK rail instead of a clipped
  expanded hierarchy. Its 40-point search control opens a working filtered
  command palette, its create control and workspace buttons route through the
  authoritative session state, and its footer cycles through live agent panes.
  The expanded search text node has an owned theme style and the exact
  `Search sessions` placeholder. Full visual acceptance remains pending.
- The first expanded group's real GTK action popover was opened through AT-SPI
  and captured independently. It exposes exact create/rename/color/move/close
  routes, marks the current Blue tint, omits unavailable SSH, disables Move
  Group Up at the first boundary, and keeps Move Group Down sensitive.
- Search visibility is now driven by a pure `SidebarSearchProjection` that
  normalizes whitespace/diacritics and searches group/workspace/pane titles,
  paths, local/remote identity, agent/provider names, and state vocabulary in
  deterministic render order. The expanded sidebar includes the reference
  no-matches copy and a working `Clear search` action. Escape clears or returns
  focus to the terminal, Up/Down moves a distinct current-result outline, and
  Return selects that workspace using projection order.
- Real X11/GLX inspection now covers active Pinned-title highlighting and the
  exact query-bearing no-matches panel. The live entry exposes `Text` and
  `EditableText` under the `Search sessions` AT-SPI identity; `Clear search`
  exposes a named action whose AT-SPI invocation returned true and emptied the
  entry.
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
  Pane-scoped acknowledgement IDs now persist backward-compatibly. The ordered
  lift list is the sole projection membership source, and tested pane-state
  transitions append new arrivals without moving rows already under the user's
  pointer. A guarded 500 ms focused-pane dwell preserves the selected row with
  a runtime-only sticky until navigation away, acknowledges only the active
  pane, and does not passively clear permission or explicit-input prompts. The
  immediate `Acknowledge Workspace` row action and Ctrl-Shift-K route release
  the sticky and reconcile the lifted section and hidden edge cue. Exact
  per-workspace `Mute Notifications`/`Unmute Notifications` overrides persist.
  Pane-scoped `notification` + `waiting` runtime events now add a separate,
  non-persistent unanswered-turn mark, lift without an attention reason, honor
  Pinned precedence, retract only on prompt submission/session end or explicit
  acknowledgement, and publish the exact `is still waiting for a reply, moved
  to Needs Input` GTK status announcement. Blocking prompts keep their distinct
  background-agent announcement. A real waiting notification was directly
  observed as the exact medium-priority `Object.Announcement` on the AT-SPI bus
  without a focus transition; its paired prompt submission emitted the exact
  return-to-Local announcement at the same priority. A separate blocking-input
  pass delivered `Claude Code in Review needs input.` before its exact return,
  confirming it is not conflated with the unanswered-turn copy. Full preflight
  passes 86 Swift tests.
  Injected-clock GTK coverage and audible Orca output inspection remain pending.
- Non-pinned workspace menus now expose tested, bounded within-group Up/Down
  moves plus named previous/next-group and arbitrary-group alternatives.
  Mutations reuse the authoritative snapshot and existing terminal runtime,
  reorder regular/lifted/rail projections, and asynchronously rebuild affected
  menus so boundary enablement remains truthful after every move. Native GTK
  DnD now supports midpoint insertion within/across groups and group-header
  append, with process-scoped payload validation, filter lockout, no-op
  rejection, one mutation per accepted drop, and theme-aware indicators.
  Exact reorder announcements are projected by tested core formatters.
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
  and dark GTK windows were inspected after registration. A real Arabic-locale
  X11 capture verifies direction-sensitive mirroring across the titlebar,
  sidebar header/groups/rows, sidebar footer, focused footer, and pane boundary.
  Declared chrome font sizes now honor GTK Xft DPI accessibility scaling, with
  a clamped standard X11 DPI override fallback. A real 1.5× capture verifies
  natural allocation, long-text truncation, minimum targets, and both footer
  surfaces; pure tests cover resolution and CSS rewriting.
- The expanded sidebar now handles Up/Down/Home/End as one logical visible
  sequence across lifted sections, group disclosures, workspace rows, and
  creation rows using a pure tested navigation policy. Rows, rail controls,
  groups, edge attention, footer controls, and path/status controls publish
  GTK accessible names and descriptions; selected/expanded state updates with
  the authoritative model. Workspace rows expose list/tree-item roles and
  group disclosures are level-one tree items. GTK receives native position and
  set-size relations, while descriptions duplicate `Position N of M` because
  GTK 4.14's AT-SPI bridge does not export integer relations through
  `GetRelationSet`. Direct AT-SPI inspection verified roles, group color,
  expanded/collapsed state, singular/plural counts, lifted/group positions,
  and the row's explicit Shift+F10 action-menu description. The opened native
  menu remains the named non-pointer action surface. Compact targets are at
  least 24 points. The reference `Focus Sidebar` command is now exported with
  the Linux Control-Super-S mapping. It persistently unhides the sidebar, then
  focuses `Search sessions` in expanded mode or the selected/fallback rail row
  in collapsed mode. Direct GTK-action QA and inspected real-app captures cover
  both focus rings plus the hidden-to-visible preference transition. Empty
  search Up/Down now routes directly into the hierarchy instead of relying on
  GTK event bubbling; a policy regression test and AT-SPI focus inspection
  cover the first-row handoff. Row context keys run in capture phase so GTK's
  built-in key handling cannot intercept Menu or Shift+F10 first.
  Footer state chips are real buttons that open a state-filtered activity
  panel, and Orca discovers the live app through AT-SPI.
- Collapsed group attention is projected once from pane agent states and shared
  by expanded-header and rail signals. Needs Input wins over Error, which wins
  over Thinking; Output is intentionally excluded. Each rail group control
  opens a native, keyboard-operable roster with named `Jump to` workspace
  actions and refreshed accessible state text.
- Workspace, lifted, collapsed-rail, and pane-peek surfaces now share a pure
  provider-tile projection. Claude, Codex, OpenCode, Pi, Grok, and shell use
  distinct owned scalable marks and reference tint families, while every non-idle
  state adds a shape/glyph badge and accessible provider/status wording.
  Workspace rollup is pane-aware and priority-tested. A focused GTK drawing
  component independently implements the pinned Claude burst, Codex spiral,
  OpenCode brackets, Grok rings, and shell path; Pi stays in the owned mono
  stack. Decorative children are hidden from AT-SPI. Expanded real-app matrices
  were inspected in Latte, Mocha, and HighContrast; peek/rail behavior retains
  the same scalable component and provider/state parent label.
- Expanded regular/lifted rows now use sibling overlays for hover/focus-revealed
  24-point close controls, preserving the row's selection hit target. Group
  headers replace their count with a separately focusable close action under a
  tested filter/collapse/empty/drag safety policy. The collapsed rail exposes
  Control-1…9 actions and transient digits from one lifted-first order. Real
  hover and close/reopen renders were inspected; physical held-Control input
  remains pending because synthetic X11 input does not reach this session.
- The full local preflight passes 86 Swift tests after the live unanswered-turn
  announcement milestone, followed by the release build, real two-terminal
  title/cwd integration, and 100 two-surface lifecycle cycles.
- Long group text is now width-bounded and ellipsized, titlebar brand/title
  allocation remains stable for mirrored left/right sidebars, and split
  fractions are applied from the live logical `GtkPaned` extent. Real dark
  long-text captures cover both sidebar positions; a real 2× run preserves two
  visible terminal panes and the expected 592-physical-pixel sidebar width.

## Remaining vertical-slice hardening

- Native Wayland GL context creation on the current NVIDIA/COSMIC stack.
- Real desktop IME preedit/commit and Orca inspection.
- Automated pointer selection, hover, scroll, primary selection, physical DnD,
  and pending clipboard teardown tests.
- Automated destructive-dialog interaction and restored daemon continuity.
- Collapsed/hidden/right-side presentation, pointer roster hover cards,
  Orca state/announcement inspection,
  foreground-shell detection and full settings panes remain after this footer
  milestone.

See `VIABILITY.md` for the checkpoint decision and evidence.
