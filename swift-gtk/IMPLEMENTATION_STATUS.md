# SwiftGtk4 implementation status

## INT-1112 terminal layout survival — 2026-09-23

The historical split/resize checks below retained `TerminalSurface` references
and pane IDs but did not assert process survival. A real Omarchy/Hyprland
reproduction recorded shell PID 1583197 and harmless job PID 1583525 before
GTK detach. The shim became unready, the job died, and reattach reported new
foreground PID 1583925. The staged Linux embedded-Ghostty lifecycle patch and
shim changes keep the core across GL unrealize/realize. An eight-remount
regression checks foreground PID, shell recovery, scrollback, focus, input,
output, and clipboard. The original real Omarchy repro now keeps shell PID
1676855 and active job PID 1677212 through GTK detach and reattach. Native
Wayland integration passed eight live-job remounts, scrollback, focus transfer,
input/output, title and directory callbacks, and preserved prompt/close-risk
flags. Its live-session mode skipped all clipboard writes. The separate app
action probe preserved the original shell through Split Right and Grow/Shrink,
then exposed an indefinitely retained closed sibling. The source now drops a
closed surface after focus retargeting on the next GTK turn. Supervised native
Omarchy app actions under a private D-Bus session and isolated profile then
kept original shell PID 2129973 and job PID 2129982 alive across Split Right,
Grow, Shrink, and sibling Close Pane. The sibling shell PID 2130087 exited,
the layout returned to the original pane ID, and all test processes/windows
were gone after cleanup. A bounded release Wayland run previously stopped at a
focus-test precondition
that did not prove compositor activation or sibling focus transfer; its process,
children, and window all exited. The guard is corrected source-only, and
the later fault-injected native integration passed eight remounts, exactly one
GL recovery, and detached-close shell PID exit. Its focus-transfer assertion
was skipped because compositor window focus was unavailable. Full
`./script/preflight.sh` later passed exit 0 under isolated D-Bus, Ghostty
configuration, and clipboard with private Xvfb `:1` and headless Weston
`wayland-awesomux-qa`. Swift tests, release build, single-window and dynamic
enablement, forced-termination persistence, X11 and Wayland terminal
integration, and 100 lifecycle cycles on each display passed. Both terminal
integrations verified post-remount focus transfer, eight live-process
remounts, and detached release; X11 used the private clipboard. Live Omarchy
compositor focus and broader daily-use acceptance remain pending.
The GL lifecycle now retains the original context on deferred cleanup and
uses a staged no-GL Ghostty final teardown if that context is lost. A one-shot
fault injection checks recovery exactly once; native Omarchy execution of that
fault case and its detached close passed. True lost-context quarantine remains
untested. Unrecoverable displays show a pane
error instructing close and reopen.

2026-09-23 acceptance update: SwiftGtk4 is the sole application implementation;
the unused fallback scaffolding has been removed. Omarchy/Hyprland is the
required Linux baseline. Acceptance remains pending until real Omarchy desktop
and daily-use checks pass; historical runs on other desktops and build-only
checks do not satisfy this gate. This cleanup changes no runtime behavior.

## awesoMuxchy planning — 2026-09-23

This remains the shared active implementation for the planned Omarchy edition.
The public repository is now `Interactive-Buffoonery/awesoMuxchy`; the local
folder and executable names are unchanged. See
[ADR 0005](../docs/adr/0005-awesomuxchy-omarchy-edition.md) and the
[Linear project](https://linear.app/interactive-buffoonery/project/awesomuxchy-190ce1959bdf).
The review's open runtime, clipboard, recovery, accessibility, and keyboard
findings qualify historical completion claims below. No implementation fixes
or new desktop verification accompany the rename. The existing 130-test binary,
fresh core typecheck, and local text-baseline check passed; live reference
comparison and full preflight were pending at this rename checkpoint; the later
INT-1112 private-display preflight result is recorded above. Private-origin statements below
describe historical uploads.

Consolidation update: 2026-09-22. Runtime evidence below is historical and was
not rerun during cleanup.

## Consolidation checkpoint

This is the active Linux application. Read the
[consolidation record](../docs/linux-consolidation.md) and
[Electron behavior handoff](../docs/electron-behavior-handoff.md) before further
implementation. Electron's full fetched Git history is preserved offline; no
Electron dependency or runtime code was added to SwiftGtk4.

Next: reconcile i5GamingPC's local-only implementation, verify terminal close
and sustained-save behavior, then add persistent `amx` sessions and real agents.
No new Swift, GTK, or desktop verification is claimed by this cleanup.

## Local development check — 2026-09-22

On pinguchy, pinned Swift 6.3.3 builds the debug app against GTK 4.22.4 after
repository-local compatibility setup and a narrow SwiftPango constant patch.
Ghostty and the shim build with the Arch host-helper linker workaround.
The development application opens on native Wayland, exports its workspace
action, and creates a real terminal workspace; its window capture was inspected.
This does not replace i5GamingPC desktop, visual-parity, or daily-use evidence.
All 130 Swift package tests pass on this host. See
[development instructions](../docs/development.md). Full preflight was pending
at this 2026-09-22 checkpoint; the later INT-1112 result is recorded above.

## Current phase

Viability, defensive restoration, and the enriched sidebar/terminal footer
milestone are complete and locally verified. The terminal footer's reference
geometry and state styling have also passed a real-window visual correction.

## Completed

- The app-owned pane-boundary system replaces the stock wide `GtkPaned`
  appearance while retaining GTK allocation, pointer dragging, and keyboard
  resize semantics. Pane top edges track focused/unfocused/attention/error;
  an input-transparent scrim dims inactive panes; high contrast adds a
  black/white non-color thickness cue and reduced motion disables transitions.
  Native Wayland vertical, horizontal, and nested release frames and X11
  focus-transfer/live-event/appearance frames were inspected, along with native
  125/150/200% constrained-width scale frames. Equivalent-size pinned macOS
  dark fixtures now cover focus A/B, nested focus, hover, drag, keyboard resize,
  and narrow layout, exposing remaining rail-color and pane-header differences.
  Linux physical interaction and the paired appearance/accessibility matrix
  are explicitly still pending.
  Native AT-SPI directly verifies both orientation-specific names, explicit
  `separator` roles, and resize descriptions in a nested layout; GTK 4.14's
  inert AT-SPI focus/value operations are not represented as interaction proof.

- The awesoMux titlebar now owns GTK client-side decoration and native window
  controls, removing the duplicate outer header in inspected X11 and native
  Wayland release frames. Explicit decoration layout retains minimize,
  maximize, and close under COSMIC. Paired-reference verification remains
  pending.

- Swift 6.3.3 builds the pinned SwiftGtk dependency graph without warnings in
  owned Swift code or concurrency-suppression flags.
- `AwesoMuxTerminal` contains every raw Ghostty handle and exposes owned Swift
  runtime/surface objects to the app and integration harnesses.
- Two concurrent real terminals render on native Wayland/EGL and X11/GLX,
  receive focus and resize, and support UTF-8 input plus GTK clipboard
  read/write callbacks.
- GTK signals are disconnected before release; pending clipboard reads keep
  the host allocation alive and cannot complete against a destroyed core.
- GTK focus-enter/leave events cross the language-neutral callback table and
  update Swift pane ownership; sidebar selection and direct pane clicks now
  converge on the same focused-surface route.
- The standalone terminal integration harness passes pane independence,
  process exit, callbacks from both focused surfaces, resize, Unicode, rapid
  Unicode reflow during 80 divider moves, and clipboard read/write. The stress
  route restores the split and requires the same surface to remain ready for
  focus, input, and close-risk verification; four consecutive X11/GLX passes
  completed cleanly.
- The shim now prepares GTK's desktop-OpenGL environment before initialization,
  matching canonical Ghostty's GTK 4.14/4.16 version split. The same harness
  passes natively on COSMIC Wayland at 100%, 125%, 150%, and 200%, followed by
  100 two-surface lifecycle cycles and an inspected 1440×888 app-owned PNG.
- Full preflight passes all 130 Swift tests, every release/process probe, X11
  integration plus 100 lifecycle cycles, and native Wayland integration plus
  100 lifecycle cycles. Visual-QA commit `fd0dd22` is on the private origin.
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
  same exact focus route. Workspace selection now refreshes pane-command
  enablement immediately. A pure catalog-wide projection also gates workspace,
  attention, recovery, jump, palette, and sidebar commands across empty,
  one/two-workspace, pane-count, and modal-sheet states. A release-process probe
  proves each boundary, including exact second-pane routing and the reference's
  split availability during a sheet, and rejects export of the unimplemented
  Keyboard Shortcuts placeholder. A fresh release
  app used app-owned collapsed/expanded focus recovery to expose the peek card;
  AT-SPI invoked pane 1's explicit Click action and the owner-only snapshot
  persisted the exact first pane identity. A real Pinned-row X11/GLX capture
  was inspected; audible Orca and physical-pointer evidence remain pending.
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
  local actions and show a remote indicator. Ordinary path clicks retain that
  action menu, while Linux Control-click maps the reference Command-click to
  reveal the same current, identity-checked local repo root or working
  directory in Files; remote panes fail closed. Real release-app AT-SPI QA
  confirms an ordinary click still exposes both Show in Files and Copy Path.
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
- Title-only publications for the selected focused pane now coalesce behind a
  tested 500 ms settle before refreshing footer repository context. This keeps
  in-place branch changes discoverable without launching a filesystem/Git walk
  for every high-frequency terminal-title frame; cwd/pane/surface-generation
  changes and background-pane titles cancel or fail closed.
- The path control and status chips now use the reference's intrinsic sizing,
  spacing, radii, opacity, tone-specific borders, and 10/11-point monospaced
  hierarchy. Repository roots render as `repo root`; nested directories render
  repo-relative, and disappearing Git/PR/CI state clears stale chips.
- Interactive branch/PR/CI menu chips now use the shared tested 24-point target
  minimum; the noninteractive dirty/remote indicators intentionally remain at
  the reference's compact 20-point status height.
- The path/project priority and branch chip now handle pathological footer text
  without displacing adjacent controls. The branch label follows the reference
  240-point cap and middle truncation while the short ahead/behind hint remains
  whole; GTK status menus and long branch-list entries are shrinkable/bounded.
  Draft and review PR chips now show the exact reference suffixes. A 1440 × 852
  synthetic long-repository/branch/dirty capture was inspected with two live
  Ghostty panes and no overlap or clipping.
- In-pane footer commands now match the reference shell-session rule: local
  ownership plus no declared agent enables staging, while remote/agent panes
  fail closed. Staged branch/PR/CI payloads never append a newline, so an active
  command or TUI remains under user control. Branch rows copy their name when
  the gate is closed; PR/CI insertion rows are omitted and defensively re-check
  on activation. The current branch is a noninteractive row, branch rows expose
  truthful insert/copy descriptions, and PR/CI menus use exact reference copy.
  Live AT-SPI verified the same branch row changes from `Copies the branch
  name` for Codex to `Inserts the checkout command at the prompt` for an
  otherwise identical local shell pane, then staged the no-newline payload
  without executing it or producing runtime diagnostics.
- Session mutations now schedule one serialized utility write at the
  reference's 500 ms trailing edge instead of performing validation, JSON
  encoding, previous-snapshot rotation, and atomic replacement on GTK's UI
  thread. A clean application-run boundary flushes the newest authoritative
  snapshot after invalidating delayed work, and a failed write retains that
  value for the next mutation or explicit flush. Four focused tests cover burst
  coalescing, bounded automatic durability, latest-state flush, and retry.
- Missing/invalid saved state now opens on the real zero-workspace surface
  rather than developer fixture workspaces. A successfully quarantined invalid
  snapshot presents one owned 520×230 recovery sheet using exact reference
  wording; real AT-SPI verified its frame, heading, full message, and `Done`
  action. The archive and subsequent clean empty snapshot both retained `0600`.
  Local preflight now runs a release process probe that SIGKILLs scheduled
  persistence before and after the 500 ms edge, decoding the prior safe snapshot
  in the first case and the newest snapshot in the second.
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
- The 40-point collapsed Search action and Control-K now share a focused
  `CommandPaletteController` popover inside the primary GTK window. Its tested
  immutable summon projection unifies workspace and enabled-command results,
  searches title/path/group fields with stable fuzzy scores, exposes curated
  suggestions for an empty query, and maps leading `>` to actions-only mode.
  Bare Return remains inert until selection; Up/Down, Return, and Escape use a
  tested clamped policy and exact target routing. Real AT-SPI opened it through
  collapsed Search, verified editable unified/actions-only results and result
  positions, and a privacy-safe 606×506 Latte popup surface was inspected. Its
  tested geometry keeps the preferred 520×420 card at normal sizes, applies a
  16-point inset on narrow windows, and keeps arrow-selected rows within the
  native scroll viewport.
- Visible title/location search matches now use tested case- and
  diacritic-insensitive fuzzy scoring with word-boundary/contiguous bonuses,
  bounded gap penalties, and best-alignment selection. Every matched UTF-8 byte
  range is applied as a bold underlined Pango attribute to regular and lifted
  rows. Score order has a stable source-order tie-breaker; whole-group and
  hidden workspace/provider/state/SSH matches retain authoritative order and
  remain truthful without falsely highlighting unrelated visible text.
- A tested empty-workspace presentation now drives the centered first-launch
  guidance, primary New Workspace action, conditional Reopen Closed Workspace,
  and the collapsed rail's dashed 40-point creation control. Sidebar
  width/visibility routing was lifted ahead of selected-workspace gating so
  empty-state users can still collapse, expand, hide, and show the host. Both
  expanded and collapsed empty states were run and inspected under X11/GLX.
- Missing-profile recovery was exercised through the real accessibility tree:
  `Focus Sidebar` focused the named search box, the centered action exposed one
  `Click` action and the exact `New Workspace` name, and invoking it persisted
  exactly one group, selected workspace, and pane. Its visible plus-prefixed
  text is now an accessibility-hidden child so GTK cannot override the parent
  action name. The focused 1440×852 Latte empty surface was inspected.
- Group mutations now cover sanitized unique create/rename, explicit color,
  stable-ID reorder, cross-group workspace insertion, and populated close with
  replacement selection. Native GTK group menus expose only implemented
  routes, dynamically gate move/close during filtering, confirm destructive
  close, and keep a creation row after each expanded group's workspaces.
  Automatic tint cycling and the awesoMux/mauve exception are tested.
- Group creation and rename now use one transient modal sheet owned by the main
  window. The shared pure draft matches the reference's input clamp,
  sanitization feedback, duplicate and mixed-script validation, exact copy,
  and disabled-action hints. The catalog's `New Workspace Group` action is now
  implemented and disabled only while a sheet is active. Live AT-SPI verified
  create and rename headings, field/action names, duplicate rejection,
  successful persisted mutations, command recovery, and crash-free teardown;
  both 420-point Latte sheets were inspected under X11/GLX.
- The expanded header now uses separate 30-point primary and 24-point options
  segments; the collapsed rail uses a 40-point creation menu. Default versus
  current-directory creation resolve different directory/group contexts at
  activation and share a 400 ms duplicate guard. Current-directory creation is
  disabled when no focused cwd exists, refreshes with selection, and carries a
  declared remote pane's cwd through the same local-workspace route as the
  reference. `New Workspace Here` now derives the exact row identity's origin
  group and focused cwd at activation and rejects missing, soft-closed, or
  invalid targets rather than substituting the app cwd. Quick Settings now
  applies
  persisted Standard/Compact sidebar density live. The preference also updates
  native GTK geometry: Standard uses 14/3/5-point group/header/session spacing
  and Compact uses 8/1/3 points, with GTK-specific row sizing and exact
  7/5-point creation-row padding. Paired 296×852 real-app captures verify both
  densities against the same fixture.
  Creation rows now use the reference lowercase label and exact accessible
  name, a quiet elevated resting fill, and no resting dashed border.
- Creation no longer treats storage order as the default-group contract. The
  expanded primary action resolves the selected workspace's owning group at
  activation, falling back to the canonical `awesoMux` group; app/menu New
  Workspace targets that canonical default, and New Workspace in Current
  Directory preserves the focused pane cwd while using selected-owner/default
  routing. Pure coverage rejects silent first-group fallback. In a real
  three-group profile, AT-SPI activation selected and persisted one new
  workspace in the selected second group without changing either sibling.
- Workspace rename now presents one transient modal sheet instead of a loose
  GTK window. It matches `WorkspaceEditSheet` copy and validation, exposes a
  real heading plus named text box and actions, disables repeat command
  activation while open, and routes entry activation/Escape through guarded
  Save/Cancel paths. Live AT-SPI Save and Cancel passes verified persistence,
  command recovery, and crash-free controller teardown; the corrected owned
  Latte sheet was inspected at 420×196.
- Destructive workspace/group actions now use one owned modal sheet family.
  A pure close-risk policy mirrors the reference priority for process exit,
  foreground commands, shell children, indeterminate liveness, and fresh
  agent execution; the language-neutral shim exposes Ghostty's foreground PID
  and close-confirmation signal. Soft close now releases its real terminal
  surfaces and reconstructs them on reopen. Live AT-SPI verified exact
  headings, bodies, hints, safe-default Cancel, destructive actions, command
  gating, persisted recovery, aggregate group count, teardown, and app
  survival. The three 480×230 Latte sheets were inspected under X11/GLX. The
  staged canonical runtime now installs Ghostty's own shell integration and
  exports a locked prompt-observed bit; app risk uses prompt-away only after
  observation. The real harness proves an observed idle prompt is safe and a
  subsequent foreground command is risky without startup false positives.
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
  pane, and does not passively clear permission or explicit-input prompts. Its
  production scheduler now uses the GTK/GLib main loop and also starts when an
  event arrives after focus has settled. Injected scheduling tests verify the
  exact 500 ms edge, stale selection/pane rejection, newest-request behavior,
  and cancellation. A real owner-only event persisted the exact acknowledged
  pane; paired inspected captures show background promotion and origin return
  after dwell/navigation. The immediate `Acknowledge Workspace` row action and
  Ctrl-Shift-K route release the sticky and reconcile the lifted section and
  hidden edge cue. Exact
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
  passes 113 Swift tests.
  Background rollup crossings into Done and Error now use the reference
  agent-plus-workspace completion/error copy without lifting the row. Live Codex
  events delivered both exact medium-priority AT-SPI announcements; Running
  remained silent as intended.
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
- Split Right, Split Down, and Close Pane are now exported through the GTK app
  action/menu/palette router. A split seeds one local shell from the focused
  cwd, retained every surviving Swift surface reference (the old shim still
  restarted its Ghostty core on unrealize), focuses the new pane, and
  refreshes all pane-owned chrome. Multi-pane close selects the next traversal
  neighbor, prunes stale acknowledgement/unanswered identities, shows the
  exact pane-risk sheet when required. Historical close QA retained detached
  Ghostty surfaces until process exit, which could wait indefinitely because
  the embedded close request has no Swift host callback. INT-1112 now releases
  the closed surface on the next GTK turn after the survivor owns focus. A
  supervised native Omarchy app-action run on 2026-09-23 verified the original
  shell and harmless job survived Split Right, Grow, Shrink, and sibling Close
  Pane while the sibling shell exited. The historical two-cycle right/down
  split-and-confirmed-close pass preserved the original pane ID and cwd and
  finished with a clean runtime log but did not prove process continuity.
- Grow/Shrink Active Pane now map to Control-Alt-Equals/Minus and are enabled
  only for a selected multi-pane workspace. The pure nearest-split reducer
  handles nested first/second growth, 10–90% clamps, and boundary no-ops;
  command activation persists the new fraction while remounting containers
  around the same Swift surface references. Real GTK actions verified
  0.50 → 0.45 → 0.50 → 0.10 and a non-mutating extra boundary activation with
  a clean runtime log.
- GtkPaned primary-button release now updates the exact nested model split,
  snaps pointer movement to 10–90%, and writes once per completed interaction.
  The route deliberately ignores allocation-time position notifications: a
  clean isolated-profile launch left an exact stored 0.500 fraction unchanged.
  Exact nested replacement/clamp tests pass; physical held-pointer evidence is
  still pending because XTest is not routed by the Smithay QA display.
- Previous/Next Pane and Focus Pane 1–6 are now exported actions with exact
  Control-Alt bracket/digit chords, depth-first routing, truthful per-pane-count
  enablement, persisted focus/footer refresh, and `Focused pane N`
  announcements. Real action introspection reported Pane 1/2 plus relative
  actions enabled and Pane 3–6 disabled for a two-pane fixture; activating Pane
  2 → Previous → disabled Pane 3 → Next persisted only the expected identities.
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
- `ChromeContrastAudit` now verifies 37 named WCAG 2.2 pairings for Mocha,
  Latte, and high contrast: primary/compact text, focus, control boundaries,
  semantic agent states, and every provider/shell glyph. Corrections strengthen
  Latte compact text and selected actions plus both themes' low-contrast
  boundaries while preserving non-color labels, symbols, and counts. The real
  296×852 Latte sidebar crop is inspected, window-close teardown explicitly
  detaches row-owned popovers, and full preflight passes 106 tests plus every
  process-level harness without runtime diagnostics.
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
- Structural sidebar actions now restore focus by stable workspace/group
  identity after their projected GTK rows move or are rebuilt. Pin/unpin,
  acknowledge, notification changes, pinned/ordinary/cross-group reorder, and
  group reorder cover expanded and collapsed destinations while explicitly
  refusing to steal focus when a command originated in the terminal. Real
  Latte QA inspected Pinned → origin focus transfer and an AT-SPI-invoked group
  reorder with the moved disclosure's focus-only close affordance intact.
- Lifted section structure now uses GTK revealers at the reference 140 ms
  duration. `SidebarStructuralMotionPolicy` disables motion for initial layout,
  filtering, and GTK reduced-motion preference; hiding also removes the section
  from accessibility immediately and guards delayed layout removal against a
  rapid reversal. Real Latte captures inspect Pinned insertion/removal during
  transition and after settling with fixed chrome unchanged; full preflight
  passes 107 tests and every process-level harness.
- The activity panel now owns one tested open/filter state machine and closes
  transactionally when the sidebar enters its 60-point rail, clearing both the
  activity filter and sidebar search. Escape is captured across the panel
  subtree and uses the same tested filter-clearing close transition,
  disclosure-focus return, and accessibility announcement instead of relying
  on pointer access to the close button. Sidebar-owned keyboard focus follows the
  selected stable workspace identity into the rail and back into the expanded
  hierarchy, while terminal-owned focus is not stolen. Roster titles share the
  sidebar's coarse live-title projection; workspace rename and every pane
  title/cwd callback refresh the panel, including persisted nonfocused cwd
  changes. Real GTK action plus AT-SPI QA verified close/non-resurrection,
  cleared search, and selected-row focus in both modes. Inspected 296×852 and
  60×852 Latte crops exposed and verified a selected activity-row contrast
  correction covered by named WCAG requirements. Full preflight passes 110
  Swift tests and every process-level harness.
- Repeated application activation now presents one retained primary window
  instead of rebuilding state and creating duplicate native windows. Close
  clears the retained window identity, while the completed application state
  remains available for the final persistence flush. A pure activation-policy
  test covers first versus subsequent activation, and the local preflight's
  release-process probe launches three secondary instances and observes one
  X11 normal window under an isolated profile/test application ID. The probe
  reuses the desktop session bus and leaves AT-SPI intact.
- Header icon controls now use tested reference copy for AT-SPI hints. Direct
  bus traversal verifies expanded `New Workspace` and `New Workspace Options`
  name/description pairs plus collapsed `Search` and `New Workspace menu`
  pairs. Text-glyph children used by primary-create and close affordances are
  hidden as decorative, preventing GTK child-name fallback from exposing `+`
  or `×` instead of the action name.
- Collapsed group attention is projected once from pane agent states and shared
  by expanded-header and rail signals. Needs Input wins over Error, which wins
  over Thinking; Output is intentionally excluded. Each rail group control
  opens a native, keyboard-operable roster with named `Jump to` workspace
  actions and refreshed accessible state text.
- Group disclosures and rail controls now share a tested accessibility
  presentation: soft-closed workspaces are excluded from counts, selected
  descendants set the group's selected state, and local-only groups expose the
  exact reference `Local panes` or `Local creation default` execution text.
  Remote execution text is withheld until destination identity exists in the
  model rather than substituting weaker copy.
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

- Real desktop IME preedit/commit and Orca inspection.
- Automated pointer selection, hover, scroll, primary selection, physical DnD,
  and pending clipboard teardown tests.
- Automated destructive-dialog interaction and restored daemon continuity.
- Collapsed/hidden/right-side presentation, pointer roster hover cards,
  Orca state/announcement inspection,
  full settings panes remain after this footer
  milestone.

See `VIABILITY.md` for the checkpoint decision and evidence.
