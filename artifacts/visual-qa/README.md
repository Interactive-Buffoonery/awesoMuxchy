# Visual QA

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
  route are implemented; physical edge-hover reveal remains a QA gap because
  synthetic X11 pointer motion does not reach this remote application.
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
  does not take keyboard focus.
- Capture note: GTK maps the popover as a separate native X11 surface. The app
  client and popup were captured from the same live state and composited at
  their recorded root-window coordinates; no UI pixels were otherwise edited.
- Verification: the inspected image shows the 296-point sidebar, lifted row,
  real split terminals, and continuous footer without a GL-context error. Full
  preflight passed 59 Swift tests, release integration (including OSC title/cwd
  callbacks), and 100 two-surface lifecycle cycles.
- Remaining row work: exact owned provider vector glyphs and full
  physical-pointer/Orca action inspection. Hover/focus close controls,
  jump-number overlays, and native pointer drag insertion are implemented;
  the latter two still need trustworthy physical held-key/drag evidence.

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
- Runtime note: this inspectable capture uses X11/GLX under XWayland because
  the current COSMIC/NVIDIA native Wayland path cannot create Ghostty's
  required desktop OpenGL context.

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
