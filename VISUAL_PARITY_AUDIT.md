# awesoMux Linux visual-parity audit

Audit completed: 2026-08-29 11:22:46 EDT (-0400; America/New_York)

## 1. Executive assessment

The SwiftGtk4 application has a credible awesoMux shell and is substantially
closer than a generic GTK terminal: the one-window model, 296-point sidebar,
60-point rail, lifted Pinned/Needs Input sections, real Ghostty splits,
focused-pane footer, command palette, modal confirmations, Mocha/Latte/HC
tokens, and left/right/hidden layouts are all recognizable and backed by real
application images.

It is **not yet visually or interactionally at parity with macOS**. The best
current Linux frames are approximately at an advanced vertical-slice stage,
not a completed product-shell pass. The most noticeable day-to-day divergence
is inside the primary content region: GTK's stock wide `GtkPaned` handle is a
bright, heavy stripe; the macOS pane-focus/divider system is a stateful thin
stroke whose thickness, color, and top-edge relationship communicate focus,
hover, keyboard focus, attention, and drag. Linux therefore makes a two-pane
workspace look like a different terminal shell even though splitting works.

The next tier of divergence is completeness. Linux has small quick/help
popovers and several owned sheets, but lacks the complete settings,
keyboard-cheatsheet, terminal-search, unavailable/disconnected, quit/close,
and several recovery/error surfaces that make the macOS shell feel coherent.
Finally, many “verified” or “complete” status claims demonstrate model tests,
AT-SPI metadata, or a Linux-only screenshot rather than equivalent-state,
equivalent-size macOS/Linux visual comparison. Those are valuable engineering
results but insufficient evidence for visual parity.

No P0 defect was found. This audit records 3 P1, 8 P2, and 5 P3 findings.

## 2. Scope and exclusions

In scope: the everyday application shell, sidebar and rail, workspace/group
states, pane splits and focus, terminal padding/clipping, focused-pane and
sidebar footers, menus/popovers/sheets/dialogs/palette, empty/recovery states,
keyboard-visible state, appearance, motion, scaling, RTL, and visible
accessibility state.

Explicitly excluded from prioritization: SSH workspaces, remote persistence,
file handoff, Markdown/document panes, packaging/updates, and broad external
integrations. Their missing UI is not counted as a shell-parity finding below.
Session Manager is mentioned only because it is an existing macOS shell
surface, not as a request to implement the deferred persistence domain.

This was an audit only. During the audit pass, no implementation, status-file,
reference-repository, submodule, commit, push, issue, or remote change was
made. The completed report was subsequently committed and uploaded with the
user's explicit authorization.

## 3. Audit environment and revisions

| Item | Audited value |
| --- | --- |
| Linux repository | `/home/sarah/Development/awesomux-linux-gtk` |
| Linux commit | `046c6fb549c7221c516651cfbcb3dc9859147a69` |
| Active app | `swift-gtk/` (SwiftGtk4/GTK 4.14.x) |
| macOS reference | `/home/sarah/Development/awesomux-macos-reference` |
| macOS commit | `fed33ff47c559344fc6db6fa53f16e75fcc4a116` |
| Ghostty gitlink | `f2d5758f6305867dc36b36293c6165d8152b853e` |
| zmx/amx gitlink | `67c6f63c9f27e96733015f3099363a92d73e836e` |
| Primary runtime | Native Wayland on COSMIC/NVIDIA; release integration and 100-cycle lifecycle stress |
| Image evidence | Existing real-app Wayland and X11/GLX PNGs under `artifacts/visual-qa/swift-gtk/progress/`, inspected at original resolution |

The native Wayland audit run passed input, Unicode, focus, rapid reflow resize,
clipboard, environment, title/cwd callbacks, observed-prompt close-risk
signals, pane independence, and 100 two-surface lifecycle cycles. This harness
does not exercise every shell control and is not represented as doing so.

## 4. Coverage matrix

Legend: **R** = run in this audit; **I** = inspected in a current real-app
artifact; **C** = covered by current source/model/AT-SPI evidence only;
**N** = no adequate current evidence.

| Area/state | Evidence | Result/limitation |
| --- | --- | --- |
| Empty application | I/C | Latte 1440×852 missing-profile frame and AT-SPI action evidence; no paired macOS frame |
| One workspace/one pane | I | Multiple real-app frames; no precise equivalent macOS image |
| Two panes, vertical split | R/I | Native Wayland two-pane rendering passed; divider/focus mismatch found |
| Two panes, horizontal split | C | Action/model evidence; no final-state equivalent screenshot located |
| Multiple workspaces/groups | I | Standard/Compact, attention, pinned, reordered and long-name fixtures |
| Narrow/wide resize | R/C | Rapid native resize passed; narrow shell visual matrix incomplete |
| Left/right sidebar | I | Both positions represented; right-side RTL frame also inspected |
| Expanded/collapsed/hidden | I/C | Final artifacts exist; physical hover reveal documented on X11, not rerun here |
| Selected/focused/hover | I | Separate row and focus artifacts exist |
| Pressed/disabled | C/N | CSS/model state exists; no comprehensive press-frame matrix |
| Pinned/running/waiting/done/error/attention | I/C | Provider/state matrices and live-event frames; running/pressed transitions incompletely captured |
| Long names/truncation | I | Long group/workspace/footer artifacts inspected |
| Group disclosure/actions/reordering | I/C | Menu and focus-recovery images; physical DnD still unverified |
| Pane peek/roster | I/C | Composited popup inspected; physical pointer invocation and audible Orca pending |
| Search empty/populated/highlight/no-results | I/C | Real GTK images and AT-SPI editing evidence |
| Footer path/Git/PR/CI | I/C | Real Git footer and overflow fixtures; PR/CI unavailable matrix incomplete |
| Divider hover/drag/focus | C/N | Model and pointer-release code only; no sufficient physical visual matrix |
| Command palette | I/C | Latte palette inspected; macOS-equivalent pixel comparison absent |
| Workspace/group menus | I | Normal and HC popovers represented |
| Quick settings/help | I | Small popovers represented; full settings absent |
| Rename/destructive sheets | I/C | Workspace/group/close/clear/recovery sheets represented |
| Activity panel | I/C | Expanded and collapsed-focus frames represented |
| Focus restoration | C/I | AT-SPI/model evidence and selected focus-ring frames; held-key/Orca gaps remain |
| Mocha/Latte/high contrast | I | Representative frames present |
| Compact/standard density | I | Paired 296×852 frames inspected |
| Reduced motion | C | Timing policy/tests and transition frames; system-level reduced-motion run not evidenced |
| 100/125/150/200% scale | R/C/I | Native harness matrix is claimed; 100% and X11 2× visual frames; fractional visual inspection incomplete |
| RTL | I | Arabic-locale geometry frame; untranslated copy means bidi/localization parity remains open |
| Accessibility-visible state | C/I | Focus rings and extensive AT-SPI evidence; full keyboard/Orca narration not run |

## 5. Prioritized findings

### Application shell

#### P1 — The primary-window chrome does not form one dark, integrated shell

- **Surface/state:** Mocha, populated window, native Wayland.
- **macOS expected:** the titlebar is part of the same awesoMux-owned chrome;
  title, sidebar lockup, traffic-light reservation, and content edge form one
  continuous dark hierarchy.
- **Linux observed:** the native Wayland frame has a bright white outer window
  header containing a second dark 38-point app titlebar. The resulting stacked
  header is visually dominant and reads as GTK window chrome surrounding an
  embedded app rather than one awesoMux window.
- **Why it matters:** this is visible on every launch and changes the silhouette
  and vertical rhythm of the whole product.
- **macOS source:** `Sources/awesoMux/Views/ContentView.swift:643-783`,
  `AppTitlebarMetrics.swift`, `WindowChromeConfigurator.swift`.
- **Linux source:** `swift-gtk/Sources/AwesoMuxApp/main.swift:3884-3905` and
  `ChromeStyles.swift:42-44`.
- **Evidence:** `progress/48-native-wayland/native-wayland-two-pane.png`.
- **Correction direction:** use GTK-native client-side decoration/headerbar
  ownership (or suppress the redundant server header where the compositor
  permits) while retaining standard Linux window controls and accessibility.
  The awesoMux titlebar must remain the single visible header surface.
- **Dependencies:** settle decoration ownership before final titlebar spacing,
  shadow, and narrow-window measurements.

#### P2 — Equivalent-state macOS visual baselines are missing

- **Surface/state:** all major shell states.
- **macOS expected:** same logical window size, theme, sidebar position,
  workspace fixture, pane layout, and transient state captured from the pinned
  reference.
- **Linux observed:** the visual-QA index usually names Swift source files as
  “Reference” but explicitly notes that no equivalent screenshot exists for
  important states. Linux frames are therefore checked for internal quality,
  not parity.
- **Why it matters:** spacing, color, type, shadows, and timing cannot be
  rigorously called matched without like-for-like evidence.
- **macOS source:** pinned app at `fed33ff…`; screenshot ownership originates in
  `ContentView.swift` and each named surface.
- **Linux source:** `artifacts/visual-qa/README.md` and all progress PNGs.
- **Correction direction:** create a sanitized canonical fixture manifest and
  paired macOS/Linux captures at identical logical dimensions for the minimum
  shell matrix. Record pixel dimensions, scale, theme, and interaction phase.
- **Dependencies:** precedes status upgrades from partial to verified.

### Sidebar

#### P2 — Pressed, drag, and reorder feedback is not physically verified

- **Surface/state:** workspace/group pressed states and within/across-group DnD.
- **macOS expected:** pointer-down feedback and insertion markers follow the
  dragged stable identity; invalid/no-op targets remain visually distinct.
- **Linux observed:** CSS and midpoint-drop logic exist, but current status
  repeatedly says physical DnD/held-pointer delivery is pending. Static hover
  and post-action frames do not prove pressed or continuous drag behavior.
- **Why it matters:** reordering is a frequent direct-manipulation interaction;
  incorrect feedback feels broken even if the final model mutation is right.
- **macOS source:** `SidebarDropDelegates.swift`,
  `SidebarInsertionIndicators.swift`, `SidebarDragItems.swift`.
- **Linux source:** `main.swift:1484-1626`; `ChromeStyles.swift:101,108`.
- **Evidence:** progress 18/39 frames; status admits the physical gap.
- **Correction direction:** run on an input-capable Wayland session; capture
  pointer-down, valid before/after/into, invalid/no-op, and post-drop frames for
  both row and group moves. Keep GTK DnD, but style its live drop states from
  the awesoMux tokens.
- **Dependencies:** complete before claiming workspace/group ordering verified.

#### P2 — Collapsed-rail discovery is visually under-evidenced

- **Surface/state:** collapsed rail with attention, group roster, hover peek,
  held-number overlay, and keyboard focus.
- **macOS expected:** the 60-point rail is a complete alternate hierarchy with
  discoverable attention and delayed peek/number states.
- **Linux observed:** settled rail and focus images exist, but roster popover,
  held Control digits, and physical hover-card invocation remain pending; one
  historical status warning notes unreliable composited damage.
- **Why it matters:** the rail is not merely a narrow sidebar; its transient
  states are the only way to identify otherwise icon-only workspaces.
- **macOS source:** `ContentView.swift:1023-1213`, `SidebarView.swift:799-853`,
  `JumpNumberDisplay.swift`, `CommandKeyHeldEnvironment.swift`.
- **Linux source:** `main.swift:1988-2033,3982-4007`.
- **Correction direction:** capture the full rail interaction sequence on
  native Wayland with real pointer/key input and verify dismissal/focus return.
- **Dependencies:** follows reliable native full-window capture/input.

#### P3 — Sidebar text density is close but lacks a measured type baseline

- **Surface/state:** group headings, metadata, counts, long names.
- **macOS expected:** Geist for proportional hierarchy and the reference mono
  face only for compact metadata, with measured baselines and truncation.
- **Linux observed:** Geist is registered, but extensive 9–10 px mono styling
  and portable glyphs make group/footer information visibly finer and more
  mechanical in the inspected frames. No paired glyph/baseline measurement
  demonstrates equivalence.
- **Why it matters:** the sidebar occupies a third of typical narrow windows;
  small cumulative type differences dominate perceived density.
- **macOS source:** `Sources/DesignSystem/Tokens/AwFont.swift`,
  `SidebarSessionTile.swift`, `SidebarGroupHeaderView.swift`.
- **Linux source:** `ChromeStyles.swift:42-68,81-89`.
- **Correction direction:** measure cap height, baseline, line height, and
  ellipsis positions against paired reference crops before changing sizes.
- **Dependencies:** canonical paired captures first.

### Terminal and splits

#### P1 — Pane divider and focus chrome are fundamentally different

- **Surface/state:** two-pane vertical/horizontal splits; focused/unfocused,
  hover, drag, keyboard focus, attention, HC.
- **macOS expected:** a 1-point/rest divider expands to 3 points on hover;
  focus may be absorbed into the adjacent divider, while active/attention
  states use 4/6-point non-color-distinguishable treatment and a coordinated
  terminal top edge. Animation is 150 ms unless reduced motion is enabled.
- **Linux observed:** the app creates stock `GtkPaned` with `wideHandle=true`.
  The native Wayland frame shows a bright, approximately 4-point white stripe
  at rest and no visible focused-pane top accent. No app-owned stateful divider
  CSS/controller maps pane focus or attention into the handle.
- **Why it matters:** the divider is the central visual landmark of every split
  workspace and currently makes Linux look like a different terminal product.
- **macOS source:** `TerminalSplitLayoutView.swift:26-94,213-405` and
  `TerminalPaneFocusChrome.swift`.
- **Linux source:** `main.swift:914-1005` (notably `wideHandle=true` at 927 and
  949); no corresponding divider style in `ChromeStyles.swift`.
- **Evidence:** `progress/48-native-wayland/native-wayland-two-pane.png` and
  `progress/36-pane-commands/split-right-pane-count-x11.png`.
- **Correction direction:** keep `GtkPaned` for resize semantics but make its
  separator an awesoMux-owned visual layer with a larger transparent hit target.
  Publish focused pane, hover, keyboard focus, attention, axis, HC, and reduced
  motion as CSS/state classes; draw the measured 1/3/4/6-point outcomes.
- **Dependencies:** first remediation milestone; must precede padding and focus
  polish because those measurements share the pane boundary.

#### P2 — Horizontal-split and nested-focus visual coverage is incomplete

- **Surface/state:** split down, nested splits, focus traversal, close-neighbor
  selection.
- **macOS expected:** divider/top-edge rules remain correct through nested
  horizontal and vertical compositions; only the nearest relevant divider
  absorbs focus.
- **Linux observed:** commands and tree mutation are tested, but the current
  final visual set does not prove horizontal or nested divider geometry,
  clipping, focus movement, or drag styling.
- **Why it matters:** a vertical-only screenshot can conceal incorrect nested
  allocation and duplicate focus borders.
- **macOS source:** `TerminalSplitLayoutView.swift:46-149`.
- **Linux source:** `main.swift:914-1005,3712-3815`.
- **Correction direction:** add one canonical four-state split fixture:
  vertical focus A/B, horizontal focus A/B, nested nearest-divider focus, and
  post-close focus restoration at narrow and wide sizes.
- **Dependencies:** app-owned divider/focus component.

#### P2 — Terminal padding and clipping are not compared against an exact reference

- **Surface/state:** single pane, two panes, scale changes, narrow resize.
- **macOS expected:** Ghostty content inset, cursor edge, scrollbar/search
  overlays, title strip, and footer remain optically consistent at all scales.
- **Linux observed:** content is sharp and unclipped, but current screenshots
  show prompt text nearly touching pane edges and do not establish equal
  logical terminal padding. The terminal font default is still “not started”
  in the parity matrix.
- **Why it matters:** terminal inset and font are visible continuously and
  strongly affect whether the port feels identical.
- **macOS source:** `TerminalPaneView.swift`, `TerminalPanelChromeView.swift`,
  Ghostty configuration resources.
- **Linux source:** `main.swift:914-923`; Ghostty shim/config path; terminal-font
  parity row in `FEATURE_PARITY_MATRIX.md`.
- **Correction direction:** capture a sanitized grid/cursor fixture at all four
  scales and measure first/last-cell inset and footer boundary; then align the
  Linux Ghostty configuration without adding wrapper padding that breaks IME
  or pointer coordinates.
- **Dependencies:** terminal font decision and divider milestone.

### Footer

#### P2 — Footer parity is strongest visually but incomplete at overflow/unavailable boundaries

- **Surface/state:** narrow window, long path/branch, no editor, missing Git/gh,
  remote/unavailable context, multiple CI/PR states.
- **macOS expected:** compact intrinsic chips shrink/truncate in priority order,
  unavailable actions disappear or explain themselves without shifting the
  38-point bar.
- **Linux observed:** normal Git and long-text frames are good, but current
  evidence does not cover the full unavailable/overflow matrix at genuinely
  narrow content widths. Remote paths are mostly fail-closed model evidence.
- **Why it matters:** the footer is bound to the focused pane and layout shifts
  are highly visible during workspace/focus changes.
- **macOS source:** `TerminalPathBarView.swift:465-859`,
  `TerminalPathBarChips.swift`, `TerminalPathBarMenus.swift`.
- **Linux source:** `FooterViews.swift:91-259`; `ChromeStyles.swift:68-76`.
- **Correction direction:** test one deterministic matrix at 480/720/1144
  content widths with root/nested path, long branch, dirty/ahead/behind, PR,
  CI, no editors, no Git, and remote; capture before/after focus switches.
- **Dependencies:** none beyond sanitized fixtures.

#### P3 — Portable footer symbols visibly diverge from the reference

- **Surface/state:** Git/PR/CI/path chips and sidebar footer.
- **macOS expected:** SF Symbols with consistent optical boxes and baseline.
- **Linux observed:** Unicode/portable glyphs and Noto/DejaVu fallbacks have
  visibly different outlines and alignment. This difference is documented but
  no owned-symbol normalization exists for all footer icons.
- **Why it matters:** small but repeated baseline irregularities make otherwise
  close footer geometry look less deliberate.
- **macOS source:** `TerminalPathBarChips.swift`, `SidebarStatusFooter.swift`.
- **Linux source:** `FooterViews.swift`; `PLATFORM_DIFFERENCES.md` footer glyph row.
- **Correction direction:** preserve Linux-native meaning but use a small owned
  SVG/Cairo icon set with fixed optical boxes where redistribution permits;
  retain text alternatives.
- **Dependencies:** after interaction/overflow correctness.

### Transient UI

#### P1 — The complete settings and supporting-shell surface family is missing

- **Surface/state:** Quick Settings → full settings; keyboard cheatsheet;
  terminal search; unavailable/disconnected; quit/window-close confirmation.
- **macOS expected:** Quick Settings leads into a full settings shell with
  General, Appearance, Terminal, Workspaces, Agents, Notifications, Keys,
  Advanced, and Diagnostics panes; keyboard cheatsheet and terminal search are
  first-class owned surfaces; unavailable/recovery/quit states have coherent
  presentation.
- **Linux observed:** Quick Settings exposes only System/Light/Dark,
  Standard/Compact, and mute notifications. The parity matrix marks full
  settings, keyboard cheatsheet, quit/window close, and several supporting
  surfaces not started; no Linux implementation locations exist for the full
  macOS view family.
- **Why it matters:** users encounter these from everyday help/settings and
  keyboard workflows; the Linux shell stops abruptly at small popovers.
- **macOS source:** `Views/Settings/AwesoMuxSettingsView.swift`,
  `Views/Settings/Panes/*`, `KeyboardCheatsheetView.swift`,
  `GhosttySurface/SurfaceSearchOverlay.swift`, `TerminalUnavailableView.swift`,
  `RemotePaneDisconnectedView.swift`, app quit/close coordinators.
- **Linux source:** `FooterViews.swift:448-521,701-740`; absent corresponding
  full-surface implementations.
- **Correction direction:** build GTK-native owned windows/sheets that reuse
  the command catalog and tokens; do not inflate Quick Settings into a generic
  GTK preferences dialog. Start with Appearance/Keys/Terminal search because
  they directly support this visual-parity contract.
- **Dependencies:** command availability and preferences models; deferred
  product domains can remain absent from pane lists until implemented.

#### P2 — GTK sheets are functionally owned but visually flatter than macOS modals

- **Surface/state:** rename, close/clear, recovery.
- **macOS expected:** AwModal supplies a consistent dimmed/window-owned layer,
  container radius, shadow, focus/accept treatment, and safe-default hierarchy.
- **Linux observed:** inspected sheet crops show a flat rectangular surface
  filling the capture, with limited evidence of the parent dimming, container
  edge, shadow, or spatial relationship to the main window. Button order is
  correct for Linux conventions, but the modal family does not yet read as the
  same visual object.
- **Why it matters:** destructive and recovery moments are high-attention
  states where hierarchy must be unmistakable.
- **macOS source:** `Sources/DesignSystem/Modal/AwModal*.swift`,
  `WorkspaceEditSheet.swift:24-63`.
- **Linux source:** `main.swift:2497-2597,3116,3415-3460`;
  `ChromeStyles.swift:78,92,106`.
- **Evidence:** progress 30–32, 36, and 37 sheet PNGs.
- **Correction direction:** compare whole-window frames (not sheet-only crops),
  then reproduce the visible hierarchy with a GTK modal/transient plus owned
  content card, dimming where appropriate, and platform-correct button order.
- **Dependencies:** canonical paired modal captures.

#### P2 — Command palette uses a GtkPopover workaround with incomplete focus proof

- **Surface/state:** open, typed query, actions-only, no results, dismiss/restore.
- **macOS expected:** a centered 520×420 owned palette with reliable first
  responder, key-window focus treatment, selection, scrolling, and restoration.
- **Linux observed:** visual card is close, but it is parented as a popover and
  focuses the entry through a 10 ms timeout. Current evidence admits GTK 4.14
  reports no focused AT-SPI object for the popup on the automated display.
- **Why it matters:** the palette is predominantly keyboard-driven; visible
  focus without truthful accessible focus ownership is behavioral drift.
- **macOS source:** `CommandPaletteView.swift:55-101,140-166,226-393`,
  `CommandPaletteController.swift`.
- **Linux source:** `CommandPaletteView.swift:74-105`.
- **Correction direction:** retain an in-window GTK surface but establish focus
  synchronously from map/present lifecycle, expose active descendant/selection,
  and verify real Tab/Up/Down/Return/Escape plus focus return on Wayland/Orca.
- **Dependencies:** input-capable Wayland and Orca pass.

#### P3 — Quick Settings has visible popover-arrow and spacing drift

- **Surface/state:** Mocha/HC quick settings.
- **macOS expected:** the reference quick sheet is a 420-point owned sheet with
  section separators, 18-point padding, 12-point section rhythm, and a Done
  affordance.
- **Linux observed:** the inspected GTK popover is roughly 220 px wide, uses a
  large triangular arrow, and contains only three compact sections with no
  Done action. It reads as a conventional GTK menu rather than the macOS quick
  sheet.
- **Why it matters:** this is one of two permanent footer entry points.
- **macOS source:** `Settings/QuickSettingsSheet.swift:11-69`,
  `AwSettings.swift`.
- **Linux source:** `FooterViews.swift:701-740`; generic popover style in
  `ChromeStyles.swift:77-80`.
- **Correction direction:** use a GTK-native transient sheet/popover but match
  the reference content width/rhythm and dismissal semantics; platform arrow
  mechanics may differ only if they do not change the visible hierarchy.
- **Dependencies:** full settings routing decision.

### Appearance, scaling, and accessibility

#### P2 — Fractional-scale visual parity remains unproven

- **Surface/state:** 125% and 150% Wayland.
- **macOS expected:** sharp text, aligned one-logical-pixel dividers, accurate
  pointer coordinates, and unclipped chrome.
- **Linux observed:** integration passes at compositor scales, but existing
  status explicitly leaves fractional blur and pointer-alignment visual
  inspection pending. The only clear scale visuals are 100%, X11 2×, and a
  separate 1.5× text-scaling frame, which is not equivalent to compositor 150%.
- **Why it matters:** fractional scaling is common on Linux laptops and most
  likely to expose the current divider and GL alignment defects.
- **macOS source:** all token/layout sources; logical-point rendering contract.
- **Linux source:** Ghostty shim scale handling; scaling row in
  `FEATURE_PARITY_MATRIX.md`.
- **Correction direction:** native Wayland portal captures at 125/150 with a
  grid/cursor/divider/focus fixture and pointer hit-test recording.
- **Dependencies:** app-owned divider and native capture consent path.

#### P3 — Reduced-motion support is asserted from policy, not a full real run

- **Surface/state:** lifted sections, hidden-sidebar reveal, palette/result
  movement, hover peek, activity panel.
- **macOS expected:** all nonessential transitions become identity under the
  system reduced-motion preference while hierarchy remains understandable.
- **Linux observed:** `.reduced-motion` state and zero-duration reveal policy
  exist, and mid-transition frames exist in ordinary mode, but no complete
  system-level reduced-motion interaction sequence is recorded.
- **Why it matters:** one missed transient animation violates the preference
  even if primary transitions pass unit tests.
- **macOS source:** `SidebarView.swift:85,199`, `ContentView.swift:474-487`,
  `CommandPaletteView.swift:151`.
- **Linux source:** `main.swift:3066-3072`; revealer/palette controllers.
- **Correction direction:** enable GTK animations off at runtime and record the
  full structural/reveal/palette/dismiss sequence with frame timing.
- **Dependencies:** none.

#### P3 — RTL is geometrically mirrored but not a complete RTL interaction pass

- **Surface/state:** right/left directional controls, pane order, popovers,
  drag indicators, keyboard arrows.
- **macOS expected:** direction-sensitive UI mirrors while logical pane order,
  command routing, focus sequence, and truncation remain truthful.
- **Linux observed:** the Arabic-locale frame proves broad geometry mirroring,
  but copy remains English and no evidence covers drag/popover arrows or
  directional keyboard behavior in RTL.
- **Why it matters:** a single static frame can hide reversed navigation or
  insertion semantics.
- **macOS source:** `ContentView.swift`, sidebar/drop/navigation policies.
- **Linux source:** GTK direction handling plus `main.swift` sidebar/pane routes.
- **Correction direction:** run keyboard and DnD sequence under RTL and capture
  left/right popovers and insertion markers; localization remains a separate
  later phase.
- **Dependencies:** physical input coverage.

#### P2 — Accessibility parity remains incomplete despite strong metadata work

- **Surface/state:** whole-shell keyboard navigation and screen-reader output.
- **macOS expected:** visible focus ownership and VoiceOver-equivalent names,
  state, position, announcements, modal trapping, and focus restoration.
- **Linux observed:** AT-SPI names/descriptions and several announcements are
  unusually well covered, but current status still lists physical Tab/held-key,
  audible Orca, IME, physical DnD, and some popover focus as pending.
- **Why it matters:** focus rings that look correct without actual focus
  ownership are not interaction parity.
- **macOS source:** `SidebarView.swift`, command palette/modal focus code,
  accessibility policies throughout Views.
- **Linux source:** accessibility helpers and focus routes in `main.swift`,
  `CommandPaletteView.swift:74-105`.
- **Correction direction:** perform one scripted-manual keyboard/Orca audit per
  shell mode, recording object role/name/state and visible focus after every
  structural mutation/dismissal.
- **Dependencies:** input-capable native session and Orca.

## 6. Missing surfaces inventory

The following current macOS shell surfaces have no complete Linux counterpart
or no adequate current runtime evidence. Deferred SSH/document/integration
domains are intentionally omitted.

| Surface | macOS authority | Linux state |
| --- | --- | --- |
| Full settings window and pane navigation | `Views/Settings/AwesoMuxSettingsView.swift`, `Views/Settings/Panes/*` | Missing; only Quick Settings subset |
| Keyboard cheatsheet and search | `KeyboardCheatsheetView.swift` | Missing |
| Terminal find/search overlay and result navigation | `GhosttySurface/SurfaceSearchOverlay.swift` | No complete shell UI evidence |
| Quit-risk and empty-window close flows | App delegate/quit coordinator and ADR-0002 | Marked not started |
| Terminal unavailable presentation | `TerminalUnavailableView.swift` | Missing |
| Complete disconnected/reconnect visual state | `RemotePaneDisconnectedView.swift` | Out-of-scope backend, but visible generic unavailable state still missing |
| Complete recovery choice/replacement flow | persistence/recovery views | Only quarantine/Done subset |
| Session Manager | `SessionManagerPanel.swift` | Missing; lower audit priority |
| About/keyboard-help window family | About and cheatsheet views | Missing/incomplete |
| Complete notification/action presentation | notification policy/views | Missing; sidebar attention itself exists |

## 7. Present but behaviorally different

| Surface | Difference |
| --- | --- |
| Pane divider | Stock wide GtkPaned; lacks macOS stateful focus/hover/attention ownership |
| Command palette | GtkPopover plus delayed focus; accessible focus not reliably exposed |
| Quick Settings | Compact autohiding popover instead of the wider owned quick sheet/full-settings gateway |
| Modal sheets | Separate GTK modal windows/crops; parent dimming and exact focus hierarchy not proven |
| Collapsed rail | Core routing exists; held-digit, physical hover/roster, and DnD behavior not fully proven |
| Hidden sidebar | GTK overlay and 220 ms grace preserve outcome; animation character still lacks paired timing comparison |
| Sidebar ordering | Model and actions work; physical drag feedback remains unverified |
| Accessibility | AT-SPI fallback descriptions replace unavailable integer relations; acceptable platform mechanism, incomplete outcome audit |

## 8. Present but visually different

| Surface | Visible difference |
| --- | --- |
| Window header | Bright native outer header plus owned 38-point titlebar in Mocha |
| Split divider | Heavy bright stripe instead of thin muted/stateful divider |
| Pane focus | Missing/coarsely represented top-edge and divider absorption cues |
| Quick Settings | Narrow GTK menu proportions and large arrow |
| Sheets | Flat rectangular crop; modal card/shadow/dimming relationship not demonstrated |
| Footer icons | Portable Unicode/font outlines differ from SF Symbols |
| Sidebar microtype | Fine mono metadata/group rhythm lacks measured paired baseline |
| Fractional scale | Sharpness and one-pixel boundary alignment not visually demonstrated |

## 9. Existing parity claims needing correction

1. **Single-window app shell — `verified`:** behavior is verified, but visual
   shell parity is not. Split into behavioral and visual status or downgrade
   the visual part to partial because of duplicate/native header chrome and no
   paired macOS frame.
2. **Sidebar density — `verified`:** paired Linux Standard/Compact images prove
   the preference works, not that either matches macOS at the same fixture and
   size. Retain behavioral verification; mark visual parity partial.
3. **Bundled UI font — `complete`:** registration/application is complete;
   typography parity is not measured across baselines, weights, fallback
   glyphs, and scaling. Rename the claim to “font packaging/registration
   complete.”
4. **Provider glyphs/status shapes — `complete`:** owned vector implementation
   and Linux matrices are strong, but no paired reference renders or grayscale
   comparison support complete visual parity. Mark implementation complete,
   parity partial.
5. **RTL layout — `complete`:** one static mirrored frame does not verify
   directional keyboard, menus, DnD, or focus order. Downgrade interaction
   parity to partial.
6. **Accessible text scaling — `complete`:** a 1.5× X11 capture verifies owned
   CSS allocation, not the complete settings/transient/keyboard surface family.
   Scope the claim explicitly to implemented chrome.
7. **Scaling — `partial`:** correctly partial; remove language that can be read
   as visual completion at 125/150 until native fractional screenshots and
   pointer alignment are inspected.
8. **Sidebar accessibility — `partial`:** correctly partial; keep audible Orca,
   physical key delivery, and modal/popup focus as explicit blockers.
9. **Workspace ordering — `partial`:** correctly partial; do not promote until
   physical DnD/pressed/insertion feedback is inspected.
10. **Quick Settings/high contrast evidence:** current wording shows contrast
    tests and Linux inspection. It should not imply parity with the macOS quick
    sheet, whose width, content, and dismissal model differ.

## 10. Dependency-ordered remediation roadmap

1. **Create the canonical paired shell fixture and evidence protocol.** Capture
   macOS and Linux at identical logical sizes for empty, single-pane,
   vertical/horizontal split, populated sidebar, rail, hidden/reveal, palette,
   quick settings, modal, light/dark/HC, 125/150/200, and narrow width. This is
   the measurement base for every later correction.
2. **Complete one pane-boundary vertical slice.** Own divider visuals while
   retaining GtkPaned semantics; implement rest/hover/drag/keyboard/focused/
   unfocused/attention/HC/reduced-motion states together with the pane top edge.
   Validate vertical, horizontal, nested, narrow, and scale matrices.
3. **Resolve primary-window decoration ownership.** Remove the double-header
   effect and then tune titlebar lockup, centering, truncation, and left/right
   layout against paired frames.
4. **Complete one sidebar-row component across every state.** Normal, selected,
   focus-only, pointer hover, pressed, close-hover/focus, pinned, running,
   waiting, done, error, attention, disabled, drag source, before/after/into,
   long text, Standard/Compact, Latte/Mocha/HC, rail, RTL, and scale should be
   corrected coherently before isolated group/footer pixel changes.
5. **Complete rail and hidden-sidebar interaction evidence.** Physical hover,
   roster/peek handoff, held-number overlay, attention discovery, 220 ms leave,
   focus restoration, left/right, and reduced motion on native Wayland.
6. **Complete footer boundary matrix.** Narrow/overflow/unavailable/remote and
   focus-switch transitions, then normalize owned icon optical boxes.
7. **Build the core transient surface family.** Establish shared GTK-native
   card/sheet/popover tokens and focus lifecycle, then use them for palette,
   quick settings/full-settings gateway, rename/destructive/recovery, keyboard
   cheatsheet, and terminal search. Backend-heavy deferred panes may remain
   absent rather than placeholder content.
8. **Run the platform matrix.** Native 100/125/150/200 screenshots, system text
   scale, HC, reduced motion, RTL interaction, full keyboard-only traversal,
   IME, physical DnD, and audible Orca.
9. **Correct status claims only after paired inspection.** Separate
   implementation complete, behavior verified, accessibility verified, and
   visual parity verified so model tests cannot stand in for inspected UI.

## Smallest high-impact first milestone

**Ship an app-owned pane-boundary/focus-chrome milestone:** match the macOS
divider and active-pane top-edge system for vertical and horizontal two-pane
workspaces, including rest, hover, drag, keyboard focus, attention, high
contrast, reduced motion, and 100/125/150/200% scaling, with paired macOS/Linux
captures at the same logical size.

This is smaller than a full shell restyle, is exercised constantly, and would
remove the single strongest cue that the Linux build is a different app.
