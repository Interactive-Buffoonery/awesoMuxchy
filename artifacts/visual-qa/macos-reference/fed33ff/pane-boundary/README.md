# macOS pane-boundary reference fixtures

- Reference revision: `fed33ff47c559344fc6db6fa53f16e75fcc4a116`
- Ghostty revision: `f2d5758f6305867dc36b36293c6165d8152b853e`
- zmx revision: `67c6f63c9f27e96733015f3099363a92d73e836e`
- Runtime: release awesoMux app, macOS 26.6.1, Apple Silicon, Dark appearance,
  Retina 2x, isolated `qa-fed33-mini-home` profile, sanitized `qa$` terminals.
- Sizes: wide fixtures use a 1440 x 888 logical window; the narrow fixture uses
  a 900 x 700 logical window. Window-only PNGs include the native shadow and
  therefore measure 3104 x 2000 and 2024 x 1624 physical pixels respectively.
- Authoritative source: `Views/TerminalSplitLayoutView.swift` and
  `Views/TerminalPaneFocusChrome.swift` in the pinned reference revision.

## Captured states

- `macos-fed33-dark-wide-vertical-focused-right.png`
- `macos-fed33-dark-wide-vertical-focused-left.png`
- `macos-fed33-dark-wide-horizontal-focused-bottom.png`
- `macos-fed33-dark-wide-horizontal-focused-top.png`
- `macos-fed33-dark-wide-nested-focused.png`
- `macos-fed33-dark-wide-vertical-hover.png`
- `macos-fed33-dark-wide-horizontal-hover.png`
- `macos-fed33-dark-wide-divider-drag-before.png`
- `macos-fed33-dark-wide-divider-drag-after.png`
- `macos-fed33-dark-wide-keyboard-resize-before.png`
- `macos-fed33-dark-wide-keyboard-resize-after.png`
- `macos-fed33-dark-narrow-nested.png`

The real menu actions Split Right, Split Down, Focus Pane 1/2/3, and Close
Pane were exercised. Pointer hover was positioned over each divider axis. A
real pointer drag moved the horizontal divider, and Command-Option-Equals moved
the keyboard-focused divider. The purple keyboard/drag outline persisted after
the resize and is recorded rather than edited away.

Every retained PNG was inspected at original resolution. Attention/error was
not manufactured. Light appearance, increased contrast, reduced motion,
non-Retina scaling, RTL, and audible VoiceOver were not captured. These files
therefore establish canonical equivalent-state inputs; they do not establish
complete pane-boundary parity by themselves.
