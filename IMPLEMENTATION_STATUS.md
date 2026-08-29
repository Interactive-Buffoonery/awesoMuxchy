# Implementation status

Updated: 2026-08-29

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
  A real zero-group/no-selection profile verifies the neutral absent state:
  the focused footer and all path/Git/PR/CI/remote chips disappear instead of
  presenting disabled placeholders, while the empty-workspace recovery action
  and truthful `0 agents` sidebar footer remain.
- The sidebar footer now matches the reference control set: Quick Settings,
  Help & Feedback, live thinking/output/attention chips, total agents, and an
  expandable agent activity panel that routes back to the exact pane. Theme
  and notification-mute preferences persist as owner-only profile JSON.
- Live agent state now enters through the pane-scoped `awesomux-agent-v1`
  side channel rather than terminal scraping. Each Ghostty surface receives
  an owner-only JSONL endpoint plus session/pane identity through a
  language-neutral environment ABI; a bounded background reader accepts only
  the five known provider identities and explicit semantic states, then
  publishes through the existing generation-guarded pane reducer on GTK's
  main thread. A real Grok `userInputRequired` event moved the exact workspace
  into Needs Input, refreshed its provider/status tile and three-agent footer,
  and persisted the pane state. Waiting `notification` events are separately
  tracked as runtime-only unanswered turns: they promote without manufacturing
  an attention reason, retract on prompt submission/session end or explicit
  acknowledgement, honor Pinned precedence, and announce the exact reference
  move wording without stealing focus. Ordinary background input promotions
  and live return-to-group transitions also use the reference announcement
  channel. Full preflight passes 86 Swift tests; the
  terminal harness also proves the environment reaches the child process.
- Footer menus expose only real routes: Quick Settings directly changes the
  implemented theme, density, and notification preferences, while Report a
  bug… and Suggest a feature… open the verified feedback intake. Placeholder
  Welcome Tour and More settings informational windows were removed; those
  entries stay absent until their full product surfaces exist. Real AT-SPI-opened
  Quick Settings and Help & Feedback popovers were captured and inspected. The
  notification check row now has owned Mocha/Latte contrast, a visible focus
  outline, and a 24-point minimum target; AT-SPI reports all visible choices as
  sensitive. HighContrast passes repeat the real Quick Settings and group-menu
  surfaces with stronger borders and preserved labels, selections, and
  enablement; provider/status grayscale traversal remains pending.
- The collapsed 60-point footer now mirrors the reference vertical contract:
  Quick Settings, Help & Feedback, then only nonzero Thinking, Output, and
  Needs Attention controls. Each 32-point state control cycles through exact
  matching panes in stable sidebar traversal order instead of using a generic
  all-agent button. The expanded panel groups the same authoritative roster by
  priority, shows pane/session titles and sanitized local/remote locations,
  marks the selected pane, closes on selection, restores focus on dismissal,
  and announces open/close without stealing terminal focus.
  Count labels use the exact reference singular/plural forms (`1 agent`,
  `2 agents`, and state-qualified equivalents), while total-button accessible
  state distinguishes Expanded and Collapsed from its stable count label.
  Full preflight passes 67 Swift tests, the release terminal integration, and
  100 two-surface lifecycle cycles after this roster/footer milestone.
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
- Long repository/path text and branch chips now converge on the reference
  truncation policy: project text ends cleanly, paths and the 240-point-capped
  branch label middle-truncate, ahead/behind hints remain whole, and every GTK
  status menu can shrink without moving or clipping its neighbors. Branch-list
  menu labels are bounded, and draft/review PR chips include the exact
  `· draft`/`· review` suffixes. A synthetic long-path/branch/dirty real-app
  capture was inspected with both Ghostty panes visible.
- The sidebar host now uses a native GTK horizontal split with the reference
  296-point default, 60-point rail settlement, 250-point mode threshold, and a
  480-point terminal minimum. Width and last-expanded width are defensively
  normalized in the existing owner-only profile preferences, including
  backward-compatible loading of pre-width preference files. Configured
  left/right placement mirrors titlebar/sidebar order, divider-coordinate
  math, resize ownership, and edge borders. Persistently hidden sidebars move
  into a GTK overlay: the 40-point edge sensor reveals without resizing the
  terminal, sidebar occupancy holds the reveal, and exit uses the reference
  220 ms grace. A tested dormant-state attention policy shows a side-aware
  discovery tab for Needs Attention. Native
  Collapse/Expand Sidebar and Hide/Show Sidebar commands use the reference
  Linux-mapped shortcuts; hiding first returns focus to the active terminal.
- The 60-point mode now owns a separate GTK rail rather than clipping expanded
  controls. It includes 40-point search/command-palette and creation controls,
  live workspace selection buttons, and a collapsed footer whose total-agent
  control cycles through the live pane roster. The expanded search field uses
  the exact `Search sessions` placeholder and an owned dark-theme text-node
  style. A trustworthy collapsed screenshot is still pending because the
  available raw X11 window capture does not composite client-side GTK damage.
- Sidebar filtering now runs through a pure deterministic projection rather
  than mutable per-row substring caches. It searches group/workspace and pane
  titles, local and remote paths, execution identity, agent/provider identity,
  and canonical state tokens with diacritic-insensitive normalization. Focused
  tests cover stable ordering, whitespace-only queries, top match, remote/SSH,
  Needs Input, and no-result behavior; the GTK sidebar now renders the exact
  no-matches description and `Clear search` action.
- Search output now carries Unicode-safe UTF-8 byte ranges for visible
  title/location matches. GTK applies bold underlined Pango attributes to
  regular and lifted rows and clears them transactionally with the query;
  agent/state/group-only matches remain visible without inventing a highlight.
- Real X11/GLX captures now cover a visible Pinned title highlight and the exact
  query-bearing no-matches panel. The live `Search sessions` entry was edited
  through AT-SPI `EditableText`; AT-SPI exposed `Clear search` as a named action,
  and invoking it returned true and emptied the accessible text value.
- The zero-group state now presents the reference first-launch workspace
  guidance and New Workspace action in the content area, with Reopen Closed
  Workspace appearing only when recovery exists. The 60-point rail renders
  the reference dashed 40-point creation action. A pure presentation policy
  covers filtering/recovery branches, sidebar width/hide commands now work
  without a selected workspace, and expanded/collapsed real windows were
  inspected from an isolated empty profile.
- Expanded search keyboard routing uses that same projection order: Escape
  clears or restores terminal focus, Up/Down moves a visible current-result
  outline, and Return selects and focuses the routed workspace.
- Workspace-group state now has tested safe create/rename, explicit color,
  stable-ID reorder, cross-group workspace movement, and populated close with
  deterministic replacement selection. GTK headers expose the corresponding
  truthful menus and confirmation flow (SSH remains absent), plus a persistent
  per-group `New Workspace in Group` row that disappears while filtering.
  Automatic unfiltered-index tint cycling reserves mauve for awesoMux and
  peach for attention, while explicit colors remain authoritative.
- The expanded create header is a 30-point primary plus 24-point options split
  control, and the collapsed rail uses a 40-point menu. The default and
  current-directory commands now have distinct group/directory semantics and
  all pointer creation routes share a 400 ms duplicate guard. Standard and
  compact sidebar density is selectable, persisted, and applied live.
- The sidebar now chains one tested lifted-row projection after search: Needs
  Input renders first in sticky arrival order, Pinned follows in explicit user
  order, pinned wins deduplication, and ownership groups retain identity while
  hiding lifted rows. Ordered IDs decode compatibly from older snapshots and
  are rejected if duplicated or stale. Expanded rows retain origin tint and
  label; the rail uses the same navigation order with distinct warning/pinned
  glyphs. Secondary-click menus provide real `New Workspace Here` and
  `Pin`/`Unpin` routes, and a real two-section fixture was inspected.
- Workspace row actions now include sanitized rename, cross-group moves, and
  bounded Pinned ordering. Rename refreshes regular, lifted, rail, search, and
  persisted representations; moving preserves terminal/pane identity and
  rebinds the row menu to its destination group.
- Regular and Needs Input row menus now provide non-pointer workspace ordering:
  bounded `Move Workspace Up`/`Move Workspace Down`, named previous/next-group
  alternatives, and arbitrary destination groups. A tested availability model
  drives edge enablement. GTK reorders the existing row and collapsed rail
  projections while retaining terminal runtimes, then refreshes affected menus
  after each identity-based mutation.
- Every regular, Needs Input, and Pinned workspace row can open its complete
  native action popover with Menu or Shift+F10. Keyboard controllers follow the
  row across context-menu rebuilds, group moves, lifted projection changes,
  close/clear, and group teardown, providing a non-pointer route to the same
  rename, acknowledge, notification, pin, pane jump, move, close, and clear
  actions as secondary click.
- Native GTK drag sources and drop targets now reorder ownership rows within
  and across groups, append workspace drops on group headers, reorder group
  headers, and reorder Pinned rows. A process-scoped payload nonce rejects
  external data, filtering disables every structural source/target, midpoint
  indicators reject no-op destinations, and each accepted drop performs one
  authoritative snapshot mutation before existing GTK rows are reconciled.
  Dark, Latte, and high-contrast insertion styles are present. The app launches
  cleanly with all controllers attached; physical drag execution remains an
  explicit QA gap because XTest pointer events do not reach this remote app.
- Long group labels now ellipsize inside their assigned column instead of
  displacing the complete sidebar. The titlebar gives its fixed 296-point brand
  column and remaining pane-title region independent allocation, preserving the
  reference alignment for both left and right sidebar placement with long
  workspace titles. Both mirrored layouts were inspected in the real app.
- Initial split positions now derive from the `GtkPaned` logical allocation
  rather than a hard-coded 1440×900 estimate. A real `GDK_SCALE=2` run keeps
  both Ghostty panes visible and scales the 296-point sidebar to 592 physical
  pixels without clipping long sidebar text.
- Collapsed group headers now preserve hidden agent visibility with a tested
  Needs Input/Error/Thinking rollup (in that priority order, excluding passive
  Output). The 60-point rail includes group buttons whose native popovers list
  every live workspace as an explicit keyboard/screen-reader `Jump to` action;
  roster names and counts refresh after model mutations.
- Ghostty OSC title and working-directory actions now cross the language-neutral
  shim into Swift callbacks. Stable pane generations reject recycled/stale
  surfaces; sanitized updates land in the authoritative snapshot before rows,
  search, lifted projections, accessibility labels, window title, and the
  focused-pane footer refresh. User-renamed workspace titles remain fixed.
  The real terminal integration emits OSC 2 and OSC 7 and requires both
  callbacks to arrive.
- Expanded multi-pane workspace rows now publish a tested pane-tree-order peek
  projection and reveal the reference-width card after 180 ms. The card shows
  workspace rollup state, authoritative focused cwd, pane numbers, pane-local
  state, and active identity, then routes a pane click through the existing
  workspace-select/exact-pane-focus path. Its host follows a workspace into
  Needs Input or Pinned, card handoff receives the reference 220 ms grace, and
  transient popup content does not steal keyboard focus. The row context
  surface exposes the same panes as explicit `Jump to pane N` actions for the
  keyboard/screen-reader path. A real Pinned-row capture was inspected; full
  physical-pointer and Orca action invocation remain pending.
- Workspace rows, lifted Needs Input/Pinned rows, collapsed-rail controls, and
  multi-pane peek cards now share one provider-aware tile projection. Claude,
  Codex, OpenCode, Pi, Grok, and shell retain distinct owned scalable marks and
  reference tint families; non-idle states add a second shape/glyph signal, and
  collapsed tiles reduce quiet states to dots while preserving explicit Needs
  Input/Error marks. Workspace rollup selects the highest-priority pane state,
  and accessible descriptions state provider plus status. Owned Cairo paths
  independently reproduce the pinned burst, open spiral, bracket,
  interlocking-ring, and shell geometries; Pi uses the owned mono stack. Glyph
  children are hidden from AT-SPI while the tile publishes the complete label.
  Expanded real-app matrices were inspected at 1440×852 in Latte, Mocha, and
  HighContrast, and live runtime-event ingestion is now verified separately.
- Expanded regular and lifted rows now reserve a stable trailing slot for a
  24-point sibling close button that reveals on pointer or keyboard focus;
  its click route cannot fall through to workspace selection. Group headers
  use the same sibling-overlay rule and replace the count with `Close Group`
  on hover/focus, while an expanded empty group leaves the action visible.
  Filtering and collapsed group bodies suppress unsafe/resting variants through
  a tested pure policy. Real hover renders and a soft-close/reopen round trip
  were inspected without blank wrapper rows.
- The collapsed rail now derives Control-1…9 digits and actions from the same
  unfiltered lifted-first projection used to render its rows. A tested display
  policy keeps digits hidden in expanded mode, action enablement follows the
  current workspace count, and direct application-action QA proved exact first
  workspace routing. The remote X11 synthetic-input limitation prevented a
  trustworthy held-Control screenshot; physical held-key QA remains pending.
- Needs Input acknowledgement is pane-scoped and persistent. Arrival order is
  now driven by the authoritative transition-updated ID list, so later arrivals
  append without displacing existing rows and the projection cannot resurrect
  an acknowledged pane from stale raw agent state. A guarded 500 ms passive
  dwell acknowledges only the focused pane, retains the selected row through a
  runtime-only sticky until navigation away, and refuses to clear permission or
  explicit-input prompts. Ctrl-Shift-K and the row action deliberately clear
  every waiting pane immediately. Fast selection/focus changes invalidate the
  pending dwell; the sticky is never serialized. Per-workspace notification
  mute overrides also persist and use exact Mute/Unmute wording. Seventy-four
  Swift tests and full preflight cover the transition model; physical dwell
  timing and spoken return announcements remain real-app QA gaps.
- Sidebar and adjacent footer styling now live in an owned focused GTK
  stylesheet with Catppuccin Mocha/Latte and high-contrast ramps derived from
  the pinned design tokens. System appearance, explicit Light/Dark,
  high-contrast theme overrides, reduced-motion preference, and density resolve
  through a tested pure policy. The four pinned OFL Geist faces are packaged
  and registered process-locally with Fontconfig; real Latte and Mocha windows
  were run and inspected. An Arabic-locale real-app pass verifies GTK's RTL
  mirroring for titlebar/sidebar placement, split-create segments, row/group
  alignment, both footer surfaces, and the two-pane content boundary. Owned CSS
  font sizes now follow a defensively clamped GTK Xft DPI/accessibility scale;
  a real 1.5× pass verifies truncation and natural control growth across the
  sidebar and both footers without changing the 296-point host width.
- Visible sidebar navigation now has a tested Up/Down/Home/End policy spanning
  lifted rows, group disclosures, ownership rows, and per-group creation rows.
  Workspace rows now construct with list/tree-item roles, and groups construct
  as level-one tree items. GTK controls publish explicit names/descriptions,
  selected/expanded state, color, attention, and native position/set-size
  relations at the component seam. Because GTK 4.14 does not translate its
  integer set relations into AT-SPI object relations, the live descriptions
  also publish `Position N of M`; direct bus inspection verified lifted rows
  and all three fixture groups. Singular/plural group counts are tested. Row
  descriptions advertise the Shift+F10 action menu, and the opened menu
  exposes every named action. Compact icon/footer targets are at least 24
  points. The exact `Focus Sidebar` command now maps Command-Control-S to Linux
  Control-Super-S, unhides the sidebar, and hands terminal focus to the
  expanded search field or the selected collapsed-rail row. Both visible focus
  states were exercised through the exported GTK action and inspected at
  original resolution. Empty-search arrows route directly into the logical
  hierarchy, with the first expanded row's AT-SPI focused state and native
  outline inspected in the real app. Agent state chips are
  buttons that open the panel filtered to the chosen state. Orca enumerates
  the running app through AT-SPI. Group disclosure, color, close,
  workspace/pinned/group reorder, pin/unpin, Needs Input promotion (including
  unanswered turns), and return transitions now publish GTK accessibility
  status announcements with tested reference wording. A real pane event was
  observed on the AT-SPI bus as an `Object.Announcement` carrying the exact
  unanswered-turn sentence at medium priority while terminal focus remained
  unchanged. Full spoken navigation and audible Orca output verification remain
  pending.
- Workspace rows now expose real soft close and permanent clear actions. Soft
  close records a bounded, 24-hour recovery snapshot, removes the row from all
  projections, selects the next live workspace, and powers Ctrl-Shift-T
  reconstruction without draining recovery state until GTK rebuild succeeds.
  Clear always confirms with baseline permanent-close copy, creates no reopen
  entry, and tears down the workspace's terminal surfaces and UI ownership.
- A real inspected screenshot and comparison index were pushed in focused
  visual-QA commits `4149963` and `01cc8d7`. The newer multi-pane peek capture
  is retained locally and intentionally remains unpushed pending resolution of
  the earlier implementation-history push boundary mistake.

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
3. Physically verify pointer reorder and insertion indicators. Dynamic group
   menu enablement plus both left/right hidden attention reveal paths and timed
   retraction are captured and inspected.
4. Add bounded/coalesced persistence writes, recovery UI, and forced-termination tests.
5. Continue through the root implementation order, capturing each required
   visual milestone.

The verified SwiftGtk4 baseline began at `260e917`. Later implementation
ancestors were unintentionally included when visual-QA commit `6a198bc` was
pushed; that boundary mistake is recorded above, and subsequent implementation
and screenshot work remains local pending explicit direction.
