# Visual QA

## 2026-09-05 — current macOS baseline and titlebar/sidebar correction

The comparison now pins macOS **`2fd33a0`** (2026-09-05 remote `main`), with a
new release build and [revision-specific fixture index](macos-reference/2fd33a0/titlebar-sidebar/README.md).
The older `fed33ff` images below remain historical evidence.

| State | Current macOS reference | Linux release |
| --- | --- | --- |
| Dark, expanded sidebar | [macOS](macos-reference/2fd33a0/titlebar-sidebar/macos-dark.png) | [Linux](swift-gtk/progress/52-current-reference-sidebar/dark.png) |
| Light, expanded sidebar | [macOS](macos-reference/2fd33a0/titlebar-sidebar/macos-light.png) | [Linux](swift-gtk/progress/52-current-reference-sidebar/light.png) |
| Empty, no workspace | Not paired in this pass | [Linux](swift-gtk/progress/52-current-reference-sidebar/empty.png) |
| Collapsed sidebar | Not paired in this pass | [Linux](swift-gtk/progress/52-current-reference-sidebar/rail.png) |
| Right sidebar | Not paired in this pass | [Linux](swift-gtk/progress/52-current-reference-sidebar/right.png) |
| High contrast | Not paired in this pass | [Linux](swift-gtk/progress/52-current-reference-sidebar/hc.png) |

- **Geometry:** paired windows are 1440×888 logical points, with 296-point
  expanded sidebars. macOS PNGs are 2880×1776 at Retina 2×; Linux PNGs are
  1440×888 at 1×. All Linux captures use the real XWayland/GLX release app.
- **Fixture:** two groups, three named synthetic workspaces, equally sized
  terminal panes, right-pane focus. Selected panes show `/tmp` and `qa$`;
  dormant rows show `~`. No terminal history, private repository locations,
  credentials, clipboard data, or arbitrary agent output is retained.
- **Corrected:** the ツ/uppercase wordmark, integrated gradient titlebar,
  folder/title anchored to the content column, group-colored selected-row
  border/glow, elevated idle rows, close controls, group-header footprint,
  search/creation-row density, metadata size/order, and sidebar separator.
  The light-titlebar selector now matches its actual theme-class owner.
  Group-color mutations refresh existing rows rather than leaving stale tints.
  Collapsed icons fit their rail; the right-sidebar wordmark aligns with its
  column, with native window controls at the opposite edge. High-contrast
  window-control glyphs remain visible.
- **Measurements:** search begins at y=48 in both captures. The first selected
  row begins at approximately y=114.5 on macOS and y=115 on Linux; regular
  row heights are approximately 55 points on both. The third row begins near
  y=305 in both. Measurements use native PNG pixels divided by capture scale;
  antialiased borders/glow account for half-point edges.
- **Verification:** final local `./script/preflight.sh` passes 134 Swift tests,
  debug/release builds, secondary activation, command enablement, forced-quit
  persistence, X11 and native Wayland terminal integration, and 100 two-surface
  lifecycle cycles on each backend. Wording regeneration/check and
  `git diff --check` pass. Every retained image was inspected.
- **Still partial:** native Wayland app-local capture has no usable compositor
  allocation in this unattended launch; a passing native runtime harness does
  not close that visual gate. Font/symbol outlines, group action controls,
  the exact selected-rail shape, footer proportions/tint, and the light-mode
  pane-focus color still differ. Physical hover/drag, keyboard/Orca, fractional
  scale, and additional current-macOS surfaces remain unverified. The unpaired
  states above are Linux regression evidence, not macOS parity claims.
- **Baseline upkeep:** the source/wording pin is centralized in
  `shared/product-contract/reference-baseline.json`; the wording tools read
  pinned Git objects from the clean reference. Future passes should resolve
  current `main`, capture that exact revision, and retain older evidence under
  its original commit. This refresh does not upgrade the Linux Ghostty ABI or
  imply feature parity with newly added macOS capabilities.


## 2026-08-30 — SwiftGtk4 pane-header and focus-token correction

- Linux images: [vertical focus B](swift-gtk/progress/51-pane-header/x11-dark-vertical-focus-b.png)
  and [horizontal focus B](swift-gtk/progress/51-pane-header/x11-dark-horizontal-focus-b.png).
  Both are privacy-safe 1440 × 888 release-app XWayland captures with two real
  Ghostty surfaces running the capture-gated `qa$` terminal command.
- Reference trace: the clean pinned macOS source at
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116` confirms that everyday multi-pane
  chrome contains a 4-point focus band and a fixed 24-point `PaneTitleBarView`.
  It also confirms that the lower single pane in a stacked split absorbs its
  focus band into the adjacent divider. Default Mocha divider tokens are
  `#8c674f` at rest and `#a1765b` on hover; the focused peach is `#fab387`.
- Correction: each multi-pane GTK terminal now owns the same 4 + 24 vertical
  structure, including a sanitized ellipsized title and a named 24-point Close
  Pane control. The former blue/gray focus and divider colors use the pinned
  peach/muted family. Stacked splits paint the lower pane's focus on the
  existing `GtkPaned` separator while suppressing its duplicate top edge;
  GTK still owns the one-point allocation, native hit target, drag, keyboard
  resize, terminal allocation, and reflow.
- Measurement: the vertical focused band is four exact `#fab387` rows
  (`y=39…42`) above a 24-row `#171721` pane header (`y=43…66`). The vertical
  rest divider remains two visible `#8c674f` rows around its one-point GTK
  allocation. In the stacked frame, absorbed focus is four exact `#fab387`
  rows (`y=441…444`) immediately above the lower header.
- Inspection: both retained images were opened at original resolution. The
  focus band/header/divider relationship is continuous, both terminal
  framebuffers are complete, inactive dimming remains pane-local, titles and
  close controls do not clip, and the stacked lower pane has no duplicate
  focus rail.
- Native evidence boundary: the release app registered and ran cleanly with
  GTK's Wayland backend and an isolated profile, but the unattended COSMIC
  launch did not receive a current window allocation for app-local snapshotting;
  the desktop screenshot portal requires interactive consent. No native image
  or physical-input claim is made from that attempt. Native pointer hover,
  held drag, keyboard divider focus/resize, and the paired theme/scale/RTL/IME/
  Orca matrix remain open, so pane boundaries are still excluded from
  `VISUAL_PARITY_ACHIEVED.md`.
- Privacy: the capture-only terminal override is accepted only when a visual-QA
  capture path is also active. The retained frames contain `qa$`, `/tmp`, and
  synthetic `Primary terminal` labels only—no host identity, history, typed
  commands, clipboard data, credentials, private paths, or agent output.

## 2026-08-29 — SwiftGtk4 primary-window decoration implementation

- Linux images: [native Wayland client-owned titlebar](swift-gtk/progress/50-primary-window-decoration/native-wayland-client-titlebar.png)
  and [X11 client-owned titlebar](swift-gtk/progress/50-primary-window-decoration/x11-client-titlebar.png).
- Implementation: the existing 38-point awesoMux titlebar is now installed as
  GTK's client-side titlebar and explicitly owns native minimize, maximize,
  and close controls. The former duplicate outer header is absent.
- Inspection: both 1440 × 888 release frames were opened at original
  resolution. The titlebar, sidebar brand, centered focused-pane title, three
  native controls, and content form one continuous window surface without
  clipping. The first native pass exposed compositor-default suppression of
  minimize/maximize; the explicit GTK decoration layout corrected it before
  the indexed native frame was retained.
- Status: implementation and native Wayland rendering are verified. Paired
  macOS comparison plus the complete theme/accessibility interaction matrix
  remain required before closing the audit finding.
- Privacy: the isolated fixture contains only synthetic shell identity and
  `/tmp`; it contains no history, commands, clipboard data, credentials,
  private paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 pane-boundary implementation pass

- Linux images: [vertical split](swift-gtk/progress/49-pane-boundary/native-wayland-vertical-focused.png),
  [horizontal split](swift-gtk/progress/49-pane-boundary/native-wayland-horizontal-focused.png),
  [nested split](swift-gtk/progress/49-pane-boundary/native-wayland-nested-focused.png),
  [focused/unfocused scrim](swift-gtk/progress/49-pane-boundary/x11-focused-unfocused-scrim.png),
  [focus transferred to pane one](swift-gtk/progress/49-pane-boundary/x11-focus-switched-pane-one.png),
  [live attention](swift-gtk/progress/49-pane-boundary/x11-attention.png),
  [live error](swift-gtk/progress/49-pane-boundary/x11-error.png),
  [high contrast](swift-gtk/progress/49-pane-boundary/x11-high-contrast.png),
  and [reduced motion](swift-gtk/progress/49-pane-boundary/x11-reduced-motion.png).
  Native Wayland scale/narrow-layout images cover
  [125%](swift-gtk/progress/49-pane-boundary/native-wayland-scale-125.png),
  [150%](swift-gtk/progress/49-pane-boundary/native-wayland-scale-150.png), and
  [200%](swift-gtk/progress/49-pane-boundary/native-wayland-scale-200.png).
- Paired macOS inputs: the [pinned-reference fixture index](macos-reference/fed33ff/pane-boundary/README.md)
  records focused vertical and horizontal A/B states, nested focus, pointer
  hover on both axes, pointer drag before/after, keyboard resize before/after,
  and a narrow nested layout. The wide reference window is the same 1440 x 888
  logical size as the Linux Wayland fixtures; the narrow reference is 900 x
  700. All twelve retained reference PNGs were inspected at original
  resolution.
- Reference: `TerminalSplitLayoutView.swift` and
  `TerminalPaneFocusChrome.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content: the real 1440 × 888 release app on native COSMIC Wayland at
  100% scale, using isolated profiles and `/tmp`-only terminal working
  directories. Each image contains real independently rendered Ghostty panes.
- Implementation: `GtkPaned` retains native resize, allocation, pointer, and
  keyboard semantics while app-owned CSS replaces its wide visual handle.
  Pane-owned top edges distinguish focused, unfocused, needs-attention, and
  error states, and an input-transparent scrim matches the reference's 0.32
  inactive-pane dimming. High contrast uses a thicker black/white non-color cue
  and reduced motion removes the 150 ms transitions. Dividers expose
  orientation-specific names and keyboard-resize descriptions.
- Inspection: every listed PNG was opened at original resolution. The focused
  edge and inactive scrim transfer to the exact focused leaf; live provider
  events produce distinct attention and error rails; high contrast remains
  visible against the dark terminal; terminal allocations remain complete.
  COSMIC constrained the logical window from 1364×696 through 852×408 as scale
  increased, exercising title truncation, terminal reflow, fixed sidebar/footer
  ownership, and increasingly narrow split panes without holes or clipping.
  The display was restored and confirmed at 2560×1440@99.946 Hz, 100% after
  every pass.
- Accessibility: direct AT-SPI inspection of the native Wayland release app
  initially found unnamed generic `GtkPaned` objects despite accessible label
  properties. The app now constructs pane splits with the explicit GTK
  `separator` role. After a clean nested-layout launch, AT-SPI exposed both
  `Vertical pane divider` and `Horizontal pane divider`, each with the exact
  description `Use arrow keys to resize the adjacent terminal panes` and the
  `Component`, `Value`, and `Action` interfaces. GTK 4.14 reports zero minimum
  increment and rejects `GrabFocus`; setting `CurrentValue` also leaves the
  allocation unchanged, so direct assistive manipulation and audible Orca are
  not claimed.
- Comparison result: the macOS fixtures now establish the reference behavior
  over time, including hover, drag, keyboard resize, and focus transfer. Linux
  structurally matches the split axes and nested allocation, but the retained
  Linux focused rail is brighter/bluer than the muted reference accent and the
  Linux pane surface does not yet reproduce the reference pane-header layer.
- Status: implementation and baseline native rendering are complete, but
  visual parity is not yet verified. Physical hover/drag and keyboard divider
  focus/resize remain unproved in the Linux app, along with audible Orca and
  the paired appearance/accessibility matrix. The 1440×888 native frames serve
  as the wide-window fixture. This milestone is therefore not listed in
  `VISUAL_PARITY_ACHIEVED.md`.
- Privacy: fixtures contain synthetic workspace identity and `/tmp` only; no
  terminal history, typed commands, clipboard data, credentials, private
  paths, or arbitrary agent output is present.

## 2026-08-29 — SwiftGtk4 native Wayland terminal rendering

- Linux image: [native Wayland two-pane workspace](swift-gtk/progress/48-native-wayland/native-wayland-two-pane.png).
- Reference: `TerminalView.swift`, `WorkspaceView.swift`, and the sidebar shell
  at macOS baseline `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content: the real 1440 × 888 release app using GTK's native Wayland
  backend on COSMIC, with two independently rendered Ghostty panes in one
  workspace at the monitor's 100% scale.
- Correction: the shared language-neutral shim now selects Ghostty's supported
  desktop-OpenGL path before GTK initialization. On installed GTK 4.14.5 it
  applies the canonical `gl-disable-gles`, `vulkan-disable`, and
  `gl-no-fractional` compatibility selection; GTK 4.16+ uses `GDK_DISABLE`.
- Verification: native terminal integration passes Unicode, focus, rapid
  resize/reflow, clipboard, environment, title/cwd, close-risk, and pane
  independence checks. The 100-cycle two-surface lifecycle harness passes, as
  do real integration runs at COSMIC scales 125%, 150%, and 200%. The display
  was restored to 2560×1440@99.946 Hz and 100%.
- Inspection: the PNG was opened at original resolution. Both terminal
  framebuffers are complete, the divider is continuous, prompts and cursors
  are sharp, and the sidebar/title/footer geometry has no holes or clipping.
- Privacy: an isolated profile and visual-QA-only Bash configuration provide a
  fixed prompt with no history or startup files. The image contains no typed
  commands, terminal output, clipboard data, credentials, or private paths.

## 2026-08-29 — SwiftGtk4 focused-footer interactive targets

- Linux image: [interactive focused-footer chips](swift-gtk/progress/47-focused-footer-targets/interactive-chip-targets-x11.png).
- Reference: `TerminalPathBarView.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`, where the actionable branch chip
  has a 24-point minimum height.
- Captured content: a 1144 × 38 footer-only crop from the real 1440 × 852
  release app on X11/GLX under XWayland. The app used a clean isolated profile
  and created one real local Ghostty workspace in the repository.
- Behavior and correction: interactive branch, pull-request, and CI menu chips
  now consume the shared tested 24-point target minimum. The visible `main`
  branch control occupies that full height; the noninteractive `+6` dirty
  indicator intentionally retains its compact 20-point status geometry.
- Inspection: the PNG was opened at original resolution. The path control,
  branch chip, dirty indicator, dividers, baseline, and 38-point footer remain
  vertically aligned with no clipping or movement into the terminal surface.
- Verification: full preflight passes the text baseline, all 130 Swift tests,
  warnings/release builds, single-window and dynamic-command probes,
  forced-termination persistence, real terminal integration, and 100
  two-surface lifecycle cycles.
- Privacy: the strict footer crop contains only the repository's public name,
  generic branch/status data, and product chrome. It contains no terminal
  contents, typed commands, clipboard data, credentials, or private paths.
- Upload status: published to the verified private origin under Sarah's explicit
  full-branch authorization. [Open the uploaded PNG on GitHub](https://github.com/Interactive-Buffoonery/awesoMuxchy/blob/main/artifacts/visual-qa/swift-gtk/progress/47-focused-footer-targets/interactive-chip-targets-x11.png).

## 2026-08-29 — SwiftGtk4 command availability boundaries

- Linux image: [zero-workspace command palette](swift-gtk/progress/46-command-availability/empty-palette-latte-x11.png).
- Reference: `PaletteCommand.swift`, `AwesoMuxApp.swift`, and the command
  availability tests at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Architecture and behavior: one pure `CommandAvailabilityProjection` now
  drives initial GAction state, every live refresh, and the command palette's
  immutable summon snapshot. It covers selected workspace/cwd, pane and
  workspace counts, attention and unanswered turns, recently closed state,
  active sheets, jump bounds, and sidebar-target availability. The workspace
  context menu uses the same acknowledgement predicate, including unanswered
  turns that do not carry a blocking agent state. Unimplemented catalog items
  are omitted from GTK actions and menus instead of appearing as disabled
  placeholders.
- Real-app QA: the release-process probe starts from a genuinely empty profile,
  crosses one workspace, two panes, a second workspace, pane routing, and an
  active naming sheet. It verifies disabled no-op actions at every boundary,
  exact enabling after each model change, and the reference's deliberate split
  availability while a sheet is presented.
- Inspection: the 606×506 Latte popup was inspected at original resolution.
  Its bare query contains only `New Workspace` under `SUGGESTED`; `New
  Workspace in Current Directory` and `Reopen Closed Workspace` are absent,
  no row is implicitly selected, the focused search ring is visible, and the
  complete native shadow is intact.
- Verification: full preflight passes the text baseline, all 125 Swift tests,
  warnings-as-errors and release builds, single-window and expanded
  dynamic-command probes, both forced-termination cases, terminal integration,
  and 100 two-surface lifecycle cycles.
- Privacy: the profile contains zero workspaces and therefore creates no
  terminal. The popup-only capture contains no shell identity, terminal
  content, commands, credentials, clipboard data, private paths, or arbitrary
  agent output.

## 2026-08-29 — SwiftGtk4 unified command palette

- Linux image: [collapsed-search unified palette](swift-gtk/progress/45-command-palette/unified-command-palette-latte-x11.png).
- Reference: `PaletteResult.swift`, `PalettePresenter.swift`, and
  `CommandPaletteView.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Architecture and behavior: collapsed Search and Control-K open one shared
  focusable GTK popover parented to the primary window. A tested immutable
  summon projection groups workspaces before enabled actions, keeps source
  order as the fuzzy-score tie-breaker, searches workspace title/path/group,
  caps workspace results at 50, exposes curated suggestions for a bare query,
  and maps a leading `>` to actions-only mode. Bare Return has no implicit
  target; Up/Down clamps from either edge, Return opens the exact selected
  workspace/action, and Escape dismisses. A tested follow-up geometry policy
  preserves the 520×420 card when space permits, applies a 16-point inset in
  narrow windows, and scrolls keyboard-selected results into view.
- Real-app QA: AT-SPI invoked the collapsed 40-point `Search` action, found one
  editable `Command palette search`, verified `WORKSPACES` and `SUGGESTED`
  sections plus result positions, entered `> split`, and observed only the two
  enabled split actions with the exact `Actions only mode` badge. GTK 4.14 on
  this automated XWayland display reports no focused AT-SPI object for the
  popup, but the inspected frame visibly proves the search focus ring and the
  editable interface accepted both queries.
- Inspection: the 606×506 native popup surface was inspected at original
  resolution. Its 520×420 Latte card shows the synthetic owner-only
  `Baseline`/`awesoMux`/`/tmp` fixture, exact placeholder, separate result
  sections/counts, no selected result before user input, footer keyboard hints,
  border, rounded corners, and complete shadow without terminal pixels.
- Verification: full preflight passes the text baseline, all 121 Swift tests,
  warnings-as-errors and release builds, single-window and dynamic-command
  probes, both forced-termination cases, terminal integration, and 100
  two-surface lifecycle cycles.
- Privacy: the fixture was written by the repository persistence probe; the
  popup-only capture contains no shell identity, terminal content, commands,
  credentials, clipboard data, private paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 clean-profile recovery

- Linux image: [missing-profile empty state with sidebar focus](swift-gtk/progress/44-clean-profile-recovery/empty-focus-sidebar-latte-x11.png).
- Reference: `ContentView.swift`, `SidebarView.swift`, empty-workspace
  presentation, and the `Focus Sidebar` command at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Accessibility correction: the centered visible `+  New Workspace` label is
  now an accessibility-hidden decorative child, so the parent button exposes
  the exact `New Workspace` name rather than speaking the plus glyph. The same
  seam protects the conditional reopen label and existing icon/text buttons.
- Real-app QA: a genuinely missing profile launched with zero groups and no
  selected workspace. The exported `Focus Sidebar` action moved focus to the
  named `Search sessions` box. Direct AT-SPI inspection found the centered
  button as a button named exactly `New Workspace` with one `Click` action;
  invoking it returned true and persisted exactly one group, one selected
  workspace, and one pane.
- GTK note: `org.a11y.atspi.Component.GrabFocus` returned failure for ordinary
  GTK header and empty-state buttons on this GTK 4.14 stack, so the evidence
  uses the app-owned focus command plus the successful AT-SPI action rather
  than claiming that inspector method as keyboard delivery.
- Inspection: the privacy-safe 1440×852 Latte X11/GLX frame was inspected at
  original resolution. It shows the complete zero-workspace surface, visible
  search focus ring, fixed 296-point sidebar, centered actionable recovery,
  and neutral zero-agent footer without fabricated terminal context.
- Verification: full preflight passes the text baseline, all 113 Swift tests,
  warnings-as-errors and release builds, the single-window activation probe,
  both forced-termination persistence cases, real terminal integration, and
  100 two-surface lifecycle cycles.
- Privacy: no terminal exists in the captured state. The rejected post-create
  crop contained shell-derived identity/path text and was removed before
  staging; structural success was verified only from bounded identity counts.

## 2026-08-29 — SwiftGtk4 passive attention dwell

- Linux images: [background attention promotion](swift-gtk/progress/43-attention-dwell/background-attention-mocha-x11.png)
  and [return to the origin group after dwell and navigation](swift-gtk/progress/43-attention-dwell/returned-after-dwell-mocha-x11.png).
- Reference: `SelectionAcknowledgementCoordinator.swift`,
  `SidebarAttentionProjection.swift`, and Needs Input transition handling at
  macOS baseline `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Correctness: the production 500 ms callback now runs on GTK's GLib main loop
  rather than Swift's dispatch main queue, which does not drain while this
  Linux process is inside `g_application_run`. Attention arriving after pane
  focus has already settled starts the same dwell as focus entry.
- Timing seam: an injected scheduler pins the exact 500 ms delay, rejects a
  changed workspace/pane identity, permits only the newest uninterrupted
  request, and verifies explicit cancellation. Permission and user-input
  prompts remain protected from passive acknowledgement by the model gate.
- Real-app QA: an owner-only live event promoted a background pane, then the
  release app selected and passively acknowledged that exact pane through the
  GLib timeout. The owner-only snapshot retained the attention state while its
  acknowledged-pane list changed from empty to that pane identity. Navigation
  released the runtime-only sticky and returned the row to its unchanged
  origin group.
- Inspection: both 296×852 Mocha crops were inspected at original resolution
  on X11/GLX. The promotion frame keeps Needs Input above Pinned; the return
  frame has no duplicate lifted row, preserves origin ordering, and keeps the
  fixed header/footer intact. The capture helper now requests a complete X11
  expose before reading rootless-XWayland pixels, preventing damage holes.
- Verification: full preflight passes the text baseline, all 113 Swift tests,
  warnings-as-errors and release builds, the single-window activation probe,
  both forced-termination persistence cases, real terminal integration, and
  100 two-surface lifecycle cycles.
- Privacy: the isolated fixture uses synthetic identities and `/tmp`; the
  crops contain no terminal content, commands, credentials, clipboard data,
  private paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 standard and compact sidebar density

- Linux images: [compact sidebar](swift-gtk/progress/42-compact-density/compact-sidebar-mocha-x11.png)
  and [standard sidebar](swift-gtk/progress/42-compact-density/standard-sidebar-mocha-x11.png).
- Reference: `SidebarSupport.swift`, `SidebarGroupView.swift`,
  `SidebarPinnedSectionView.swift`, and `SidebarAttentionSectionView.swift` at
  macOS baseline `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Geometry: the live density preference now changes native GTK container
  spacing as well as CSS. Standard uses 14-point group, 3-point header/body,
  and 5-point session spacing; Compact uses 8, 1, and 3 points respectively.
  GTK row min-heights and padding preserve the corresponding Standard/Compact
  rhythm, while empty-creation padding matches the reference's 7/5-point
  values and retains a 24-point minimum target.
- Creation rows: visible copy is the reference lowercase `new workspace`, the
  accessible name is `New workspace in <group>`, and the resting surface uses
  a quiet elevated fill without an invented dashed border. The explicit drop
  target keeps its separate drag-and-drop outline.
- Inspection: both 296×852 Mocha crops use the same synthetic fixture and were
  inspected at original resolution on the verified X11/GLX path. Header and
  footer stay fixed while the Compact capture visibly tightens group, session,
  and creation-row rhythm without clipping controls or metadata.
- Verification: full preflight passes the text baseline, all 111 Swift tests,
  warnings-as-errors and release builds, the single-window activation probe,
  both forced-termination persistence cases, real terminal integration, and
  100 two-surface lifecycle cycles.
- Privacy: the fixture uses synthetic names and `/tmp`; the images contain no
  terminal content, commands, credentials, clipboard data, private paths, or
  arbitrary agent output.

## 2026-08-29 — SwiftGtk4 activity-panel consistency

- Linux images: [expanded activity panel with live title](swift-gtk/progress/41-activity-panel-consistency/activity-panel-live-title-x11.png)
  and [collapsed panel dismissal with row focus](swift-gtk/progress/41-activity-panel-consistency/collapsed-panel-dismissal-focus-x11.png).
- Reference: `SidebarStatusFooter.swift`, `AgentActivityPanel.swift`,
  `AgentActivityRoster.swift`, and sidebar display-mode handling at macOS
  baseline `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: the panel now derives a single-pane row title from the same coarse
  live-title projection as the sidebar, refreshes after workspace rename and
  every pane title/cwd callback, and persists nonfocused-pane cwd updates
  before reprojecting the roster. Collapsing the sidebar closes the panel,
  clears its state filter and sidebar search, and restores sidebar-owned focus
  to the selected rail row; expanding restores it to the selected expanded row.
  A terminal-focused mode change still leaves focus in the terminal.
- Real-app QA: AT-SPI edited `Search sessions` to a no-match query, opened the
  total-agent disclosure, and invoked the real GTK collapse/expand action.
  Direct inspection verified that the panel disappeared, did not resurrect,
  the search value became empty, and the selected row owned keyboard focus in
  both modes. The expanded roster showed the synthetic live title and `/tmp`
  location and selected the same pane identity as the sidebar.
- Visual correction: the first Latte activity-row pass exposed insufficient
  selected-row text contrast. The selected title and location now use the
  audited Latte foreground, and named WCAG checks cover both combinations.
- Inspection: the 296×852 expanded crop and 60×852 rail crop were inspected at
  original resolution on the verified X11/GLX path. The fixed footer geometry,
  selected state, keyboard-only focus outline, panel grouping, and readable
  live row metadata remain distinct and unclipped.
- Single-window follow-up: the activation handler now presents its retained
  primary window instead of rebuilding application state and chrome. A real
  release-process probe launches the executable once, launches it three more
  times through GApplication activation, and requires exactly one X11 normal
  window throughout. The probe uses an isolated profile and a test-only
  application ID on the existing desktop bus so it cannot disturb AT-SPI.
- Verification: full preflight passes the text baseline, all 110 Swift tests,
  the warnings-as-errors and release builds, both forced-termination
  persistence cases, real terminal integration, and 100 two-surface lifecycle
  cycles.
- Privacy: the isolated fixture uses synthetic names and `/tmp`; the crops
  contain no terminal content, commands, credentials, clipboard data, private
  paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 lifted-section structural motion

- Linux images: [Pinned insertion mid-transition](swift-gtk/progress/40-structural-motion/pinned-section-transition-x11.png),
  [Pinned insertion settled](swift-gtk/progress/40-structural-motion/pinned-section-settled-x11.png),
  and [Pinned removal mid-transition](swift-gtk/progress/40-structural-motion/pinned-section-removal-x11.png).
- Reference: `SidebarGroupView` and `SidebarSessionTile` at macOS commit
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`; structural list motion uses
  140 ms ease-out and becomes identity under reduced motion, while filtering
  suppresses structural animation.
- Behavior: Needs Input and Pinned sections now use GTK revealers for vertical
  structural insertion/removal. Initial layout, active filtering, or GTK's
  reduced-motion setting selects a zero-duration transition. Concealed section
  content is hidden from accessibility immediately and its revealer is removed
  from layout after the visual transition, with stale hide callbacks guarded
  against a rapid reappearance.
- Inspection: direct native action activation captured a partially revealed
  Pinned section, its complete 140 ms destination, and its collapsing removal.
  All three 296×852 Latte crops were inspected at original resolution; fixed
  header/footer geometry, group rows, selection, and the existing Needs Input
  projection remain stable.
- Verification: full preflight passes the text baseline, all 107 Swift tests,
  release build, forced-termination persistence cases, terminal integration,
  and 100 two-surface lifecycle cycles.
- Privacy: the isolated fixture uses synthetic names and `/tmp`; the crops
  contain no terminal content, commands, credentials, clipboard data, private
  paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 structural focus recovery

- Linux images: [focus after pin promotion](swift-gtk/progress/39-structural-focus-recovery/pinned-row-focus-recovery-x11.png),
  [focus after return to the origin group](swift-gtk/progress/39-structural-focus-recovery/origin-row-focus-recovery-x11.png),
  and [focus after group reorder](swift-gtk/progress/39-structural-focus-recovery/group-reorder-focus-recovery-x11.png).
- Reference: Pinned/Needs Input projections, workspace/group reorder actions,
  and keyboard-focus behavior at macOS commit
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: sidebar-owned focus is captured before pin, acknowledge, or mute
  rebuilds and restored on the newly projected identity after GTK finishes the
  mutation. Pinned, ordinary, and collapsed-rail destinations resolve by
  stable workspace ID. Workspace/pinned/group reorder actions likewise return
  focus to the moved identity; commands initiated from the terminal do not
  steal focus back into the sidebar.
- Real-app QA: exported GTK actions promoted and returned the selected
  workspace while the visible focus-only close affordance followed it between
  Pinned and its origin group. AT-SPI opened the real group action menu and
  invoked `Move Group Down`; the persisted order became Archive, Contrast and
  the moved Contrast disclosure retained its focus-only close affordance.
- Inspection: all three 296×852 Latte X11 crops were opened at original
  resolution. Focus is distinct from selection, the synthetic sections and
  empty group remain aligned, and no row is duplicated or clipped.
- Privacy: the isolated fixture uses synthetic names and `/tmp`; the crops
  contain no terminal content, commands, credentials, clipboard data, private
  paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 chrome contrast audit

- Linux image: [Latte agent-state sidebar](swift-gtk/progress/38-contrast-audit/latte-agent-state-contrast-x11.png).
- Audit: a pure WCAG 2.2 contrast model now asserts 37 named Mocha, Latte,
  and high-contrast pairings for text, focus, control boundaries, semantic
  agent states, and all six provider/shell glyph treatments. Text requires
  4.5:1, non-text controls and glyphs require 3:1, and enhanced
  high-contrast text requires 7:1.
- Correction: Latte compact metadata and agent-state colors were darkened,
  selected blue actions were strengthened, and low-contrast Mocha/Latte
  control boundaries were raised to the audited token. Status continues to
  use symbols, labels, and counts in addition to color.
- Verification: full preflight passes the text baseline, all 106 Swift tests,
  the release build, both forced-termination persistence cases, terminal
  integration, and 100 two-surface lifecycle cycles. A real window close also
  completed without GTK diagnostics after explicitly detaching row popovers.
- Inspection: the 296×852 strict sidebar crop was opened at original
  resolution. The selected row, focus outline, dividers, compact metadata,
  Needs Input treatment, provider tiles, and thinking/output/attention footer
  indicators are distinct and unclipped.
- Privacy: the isolated fixture uses only synthetic names and `/tmp`; the crop
  contains no terminal content, commands, credentials, clipboard data,
  private paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 session recovery

- Linux image: [quarantined-session recovery sheet](swift-gtk/progress/37-session-recovery/quarantined-session-sheet-x11.png).
- Reference: `SessionPersistence.swift`, the recovery-warning routes in
  `AwesoMuxApp.swift`, and exact localization baseline at macOS commit
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: a real isolated profile started with an invalid current snapshot
  and no previous snapshot. Launch moved the original bytes into the profile's
  quarantine at `0600`, selected the zero-workspace recovery surface, and
  presented one main-window-owned modal with exact reference heading/body copy.
  AT-SPI exposed the frame, heading, full message, and named `Done` button; its
  action dismissed the sheet. A clean window close then flushed valid empty
  state at `0600` while preserving the quarantine archive.
- Forced termination: the release persistence probe seeds a valid baseline,
  stages a newer snapshot through the production 500 ms coordinator, and is
  killed with SIGKILL on both sides of that boundary. The pre-debounce kill
  preserves and decodes the baseline; the post-debounce kill restores the newer
  state. This process-level check is part of local preflight.
- Verification: full preflight passes the text baseline, all 104 Swift tests,
  the production build, both forced-termination cases, rapid-reflow terminal
  integration, and 100 two-surface lifecycle cycles.
- Inspection: the 520×230 Latte X11 sheet was opened at original resolution.
  Its heading, wrapped recovery guidance, spacing, and focused blue `Done`
  action are complete and unclipped.
- Privacy: the invalid fixture is empty and the screenshot contains no terminal
  content, commands, credentials, clipboard data, private paths, or arbitrary
  agent output.

## 2026-08-29 — SwiftGtk4 split and close-pane commands

- Linux images: [Split Right pane count](swift-gtk/progress/36-pane-commands/split-right-pane-count-x11.png)
  and [close-pane risk sheet](swift-gtk/progress/36-pane-commands/close-pane-risk-sheet-x11.png).
- Reference: `PaneLayoutReducer.splitActivePane`,
  `PaneLayoutReducer.closePane`, `DestructivePaneActionConfirmationPolicy`,
  and the Pane command routes at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: exported GTK actions drove Split Right → confirmed Close Pane →
  Split Down → confirmed Close Pane in a real isolated profile. Each split
  persisted the expected axis, inherited the focused cwd, focused exactly one
  new pane, and preserved the original pane identity. Each close used the real
  live risk gate, was confirmed through the named AT-SPI action, returned focus
  to the original pane, and retired the detached Ghostty surface only after
  process exit. The final repeated sequence produced no GTK or runtime
  diagnostics. Follow-up real GTK actions drove Grow/Shrink Active Pane through
  persisted 0.50 → 0.45 → 0.50 → 0.10 fractions and a non-mutating extra clamp
  activation while retaining the same live pane identities; proportions are
  behavioral evidence only because the strict crop intentionally excludes
  terminal content. GtkPaned release now persists the exact nested split once
  per primary-button interaction and ignores allocation-time position noise;
  an isolated real launch preserved an exact 0.500 fraction without
  diagnostics. The Smithay display does not route XTest input, so no physical
  held-pointer claim is made.
- Follow-up action introspection on the same two-pane fixture exposed Focus Pane
  1/2 and Previous/Next as enabled while Pane 3–6 remained present but disabled.
  Real Pane 2 → Previous → disabled Pane 3 → Next activation persisted only the
  expected depth-first identities with clean runtime output. This is behavioral
  evidence; the selected sidebar row is unchanged and needs no duplicate image.
- The real two-surface integration now overlaps 80 GtkPaned divider moves with
  120 bounded synthetic Unicode lines, restores the split, requires an exact
  completion sentinel, and repeats focus/input/clipboard/close-risk checks on
  the same live surface. Four consecutive X11/GLX passes completed cleanly;
  this reflow stress adds behavioral evidence without exposing terminal text.
- Inspection: the 296×852 sidebar-only Latte capture was opened at original
  resolution and shows the selected `Pane Commands` row with the two-pane
  indicator/count while fixed header/footer geometry remains stable. The
  480×230 owned sheet was recaptured after rejecting an X11 partial-damage
  frame, then inspected at original resolution for exact heading, body, hint,
  safe-default Cancel, and destructive action treatment.
- Verification: full local preflight passes the text baseline, all 99 Swift
  tests, the production build, rapid-reflow terminal integration, and 100 two-surface
  lifecycle cycles.
- Privacy: the profile, workspace, pane title, cwd, counts, and status are
  synthetic. The strict sidebar and sheet crops contain no terminal content,
  commands, clipboard data, credentials, private paths, or arbitrary agent
  output.

## 2026-08-29 — SwiftGtk4 current-context workspace creation

- Linux image: [selected-group new workspace](swift-gtk/progress/35-current-context-creation/selected-group-new-workspace-x11.png).
- Reference: `NewWorkspaceSplitButton.swift`, `SidebarView.swift`, and the
  workspace command routes at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: a real isolated profile selected `Collapsed Workspace` in the
  second of three groups. Activating the expanded `New Workspace` primary
  control through AT-SPI left the first and empty groups unchanged, appended
  and selected exactly one workspace in `Selected Group`, and persisted the
  launch directory. App/menu creation now targets the canonical `awesoMux`
  default directly; current-directory creation combines selected-owner/default
  routing with the focused pane cwd. Pure coverage rejects a silent fallback
  to the first stored group.
- Inspection: the 296×852 X11/GLX sidebar-only PNG was opened at original
  resolution. `Context Workspace` is selected beneath the pre-existing row in
  `Selected Group`; the sibling counts remain `2`, `2`, and `0`, and the fixed
  header/footer and per-group creation rows remain aligned. The capture fixture
  uses a synthetic user-edited title after the creation/persistence assertion
  so live shell metadata cannot leak into visual evidence.
- Verification: full preflight passes the text baseline, all 95 Swift tests,
  the production build, real terminal integration, and 100 two-surface
  lifecycle cycles.
- Privacy: every visible group, workspace, status, count, and location is
  synthetic. The strict sidebar crop contains no terminal content, commands,
  clipboard data, credentials, private paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 focused-footer command gate

- Linux image: [agent-pane branch footer](swift-gtk/progress/34-footer-command-gate/agent-footer-branch-gate-x11.png).
- Reference: `TerminalPathBarView.swift`, `TerminalPathBarChips.swift`, and
  `TerminalPathBarMenus.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: the selected local pane declared Codex while its focused footer
  resolved a synthetic two-branch repository. The real branch popover exposed
  `feature/preview` with the AT-SPI description `Copies the branch name`; it did
  not claim that an agent pane could receive checkout text. The shared gate now
  matches the reference shell-session rule: local ownership with no declared
  agent permits staging, while remote/agent panes fail closed. Staged text never
  includes a newline, so a command or TUI remains under user control. PR/CI
  insertion rows are omitted when that gate is shut and every route re-checks
  focused identity at activation; safe open/copy actions remain available.
- Follow-up live AT-SPI used the same isolated two-branch repository: Codex
  exposed `Copies the branch name`; removing only the declared agent exposed
  `Inserts the checkout command at the prompt`. Invoking the latter staged the
  no-newline payload without execution and the app stopped with clean runtime
  output. The existing footer crop remains the relevant visual evidence because
  this correction changes truthful menu semantics, not footer geometry.
- Copy/accessibility: the current branch is noninteractive. PR and CI menus use
  exact `Open in Browser`, `Copy URL`, `Insert Checkout Command`, `Insert Watch
  Command`, and `Insert Failure-Log Command` wording. Branch rows describe
  whether activation inserts at the prompt or copies the branch name.
- Inspection: the 1144×38 X11/GLX footer crop was opened at original
  resolution. The synthetic `repository › repo root` composition, divider,
  spacing, and `main` chip remain aligned without exposing terminal content.
  GTK's transient popover uses a separate surface that this raw window capture
  path does not composite; its live contents and description were checked over
  AT-SPI instead of being misrepresented as screenshot evidence.
- Verification: full preflight passes the text baseline, all 94 tests (including
  every gate rejection and exact footer action wording), the production build,
  real terminal integration, and 100 two-surface lifecycle cycles. The live
  AT-SPI pass confirms the closed-gate branch behavior.
- Privacy: the repository, commit, branches, pane titles, and agent identity are
  synthetic. The strict footer crop contains no terminal content, commands,
  clipboard data, credentials, private paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 fuzzy sidebar search

- Linux image: [ordered multi-range highlight](swift-gtk/progress/33-fuzzy-sidebar-search/ordered-multi-range-highlight-x11.png).
- Reference: project-owned `FuzzyMatch.swift` and
  `SidebarSearchProjection.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: the real `Search sessions` GTK entry was edited through AT-SPI with
  the non-contiguous query `eld`. The isolated profile projected the matching
  workspace and rendered each matched character in `Extremely Long
  Development…` as a separate bold underlined Pango range. The underlying
  scorer also covers stable score ordering, word boundaries, contiguous runs,
  bounded gaps, best alignment, diacritics, and a bounded query length.
- Inspection: the 296×852 sidebar-only X11/GLX PNG was opened at original
  resolution. The query, single filtered result, current-result outline, three
  separated visible highlights, fixed header, and footer remain legible.
- Verification: full preflight passes the text baseline, 92 Swift tests
  (including UTF-8 offsets, later better alignment, stable ties, group-order
  preservation, and hidden-only hits), the production build, real terminal
  integration, and 100 two-surface lifecycle cycles.
- Privacy: every visible group, workspace, agent count, and query is synthetic.
  The strict sidebar crop contains no terminal content, commands, clipboard
  data, credentials, private paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 destructive close sheets

- Linux images: [workspace close risk](swift-gtk/progress/32-destructive-close/close-workspace-risk-sheet-x11.png),
  [clear workspace](swift-gtk/progress/32-destructive-close/clear-workspace-sheet-x11.png),
  and [workspace-group close risk](swift-gtk/progress/32-destructive-close/close-workspace-group-risk-sheet-x11.png).
- Reference: `AwesoMuxApp.confirmCloseIfNeeded`,
  `confirmClearWorkspace`, `confirmCloseGroupIfNeeded`, `QuitRiskPolicy`, and
  `DestructiveCloseCopy` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: the Ghostty shim now exposes foreground PID, close-risk state, and
  whether a semantic prompt marker has been observed. The staged canonical
  runtime installs Ghostty's own shell-integration resources. A pure policy
  combines bounded `/proc` command/child classification with trustworthy
  observed prompt-away state and fresh agent execution. Risky workspace close
  and aggregate group close show
  exact interruption copy; safe close skips the prompt. Clear always confirms
  with risk-sensitive permanent-close copy. One owned modal prevents stacking,
  makes Cancel the safe default, exposes exact keyboard hints, and disables
  competing sheet commands until dismissal. Soft close releases its real
  terminal surfaces and rebuilds fresh ones on reopen.
- Accessibility and interaction: live AT-SPI verified heading/body/hint roles,
  Cancel and destructive button names, and the exact destructive-button hint.
  Cancel preserved both workspaces and restored command enablement. Confirmed
  close persisted one recoverable workspace, removed its runtime, and a real
  reopen rebuilt it before draining recovery. Aggregate close reported exactly
  one risky workspace, removed the group, and left the app alive.
- Inspection: all three 480×230 X11/GLX Latte surfaces were inspected at
  original resolution. Bounded bidi-isolated titles, quiet explanatory copy,
  secondary Cancel, and the high-salience destructive action remain readable
  without exposing the terminal behind the modal.
- Verification: full preflight passes the text baseline, 90 Swift tests,
  production build, terminal integration including foreground PID/close-risk
  transitions, and 100 two-surface lifecycle cycles.
- Remaining evidence: physical Super-Return/Escape delivery remains pending
  because no X11 keyboard-injection utility is installed. The real terminal
  harness now proves observed idle-prompt safety and subsequent prompt-away
  command risk.
- Privacy: the profile, titles, and agent transition are synthetic; the cropped
  modal images contain no terminal content, commands, clipboard data,
  credentials, paths, or arbitrary agent output.

## 2026-08-29 — SwiftGtk4 workspace-group naming sheets

- Linux images: [new workspace group](swift-gtk/progress/31-group-naming/new-workspace-group-sheet-x11.png)
  and [rename workspace group](swift-gtk/progress/31-group-naming/rename-workspace-group-sheet-x11.png).
- Reference: `WorkspaceGroupCreateSheet.swift`, `WorkspaceGroupRenameSheet.swift`,
  and `WorkspaceGroupNameDraft.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: every group create/rename route now presents one transient modal
  sheet owned by the main window. The sheets use exact headings, `Name`,
  `Group name`, `Workspace group name`, `Cancel`, and Create/Save copy. A shared
  bounded draft rejects empty, invisible, duplicate, and mixed-script names,
  displays sanitization adjustments before saving, and keeps invalid forms
  open. Return submits valid input and Escape cancels; repeat group creation is
  disabled until the active sheet closes.
- Accessibility and interaction: live AT-SPI verified heading, label, text-box,
  and button semantics. Duplicate `Local` exposed the exact validation message
  and rejected Click. Valid `Research` was created and persisted, then opened
  from its real group-action popover, renamed to `Product`, and persisted. Both
  sheets closed cleanly, command enablement recovered, and the app stayed alive.
- Inspection: both 420-point X11/GLX Latte surfaces were inspected at original
  resolution. Owned Geist typography, focus treatment, spacing, and
  primary/secondary buttons match the accepted workspace-rename sheet.
- Verification: full preflight passes the text baseline, 88 Swift tests,
  production build, terminal integration, and 100 two-surface lifecycle cycles.
- Privacy: all group names and profile state are synthetic; no terminal
  content, commands, clipboard data, credentials, paths, or arbitrary agent
  output are shown.

## 2026-08-29 — SwiftGtk4 workspace rename sheet

- Linux image: [workspace rename sheet](swift-gtk/progress/30-workspace-rename/workspace-rename-sheet-x11.png).
- Reference: `WorkspaceEditSheet.swift` and exact localized rename copy at
  macOS baseline `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: `Rename Workspace…`, Ctrl-Shift-R, and the named row action now
  present one transient modal sheet owned by the main window. The sheet uses
  the current coarse visible title, exact `Rename '<title>'`, `Name`,
  `Workspace name`, `Cancel`, and `Save` copy. Whitespace-only input disables
  Save with `Enter a workspace name to enable Save`; valid Save updates and
  persists the authoritative workspace, while Cancel leaves it unchanged.
  The command is disabled until the sheet closes so repeated activation cannot
  stack windows.
- Accessibility and interaction: live AT-SPI inspection verified the heading,
  label, text-box, and button roles/names. Empty Save exposed the exact hint and
  rejected its Click action. Valid Save and Cancel were invoked through AT-SPI;
  both closed cleanly, command enablement recovered, persistence was correct,
  and the real app remained alive. Entry activation and Escape share the same
  guarded submit/dismiss paths.
- Inspection: the 420×196 X11/GLX window was inspected at original resolution.
  The final Latte surface uses owned Geist typography, field focus treatment,
  primary/secondary buttons, spacing, and background across the full window;
  an initial native-white GTK pass was rejected and replaced.
- Verification: the reference-copy/draft policy is covered by pure tests. Full
  preflight passes 87 Swift tests, release terminal integration, and 100
  two-surface lifecycle cycles.
- Privacy: the profile and titles are synthetic; no terminal content, commands,
  clipboard data, credentials, paths, or arbitrary agent output are shown.

## 2026-08-29 — SwiftGtk4 background agent outcome

- Linux image: [Codex Error in its origin group](swift-gtk/progress/29-background-agent-outcomes/codex-error-origin-group-x11.png).
- Reference: background Done/Error status-message behavior and sidebar rollup
  priority at macOS baseline `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: a pane-scoped Codex `stop` event reporting `error` updated Review's
  owned provider tile and non-color-only error badge while leaving the workspace
  in Local. Development remained selected and both real terminal panes retained
  focus/layout; no Needs Input section was manufactured. The paired AT-SPI pass
  delivered `Codex in Review reported an error.` at medium priority. A preceding
  Done pass similarly delivered `Codex in Review completed.`
- Inspection: the 1440×852 X11/GLX surface was inspected at original resolution.
  The Codex spiral, red × badge, origin row geometry, Local count, selected
  Development row, neutral one-agent footer, focused path bar, and adjacent Git
  chips remain aligned and readable.
- Verification: full preflight passes 86 Swift tests, release terminal
  integration, and 100 two-surface lifecycle cycles. Transition-only gating
  keeps repeated outcomes and intermediate Running state silent.
- Privacy: the event and profile are synthetic and contain no prompt, terminal,
  command, clipboard, credential, or arbitrary output field.

## 2026-08-29 — SwiftGtk4 unanswered-turn promotion

- Linux image: [Claude waiting in Needs Input](swift-gtk/progress/28-unanswered-turn/claude-waiting-needs-input-x11.png).
- Reference: runtime-only unanswered-turn lifting and exact accessibility
  transition wording at macOS baseline `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: the release app received a pane-scoped protocol-v1 Claude Code
  `notification` that explicitly reported `waiting`, matching the reference
  one-shot idle-prompt shape. Review moved into Needs Input while its pane
  remained Waiting with no manufactured attention reason; its blue information
  badge and neutral `1 agent` footer distinguish this from a blocking prompt.
  The transition announces `Review is still waiting for a reply, moved to Needs
  Input` through GTK without moving terminal focus.
- Inspection: the 1440×852 X11/GLX surface was inspected at original resolution.
  Review appears once above Local, retains its origin description and Claude
  burst, Development remains selected with both real terminal panes intact, and
  the focused-pane footer is unchanged.
- Verification: core tests cover exact phase classification, permission-prompt
  exclusion, Pinned precedence, acknowledgement, prompt/session retraction, and
  omission of both the runtime pane mark and derived lift from persisted JSON.
  A separate live pass observed the exact sentence as a medium-priority AT-SPI
  `Object.Announcement` with no terminal-focus transition; a following synthetic
  `promptSubmit` emitted `Review left Needs Input, returned to Local` through the
  same event channel and priority. A separate blocking-input pass delivered
  `Claude Code in Review needs input.` and the same return copy, confirming the
  two promotion sources remain distinct through AT-SPI.
  Full preflight passes 86 Swift tests, the release terminal integration, and
  100 two-surface lifecycle cycles.
- Privacy: the event and profile are synthetic and contain no prompt, terminal,
  command, clipboard, credential, or arbitrary output field.

## 2026-08-29 — SwiftGtk4 owned provider vector glyphs

- Linux images: [Latte provider matrix](swift-gtk/progress/27-provider-vector-glyphs/provider-vectors-light-x11.png),
  [Mocha provider matrix](swift-gtk/progress/27-provider-vector-glyphs/provider-vectors-dark-x11.png),
  and [HighContrast provider matrix](swift-gtk/progress/27-provider-vector-glyphs/provider-vectors-high-contrast-x11.png).
- Reference: `DesignSystem/Atoms/AgentTile.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior and geometry: one scalable GTK drawing component now renders the
  reference Claude eight-ray burst, Codex organic open spiral, OpenCode open
  bracket pair, Grok three-ring knot, and shell prompt at expanded/peek/rail
  sizes. Pi remains a semibold mono glyph. Provider hue stays on the mark over
  one uniform elevated tile, and the existing non-color-only state badges
  remain layered above it.
- Inspection: all three 1440×852 real X11/GLX application captures were opened
  at original resolution. The six identities remain visibly distinct in
  Latte, Mocha, and HighContrast; a first light pass exposed the shell mark's
  inherited pale color, and the final light capture verifies its corrected
  dark foreground. Long rows, selected/attention tiles, status badges, footer
  counts, and both real Ghostty panes remain aligned.
- Accessibility: the glyph drawing/text child is explicitly hidden from
  AT-SPI; the tile parent continues to expose one provider-plus-state label,
  avoiding duplicate decorative announcements.
- Verification: full preflight passes 83 Swift tests, release terminal
  integration, and 100 two-surface lifecycle cycles.
- Privacy: provider workspaces and states are synthetic. No commands, history,
  clipboard content, credentials, or arbitrary agent output is shown.

## 2026-08-29 — SwiftGtk4 live pane-scoped agent event

- Linux image: [live Grok Needs Input transition](swift-gtk/progress/26-live-agent-events/live-grok-needs-input-x11.png).
- Reference: pane-scoped agent-event delivery, provider identity, Needs Input
  promotion, and footer roster behavior at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: the release app created four owner-only pane event endpoints and
  passed each endpoint, stable pane ID, and runtime session ID into its real
  Ghostty child environment. Appending one bounded protocol-v1 Grok
  `userInputRequired` event for the synthetic Pinned Review pane changed only
  that pane from idle Pi to Grok Needs Attention, moved its workspace into the
  Needs Input projection, refreshed the non-color-only status badge, changed
  the footer to `3 agents` / two Needs Input, and persisted the new state.
- Inspection: the 1440×852 X11/GLX application surface was captured after the
  background reader and GTK-main publication completed, then inspected at
  original resolution. XWayland exposes the GTK toplevel as an ARGB surface;
  the capture preserves its pixels and composites transparent desktop pixels
  over the owned dark application backdrop so text and controls remain
  inspectable without capturing unrelated desktop content.
- Verification: full preflight passes 83 Swift tests, release terminal
  integration including exact child-environment delivery, and 100 two-surface
  lifecycle cycles. The persisted fixture independently confirms the target
  pane's Grok/Needs Attention identity.
- Privacy: event and session fixtures are synthetic. The protocol contains no
  prompt, terminal, command, clipboard, credential, or arbitrary output field.

## 2026-08-29 — SwiftGtk4 empty workspace and absent focused context

- Linux image: [zero groups / no focused pane context](swift-gtk/progress/25-empty-neutral-footer/zero-groups-no-focused-context-x11.png).
- Reference: empty-sidebar recovery, empty workspace, zero-agent footer, and
  neutral/absent focused-footer behavior at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: a separate valid schema-v2 profile contains zero groups and no
  selected workspace. The real app shows fixed search/create chrome, the
  centered `WELCOME TO AWESOMUX` recovery action, and the truthful `0 agents`
  footer. With no focused pane, path/Git/PR/CI/remote chips and the adjacent
  focused footer are absent rather than rendered as disabled placeholders.
- Inspection: the 1440×852 X11/GLX PNG was inspected at original resolution.
  The 296 px sidebar and titlebar boundary remain stable; the empty surface is
  centered and no terminal or fabricated context is shown.
- Privacy: the profile contains no workspaces, paths, panes, or terminal data.

## 2026-08-29 — SwiftGtk4 high-contrast interactions

- Linux images: [high-contrast Quick settings](swift-gtk/progress/24-high-contrast-interactions/quick-settings-x11.png)
  and [high-contrast group menu](swift-gtk/progress/24-high-contrast-interactions/group-menu-x11.png).
- Reference: high-contrast focus/border/foreground behavior, Quick Settings,
  and group actions at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: the release app ran with GTK HighContrast on X11/GLX. AT-SPI opened
  both native popovers, preserving the same truthful choices, selected Dark /
  Standard / Blue states, and first-group Move Up boundary.
- Inspection: both dedicated surfaces were inspected at original resolution.
  High-contrast popover borders are thicker and brighter; labels, selected
  fills, radio/check marks, and the notification control remain distinct. The
  broader provider/state grayscale matrix and focus-ring traversal remain open.
- Privacy: both captures contain product-owned static wording only.

## 2026-08-29 — SwiftGtk4 sidebar footer menus

- Linux images: [Quick settings](swift-gtk/progress/23-sidebar-footer-menus/quick-settings-x11.png)
  and [Help & Feedback](swift-gtk/progress/23-sidebar-footer-menus/help-feedback-x11.png).
- Reference: `SidebarStatusFooter.swift`, Quick Settings wording, and feedback
  menu routes at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: AT-SPI activated both real expanded-footer menu buttons. Quick
  settings exposes persisted System/Light/Dark, Standard/Compact, and Mute
  notifications controls. Help & Feedback exposes only `Report a bug…` and
  `Suggest a feature…`, both routed to the verified issue intake; placeholder
  informational surfaces remain absent.
- Correction and inspection: the first pass exposed a low-contrast native mute
  label. Owned Mocha/Latte colors, a visible focus outline, and a 24 px minimum
  row were added. Both final popover PNGs were inspected at original resolution;
  choices, selection fills, labels, padding, and pointer geometry are clear.
- Accessibility: direct AT-SPI inspection reports every visible theme, density,
  notification, and feedback control by name and as sensitive.
- Verification: full preflight passes 74 Swift tests, release terminal
  integration, and 100 two-surface lifecycle cycles.
- Privacy: both surfaces contain product-owned static wording only.

## 2026-08-29 — SwiftGtk4 group action menu

- Linux image: [first-group action menu](swift-gtk/progress/22-group-menu/first-group-actions-x11.png).
- Reference: `SidebarGroupView.swift`, `SidebarGroupHeaderView.swift`, and the
  shared group color/action wording at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: AT-SPI activated the real options control for the first expanded
  group. The native GTK popover exposes exact creation, rename, color, move,
  and close routes; the current Blue tint is marked, Move Group Up is disabled
  at the first boundary, and Move Group Down remains sensitive. No unavailable
  SSH action is shown.
- Inspection: the dedicated 276×838 popover surface was inspected at original
  resolution. Labels, selection marker, color order, padding, dividers, and
  dynamic boundary state are visible without terminal content in the capture.
- Accessibility: direct AT-SPI inspection verifies the named options toggle and
  each visible action; `Move Group Up` reports insensitive while the adjacent
  movement and other truthful actions report sensitive.
- Privacy: the menu contains product-owned static wording only.

## 2026-08-29 — SwiftGtk4 accessible large text

- Linux image: [1.5× accessible text](swift-gtk/progress/21-large-text/large-text-150-x11.png).
- Reference: typography, truncation, minimum-target, sidebar/footer, and focused
  path-bar contracts at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: the owned GTK stylesheet now derives a defensive 1–2× text factor
  from GTK's Xft DPI setting, with the standard `GDK_DPI_SCALE` override as the
  X11 fallback. Only declared font sizes scale; natural GTK allocation expands
  controls while reference minimum hit targets and spacing remain intact.
- Inspection: the release-equivalent real app ran at 1.5× on X11/GLX and the
  1440×852 PNG was inspected at original resolution. Titlebar, search, lifted
  rows, group headers, group creation controls, sidebar footer, pane title,
  terminal footer, and path chip grow without overlap. Long labels truncate,
  both real Ghostty panes remain visible, and the 296 px sidebar stays fixed.
- Verification: pure tests cover DPI resolution, invalid/undersized inputs,
  the 2× cap, and CSS font-size rewriting. Full preflight passes 74 Swift tests,
  release terminal integration, and 100 two-surface lifecycle cycles.
- Privacy: the profile and terminal prompts are synthetic; no command history,
  clipboard content, credentials, or arbitrary agent output is shown.

## 2026-08-29 — SwiftGtk4 right-to-left layout

- Linux image: [Arabic-locale RTL layout](swift-gtk/progress/20-rtl-layout/rtl-arabic-locale-x11.png).
- Reference: sidebar, titlebar, split-create, row/group, footer, and focused
  path-bar alignment contracts at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Display and behavior: the release app ran under `ar_EG.utf8` on X11/GLX at
  1440×852. GTK mirrored the sidebar to the right, reversed the split-create
  segments, aligned row/group content and options for RTL, mirrored both footer
  surfaces, and preserved the two-pane Ghostty order and divider.
- Inspection: the PNG was inspected at original resolution. Long title/group
  truncation, selected/attention states, fixed chrome, and pane/footer borders
  remain intact. Runtime translation remains a separate localization phase;
  this milestone verifies direction-sensitive layout only.
- Privacy: the fixture and terminal prompt are synthetic; no command history,
  clipboard content, credentials, or arbitrary agent output is shown.

## 2026-08-29 — SwiftGtk4 hidden-sidebar edge reveal

- Linux images: [hidden attention edge](swift-gtk/progress/19-hidden-sidebar-reveal/hidden-attention-edge-x11.png),
  [pointer-hover reveal](swift-gtk/progress/19-hidden-sidebar-reveal/edge-hover-revealed-x11.png),
  [retracted after pointer leave](swift-gtk/progress/19-hidden-sidebar-reveal/retracted-after-leave-x11.png),
  [right-side hidden attention edge](swift-gtk/progress/19-hidden-sidebar-reveal/right-hidden-attention-edge-x11.png),
  and [right-edge pointer reveal](swift-gtk/progress/19-hidden-sidebar-reveal/right-edge-hover-revealed-x11.png).
- Reference: `SidebarPresentationCommand.swift`, `SidebarView.swift`, and
  hidden-discovery behavior at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Display and geometry: release SwiftGtk4 app on X11/GLX at 1440×852. The
  hidden image retains the full terminal allocation and exposes the pink
  attention edge tab. Hovering that tab reveals the 296 px sidebar as an
  overlay; moving back into the terminal retracts it after the leave grace
  without changing the terminal footer width. The mirrored right-side fixture
  places and reveals the attention tab and sidebar from the opposite edge.
- Inspection: all PNGs were inspected at original resolution with real Ghostty
  rendering. The reveal preserves selection, fixed footer alignment, and the
  selected pane's focused-footer state. Direct AT-SPI inspection reports the
  visible edge control as a focusable `Show Sidebar` button with description
  `A workspace needs input` and a `click` action.
- Privacy: all workspace, location, and prompt content is synthetic; no command
  history, clipboard content, credentials, or arbitrary agent output is shown.

## 2026-08-29 — SwiftGtk4 sidebar interaction states

- Linux images: [alternate workspace selected](swift-gtk/progress/18-sidebar-interaction-states/alternate-workspace-selected-x11.png),
  [unselected Needs Input row hover](swift-gtk/progress/18-sidebar-interaction-states/row-hover-x11.png),
  and [expanded group hover](swift-gtk/progress/18-sidebar-interaction-states/group-hover-x11.png).
- Reference: `SidebarSessionTile.swift`, `SidebarGroupHeaderView.swift`, and
  `SidebarView.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Display and geometry: release SwiftGtk4 app on the verified X11/GLX path;
  1440×852 content with the 296 px expanded sidebar.
- Behavior: the exported second-workspace action selected the Pinned workspace
  and moved terminal ownership to it. Pointer hover on the unselected Needs
  Input row reveals its sibling close control without shifting row content;
  group hover replaces the count with the close affordance in place.
- Inspection: all three PNGs were inspected at original resolution. Selection,
  hover fill, tint/attention marks, close affordances, fixed footer alignment,
  and real Ghostty rendering remain visually distinct. Physical DnD insertion
  and full Orca spoken navigation remain open interaction checks.
- Privacy: the profile, workspace names, locations, and terminal prompt are
  synthetic; no command history, clipboard content, credentials, or arbitrary
  agent output is shown.

## 2026-08-29 — SwiftGtk4 sidebar keyboard-focus handoff

- Linux images: [expanded search focus](swift-gtk/progress/17-sidebar-keyboard-focus/expanded-search-focus-x11.png),
  [expanded first-row focus](swift-gtk/progress/17-sidebar-keyboard-focus/expanded-row-focus-x11.png),
  and [collapsed selected-row focus](swift-gtk/progress/17-sidebar-keyboard-focus/collapsed-row-focus-x11.png).
- Reference: `KeyboardShortcutCatalog.focusSidebar`,
  `SidebarFocusRequest.swift`, `SidebarPresentationCommand.swift`, and
  `SidebarView.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior: the exported native `Focus Sidebar` action maps the reference
  Command-Control-S chord to Linux Control-Super-S. Expanded mode moves focus
  from the active terminal to `Search sessions`; collapsed mode focuses the
  selected rail row (or its stable fallback). A hidden sidebar is persistently
  shown before the focus handoff. From an empty expanded search field, Down
  hands focus directly to the first logical sidebar row.
- Verification: the action was invoked through `org.gtk.Actions` in the real
  app. The expanded images show the search field and the first Needs Input row
  with their keyboard-only blue focus outlines; AT-SPI reported the row as the
  focused list item. The collapsed image shows the selected Needs Input rail
  row's distinct focus outline. A hide/focus round trip changed the synthetic
  fixture from hidden `true` to `false`. Both images contain two live Ghostty
  panes and were inspected at original resolution. Full preflight passes 72
  Swift tests, release terminal integration, and 100 two-surface lifecycle
  cycles.
- Accessibility note: direct AT-SPI inspection confirms focus on the search
  entry and expanded workspace list item; full Orca spoken inspection remains.
- Privacy: the profile and terminal prompts are synthetic. No terminal history,
  typed commands, clipboard data, credentials, arbitrary agent output, or
  private path is present.

## 2026-08-29 — SwiftGtk4 sidebar search states

- Linux images: [active title highlight](swift-gtk/progress/16-sidebar-search/active-highlight-x11.png)
  and [no-matches panel](swift-gtk/progress/16-sidebar-search/no-matches-x11.png).
- Reference: `SidebarSearchProjection.swift`, `SidebarView.swift`, and the
  search/no-results localization catalog at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content size: 1440 × 852 on the verified X11/GLX path with two live,
  independently rendered Ghostty panes.
- Search behavior: the real GTK entry was edited through its named AT-SPI
  `EditableText` interface. `review` projected only the Pinned match and
  rendered its visible title range bold/underlined; `no such workspace`
  rendered the exact query-bearing no-matches copy and working `Clear search`
  action without mutating group disclosure.
- Accessibility verification: AT-SPI exposed the entry as `Search sessions`
  with `Text` and `EditableText`, and the no-results action as `Clear search`
  with one named `Click` action. Invoking that action through AT-SPI returned
  `true` and the entry's accessible text became empty.
- Verification: both PNGs were opened and inspected at original resolution.
  Search filtering, highlighting, no-results presentation, and accessible clear
  routing were exercised in the real app; model coverage remains part of the
  passing 70-test/full-preflight baseline.
- Privacy: every group, workspace, provider, query, prompt, and path in the
  fixture is synthetic. No terminal history, typed command, clipboard data,
  credential, arbitrary agent output, or private path is shown.

## 2026-08-28 — SwiftGtk4 focused-footer long text

- Linux image: [long repository path, branch, and dirty state](swift-gtk/progress/15-focused-footer-long-text/long-path-branch-dirty-x11.png).
- Reference: `TerminalPathBarView.swift`, `TerminalPathBarChips.swift`, and
  `TerminalPathBarModel.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content size: 1440 × 852 on the verified X11/GLX path, with two
  independently rendered real Ghostty panes and a synthetic local Git working
  copy carrying a deliberately long repository name, nested directory, long
  branch, and one uncommitted entry.
- Corrected behavior: the project and path retain their existing end/middle
  truncation priorities; the branch label now follows the reference 240 px
  maximum with middle truncation while keeping its short ahead/behind hint
  whole. GTK status menu buttons are shrinkable, and long branch-list entries
  are bounded so no status surface can push or clip adjacent footer controls.
- PR parity: draft and review chips now render the reference suffixes
  (`PR #N · draft` and `PR #N · review`) while preserving the full accessible
  state description.
- Verification: the PNG was opened and inspected at original resolution. Both
  terminals, the path control, middle-truncated branch chip, and dirty chip are
  visible without overlap or clipping. Full local preflight passes 70 Swift
  tests, the release terminal integration, and 100 two-surface lifecycle cycles.
- Privacy: the repository, branch, directory, and dirty marker are generated
  synthetic fixture data. No terminal history, typed command, clipboard data,
  credential, arbitrary agent output, or private path is shown.

## 2026-08-28 — SwiftGtk4 Needs Input transition

- Linux images: [selected workspace in Needs Input](swift-gtk/progress/14-needs-input-transition/selected-needs-input-x11.png)
  and [acknowledged workspace returned to its origin group](swift-gtk/progress/14-needs-input-transition/returned-to-origin-x11.png).
- Reference: `SidebarAttentionProjection.swift`,
  `SelectionAcknowledgementCoordinator.swift`, and the Needs Input transition
  handling in `SidebarView.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Behavior exercised: the exported real `Acknowledge Workspace` application
  action acknowledged the selected pane, removed the workspace from the
  synthetic section, restored the same row inside its unchanged origin group,
  and kept both real Ghostty surfaces alive. The persisted synthetic fixture
  changed from one ordered attention workspace and zero acknowledged panes to
  zero attention workspaces and one acknowledged pane.
- Model correction: Needs Input membership and arrival order now come from one
  authoritative reconciled list. A selected row remains sticky after the
  passive 500 ms read dwell until navigation away, while permission and
  explicit-input prompts refuse passive acknowledgement. The sticky is
  runtime-only and is not restored from JSON.
- Verification: both 1440 × 852 images were opened and inspected at original
  resolution on the verified X11/GLX path. Seventy Swift tests cover arrival
  order, repeat signals, sticky dwell/demotion, blocking prompts, projection
  membership, and persistence boundaries. Full local preflight, release
  terminal integration, and 100 two-surface lifecycle cycles pass.
- Remaining interaction evidence: remote synthetic focus could not reliably
  move focus between the two real terminal surfaces, so the passive dwell's
  physical timing and its spoken return announcement remain keyboard/Orca QA
  items rather than being inferred from this explicit-action capture.
- Privacy: the profile contains only synthetic workspace, pane, provider, and
  state data. No terminal history, typed commands, clipboard data, credentials,
  arbitrary agent output, or private path is shown.

## 2026-08-28 — SwiftGtk4 agent activity routing

- Linux images: [expanded grouped activity panel](swift-gtk/progress/13-agent-activity-routing/expanded-activity-panel-x11.png),
  [collapsed state footer](swift-gtk/progress/13-agent-activity-routing/collapsed-state-footer-x11.png),
  and [collapsed Thinking control focus/routing](swift-gtk/progress/13-agent-activity-routing/collapsed-thinking-focus-x11.png).
- Reference: `SidebarStatusFooter.swift`, `AgentActivityPanel.swift`, and
  `AgentActivityRoster.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Expanded behavior: one pane-grained roster drives footer counts and panel
  rows. Groups appear in urgency order; rows preserve sidebar traversal order
  and show provider, live pane/session title, sanitized location, and selected
  identity. State chips open a targeted panel; row selection closes it and
  routes to the exact workspace/pane.
- Collapsed behavior: the 60-point rail now contains Quick Settings, Help &
  Feedback, and separate nonzero Thinking, Output, and Needs Attention
  controls. Each 32-point state control wraps only through matching agent panes
  rather than cycling the entire roster. The focused-control image shows the
  keyboard focus treatment and matching second-pane focus handoff.
- Accessibility: controls expose names, descriptions, selected and expanded
  state; panel open/close is announced; the close route restores a predictable
  focus target. Native GTK hit targets were exercised through the isolated X11
  QA display. Human pointer and Orca narration remain separate final checks.
- Verification: all three images contain two live Ghostty surfaces and were
  inspected at original resolution. Full preflight passes 66 Swift tests,
  release terminal integration, and 100 two-surface lifecycle cycles.
- Privacy: the profile contains intentionally synthetic workspace, pane,
  provider, state, and prompt data only. No terminal history, typed commands,
  clipboard data, credentials, arbitrary agent output, or private path appears.

## 2026-08-28 — SwiftGtk4 sidebar layout matrix

- Linux images: [Latte left sidebar with long text](swift-gtk/progress/12-sidebar-layout-matrix/light-left-long-text-x11.png),
  [Mocha right sidebar with long text](swift-gtk/progress/12-sidebar-layout-matrix/dark-right-long-text-x11.png),
  [high-contrast long-text state](swift-gtk/progress/12-sidebar-layout-matrix/high-contrast-long-text-x11.png),
  [hidden attention edge tab](swift-gtk/progress/12-sidebar-layout-matrix/hidden-attention-edge-x11.png),
  and [Mocha at 2× scale](swift-gtk/progress/12-sidebar-layout-matrix/dark-scale-2x-x11.png).
- Reference: sidebar host, titlebar, group, row, hidden-discovery, and
  appearance contracts at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Layout verification: the 296-point brand/sidebar column mirrors correctly,
  long workspace and group names truncate without displacing adjacent chrome,
  and the window title remains centered over the pane region on either side.
- Theme verification: the owned Latte, Mocha, and high-contrast styles preserve
  distinct selected, attention, pinned, divider, text, and focus treatments in
  the same synthetic session fixture.
- Hidden discovery: the hidden-sidebar image shows the attention edge tab
  without resizing either terminal. The persistent hidden state and tab click
  route are implemented. Physical reveal and timed retraction were subsequently
  verified in the milestone-19 X11 captures above.
- Scale verification: the 2× capture is 1706 × 852 physical pixels; its
  296-logical-point sidebar occupies 592 physical pixels, both real Ghostty
  panes remain visible, and the restored split fraction is computed from the
  live logical `GtkPaned` allocation rather than a fixed window estimate.
- Verification: every image was opened and inspected at original resolution.
  The final local preflight passes 64 Swift tests, release terminal integration
  (Unicode, focus, resize, clipboard, title/cwd, and pane independence), and
  100 two-surface lifecycle cycles.
- Privacy: the fixtures contain synthetic group, workspace, agent, and prompt
  content only; no terminal history, typed commands, clipboard data,
  credentials, arbitrary agent output, or private path is shown.

## 2026-08-28 — SwiftGtk4 multi-pane workspace peek

- Linux image: [Pinned multi-pane workspace peek](swift-gtk/progress/11-multi-pane-peek/pinned-multi-pane-peek-x11.png).
- Reference: `SidebarSessionPeekCard.swift`, `PanePeekItem.swift`, and
  `SidebarSessionTile.swift` at macOS baseline
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content size: 1440 × 852 on the verified X11/GLX path under
  XWayland, with two real independently rendered Ghostty panes.
- Implemented behavior: expanded multi-pane rows reveal a 240-point card after
  the reference 180 ms delay. It carries workspace rollup state, focused cwd,
  pane-tree numbering, pane-local state, active identity, and click-to-focus
  routing. The same host follows a workspace into Needs Input or Pinned rather
  than remaining attached to its hidden ownership row; the image exercises the
  Pinned case. Row-to-card handoff retains the reference 220 ms grace.
- Keyboard/screen-reader path: the row context surface exposes the same pane
  order as explicit `Jump to pane N` actions, including provider, state,
  remote identity, and active-pane wording. The transient pointer card itself
  does not take keyboard focus. A later release-process probe found and fixed
  stale pane-command enablement after workspace switches; `Focus Pane 2` now
  disables on one pane, enables on two, follows one/two-pane selection changes,
  and routes to the second pane's exact tree-order identity. A fresh release
  app then used the app-owned collapsed/expanded focus-recovery path to expose
  the card to AT-SPI; pane 1's explicit Click action returned true and the
  owner-only snapshot persisted the exact first pane identity.
- Capture note: GTK maps the popover as a separate native X11 surface. The app
  client and popup were captured from the same live state and composited at
  their recorded root-window coordinates; no UI pixels were otherwise edited.
- Verification: the inspected image shows the 296-point sidebar, lifted row,
  real split terminals, and continuous footer without a GL-context error. The
  current full preflight passes 113 Swift tests, the dynamic command-enablement
  release probe, release integration (including OSC title/cwd callbacks), and
  100 two-surface lifecycle cycles.
- Remaining interaction evidence: physical pointer card invocation and audible
  Orca output inspection. Hover/focus close controls, jump-number overlays, and
  native pointer drag insertion are implemented; held-key/drag evidence still
  needs an input-capable display.

## 2026-08-28 — SwiftGtk4 live sidebar chrome and rail

- Linux images: [expanded populated sidebar](swift-gtk/progress/10-sidebar-live-chrome/expanded-populated-x11.png)
  and [collapsed 60-point rail](swift-gtk/progress/10-sidebar-live-chrome/collapsed-rail-x11.png).
- Reference: awesoMux macOS at
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content size: 1440 × 852 on the verified X11/GLX path under
  XWayland. Both images contain two real, independently rendered Ghostty panes;
  neither contains a GL-context error, fake terminal, or blank integration
  surface.
- Expanded state: the sidebar is settled at the 296-point reference default
  with fixed search/create chrome, Needs Input and Pinned projections, group
  ownership, selected workspace, agent footer, and the continuous 38-point
  focused-pane footer.
- Collapsed state: the same live window is settled at 60 points with 40-point
  search/create/workspace controls, distinct attention and pinned glyphs, the
  group tint marker, and the compact agent footer. Terminal layout and focus
  survive the mode transition.
- Live-data verification: the language-neutral Ghostty bridge now forwards OSC
  title and cwd changes through generation-guarded pane identity. The full
  preflight passed 58 Swift tests, a release integration that emits OSC 2 and
  OSC 7, and 100 two-surface lifecycle cycles before capture.
- Privacy: the fixture shows only the intentional local development-style
  prompt and repository basename. It contains no terminal history, entered
  commands, clipboard contents, credentials, or arbitrary agent output.
- Visible remaining differences: GTK/portable glyph outlines differ from SF
  Symbols; workspace tiles still need provider-specific glyphs/status shapes,
  hover/focus close controls, and jump-number overlays. Multi-pane peek cards
  are covered by the next milestone above.
  Pointer drag insertion and accessibility announcements are now implemented,
  but physical drag/Orca proof, roster-popover capture,
  light/high-contrast/scale/right-side states, and the remaining
  completion-contract screenshots are still pending.

## 2026-08-28 — SwiftGtk4 macOS footer visual correction

- Linux image: [focused footer](swift-gtk/progress/09-footer-macos-parity/focused-footer-x11.png).
- Reference: Sarah's supplied focused-pane footer crop and awesoMux macOS at
  `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content size: 1440 × 860 on X11/GLX under XWayland.
- Corrected treatment: controls retain intrinsic height inside the 38-point
  footer; the path control is 24 points with 6-point internal spacing; status
  chips use the reference 10/11-point hierarchy, 5-point radii, restrained
  fills, and tone-matched hairlines. Branch and PR content have separate icon,
  primary-label, and secondary-state roles.
- Corrected semantics: repository roots use the exact `repo root` wording,
  nested working directories use repo-relative paths, and Git/PR/CI chips are
  explicitly cleared when their resolved state disappears.
- Later interaction correction: ordinary primary clicks still open the path
  action menu. Linux Control-click maps the reference Command-click gesture to
  reveal that same current, identity-checked local repo root or working
  directory in Files; remote panes fail closed. This changes behavior but not
  pixels, so the inspected footer image remains the applicable visual record.
- Interaction verification: a fresh release app launched from `/tmp`; AT-SPI
  found the one actionable current path control by its exact modifier hint,
  accepted an ordinary click, and then exposed both `Show in Files` and
  `Copy Path`. The full local preflight passes all 114 Swift tests, both builds,
  the single-window and dynamic-command probes, both forced-termination cases,
  terminal integration, and 100 two-surface lifecycle cycles.
- Verification: the image was captured from the real GTK application after
  background repository resolution and opened at original resolution for
  inspection. The focused repository supplied real branch, ahead, and dirty
  state; the test suite covers root/nested/fallback path presentation.
- Platform-specific remainder: Apple system mono and SF Symbols are not
  redistributable on Linux, so the implementation uses Noto Sans Mono with
  DejaVu/generic fallbacks and portable glyphs while retaining the measured
  macOS sizes, weights, spacing, and color roles.

## 2026-08-28 — SwiftGtk4 footer feature parity

- Linux images: [focused Git footer](swift-gtk/progress/08-footer-parity/focused-git-footer-x11.png)
  and [agent-state footer](swift-gtk/progress/08-footer-parity/agent-status-footer-x11.png).
- Reference: awesoMux macOS at `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content size: 1440 × 852 on X11/GLX under XWayland.
- Implemented terminal behavior: focused local panes expose the path/editor/
  Files/copy menu, branch and recent-branch actions, dirty and upstream counts,
  open PR actions, and failing/running CI actions. Resolution is bounded,
  concurrent, prompt-free, HTTPS-validated, and stale-identity guarded.
- Implemented sidebar behavior: Quick Settings, Help & Feedback, live
  thinking/output/attention counts, total agents, and an expandable activity
  list. The second image uses a profile-scoped two-agent fixture to exercise
  thinking and needs-attention states without altering the default profile.
- Verification: the full local preflight passed 32 Swift tests, the release
  terminal integration harness, and 100 two-surface lifecycle cycles. Both
  images were opened and visually inspected after the real app resolved its
  background footer context through the GTK main loop.
- Privacy: no terminal history, command output, credentials, clipboard data,
  or arbitrary agent output is shown. The local repository-style path and
  branch metadata are intentionally visible.
- Visible differences: GTK icon/font metrics and Files/editor discovery follow
  Linux conventions. Foreground-shell detection, full settings panes,
  notification delivery, and live agent-runtime event ingestion remain later
  milestones; footer actions never auto-submit inserted terminal commands.

## 2026-08-28 — SwiftGtk4 sidebar and focused-pane footer chrome

- Linux images: [populated selected workspace](swift-gtk/progress/07-sidebar-footer/populated-selected-x11.png)
  and [alternate/new workspace selection](swift-gtk/progress/07-sidebar-footer/alternate-selection-x11.png).
- Reference: awesoMux macOS at `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content size: 1440 × 852 on X11/GLX under XWayland.
- Implemented behavior: the 188-point sidebar has a fixed search/create header,
  dense live group rows, disclosure, selection/hover treatment, metadata, a
  pinned truthful `0 agents` footer, and real workspace creation. Each
  workspace page has a 38-point focused-pane path bar whose sanitized cwd
  follows terminal focus and sidebar selection.
- Verification: native `org.gtk.Actions` switched workspaces and created the
  inspected third workspace; the full local preflight passed 23 Swift tests,
  release terminal integration, and 100 two-surface lifecycle cycles.
- Privacy: the QA shell profile contains no history, command output,
  credentials, or clipboard data. Normal local development-style path chrome
  is intentionally visible.
- Visible differences: GTK-native icon/font metrics differ slightly; pinned
  workspaces, row actions/agent badges, settings/help buttons, Git/branch/PR
  enrichment, and explicit arrow/Home/End list navigation remain future work.
- Next correction: review density and typography with Sarah, then add only the
  next approved truthful sidebar/path-bar behavior; `amx` remains deferred.

## 2026-08-28 — SwiftGtk4 New Workspace command

- Linux image: [new-workspace-command-x11.png](swift-gtk/progress/06-workspace-commands/new-workspace-command-x11.png)
- Reference: awesoMux macOS at `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content size: 1440 × 852.
- Implemented behavior: the exported native GTK `New Workspace` action created
  and selected an `Untitled Workspace`, inserted its sidebar row, launched a
  distinct Ghostty surface, focused it, and atomically persisted the expanded
  grouped snapshot.
- Verification: the action was invoked through the application's exported
  `org.gtk.Actions` interface, and the resulting session file remained `0600`.
- Privacy: the terminal uses the visual-QA-only shell profile; no command,
  repository path, history, clipboard content, or credential is visible.
- Visible differences: rename/close controls, workspace metadata, group
  actions, status bar, and command-palette presentation remain future work.
- Runtime note: the inspectable capture uses X11/GLX under XWayland while the
  recorded COSMIC/NVIDIA native Wayland OpenGL constraint remains open.

## 2026-08-28 — SwiftGtk4 workspace sidebar

- Linux image: [workspace-switcher-x11.png](swift-gtk/progress/05-workspace-sidebar/workspace-switcher-x11.png)
- Reference: awesoMux macOS at `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
- Captured content size: 1440 × 852.
- Implemented behavior: sidebar rows now represent workspaces rather than
  individual panes. The selected Development workspace owns the visible
  two-pane terminal split; Review owns a separate terminal page in the same
  native GTK4 window.
- Visual treatment: the sidebar uses the reference Catppuccin Mocha palette,
  selected-row accent rail, group label, and workspace hierarchy. GTK retains
  native controls and focus behavior.
- Privacy: all terminal prompts use the visual-QA-only shell profile; no
  commands, repository paths, history, clipboard data, or credentials appear.
- Visible differences: group actions, workspace status metadata, close
  affordances, bottom status bar, and command palette remain future milestones.
- Historical runtime note: this 2026-08-28 capture used X11/GLX because the
  native context path failed at that milestone. The GTK 4.14 desktop-GL
  initialization correction and native evidence above resolved that constraint
  on 2026-08-29.

## 2026-08-28 — SwiftGtk4 terminal integration

- Linux image: [real-terminal-split-x11.png](swift-gtk/progress/04-terminal-lifecycle/real-terminal-split-x11.png)
- Reference: awesoMux macOS at `fed33ff47c559344fc6db6fa53f16e75fcc4a116`.
  The pinned repository contains no committed equivalent screenshot, so a
  pixel comparison is not yet possible on Linux.
- Captured content size: 1440 × 852.
- Tested display systems: native Wayland launch on COSMIC and X11/GLX capture
  on Xwayland. The native Wayland screenshot portal required an unattended
  consent interaction, so the inspectable artifact uses the GLX capture path.
- Implemented behavior: the pinned Ghostty library renders two concurrent,
  independently owned terminal surfaces inside one native GTK4 window.
- Privacy: both prompts use a visual-QA-only shell profile; no command,
  repository path, terminal history, or clipboard content is present.
- Visible differences: this is an unstyled terminal-integration slice. The
  sidebar is not visible in the GLX child-window capture, and the reference
  chrome, workspace treatment, focus styling, and bottom bar are not yet
  implemented.
- Next correction: complete focus routing, lifecycle stress coverage,
  accessibility metadata, and a native Wayland full-window capture when the
  portal consent prompt can be accepted.
