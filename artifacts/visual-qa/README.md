# Visual QA

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
