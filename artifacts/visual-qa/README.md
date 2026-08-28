# Visual QA

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
