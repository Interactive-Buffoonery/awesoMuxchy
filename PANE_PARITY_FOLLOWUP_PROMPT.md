# awesoMux Linux pane-parity continuation prompt

Continue the active SwiftGtk4 visual-parity work in:

`/home/sarah/Development/awesomux-linux-gtk`

The sole application implementation is `swift-gtk/`.

Before changing anything, read completely:

- `AGENTS.md`
- `AGENT_PROMPT.md`
- `swift-gtk/AGENT_PROMPT.md`
- `REFERENCE_BASELINE.md`
- `VISUAL_PARITY_AUDIT.md`
- `FEATURE_PARITY_MATRIX.md`
- `IMPLEMENTATION_STATUS.md`
- `swift-gtk/IMPLEMENTATION_STATUS.md`
- `PLATFORM_DIFFERENCES.md`
- `VISUAL_PARITY_ACHIEVED.md`
- `artifacts/visual-qa/README.md`
- `artifacts/visual-qa/macos-reference/fed33ff/pane-boundary/README.md`

Treat `/home/sarah/Development/awesomux-macos-reference` as strictly
read-only. Read its `AGENTS.md` before inspecting code. Before and after every
reference pass, run:

```sh
git -C /home/sarah/Development/awesomux-macos-reference status --short
```

Stop if it is dirty. Do not inspect GPL, AGPL, unlicensed third-party
implementation source, or unrelated terminal projects. Canonical pinned MIT
Ghostty is the only permissible Ghostty implementation source. Keep
`vendor/ghostty` and `vendor/zmx` clean.

## Current evidence

Pinned macOS revision:
`fed33ff47c559344fc6db6fa53f16e75fcc4a116`.

Canonical macOS pane fixtures are under:

`artifacts/visual-qa/macos-reference/fed33ff/pane-boundary/`

They cover equivalent logical-size dark states for vertical and horizontal
focus A/B, nested focus, pointer hover on both axes, pointer drag before/after,
keyboard resize before/after, a 1440 x 888 wide window, and a 900 x 700 narrow
window. All twelve files were inspected at original resolution.

Current Linux evidence is under:

`artifacts/visual-qa/swift-gtk/progress/49-pane-boundary/`

The Linux implementation already retains GTK-native `GtkPaned` allocation and
resize semantics while providing app-owned separators, pane focus edges,
inactive-pane scrims, attention/error states, high contrast, reduced motion,
accessible separator roles, and scale fixtures. The latest full preflight
passed 130 tests, debug/release builds, native Wayland integration, and 100
two-surface lifecycle cycles.

Do not assume this means parity. The paired inspection currently identifies:

1. Linux focused-pane rails are visibly brighter/bluer than the pinned macOS
   muted accent treatment.
2. Linux terminal panes lack the pinned reference's pane-header layer and its
   coordinated relationship to the focused top edge and dividers.
3. Linux physical pointer hover, pointer drag, and keyboard divider
   focus/resize still need real release-app proof.
4. Paired light, high-contrast, reduced-motion, scaling, RTL, keyboard, IME,
   and audible Orca coverage remains incomplete.

## Objective

Bring the complete app-owned pane-divider and focused-pane chrome system to
the same visible and interaction quality as the pinned macOS app while
retaining GTK-native resize semantics. Work in dependency order and cover
vertical, horizontal, and nested splits across:

- rest
- focused and unfocused panes
- pointer hover
- pointer drag
- keyboard focus and keyboard resize
- attention and error
- high contrast
- reduced motion
- narrow and wide windows
- 100%, 125%, 150%, and 200% scaling
- RTL and keyboard/accessibility-visible behavior where relevant

Match the macOS user-visible result with a GTK-native implementation. Do not
copy AppKit mechanics literally.

First measure the retained reference fixtures and the corresponding Linux
fixtures at original resolution. Trace each visible difference to the pinned
macOS source and current Linux implementation. Then implement the smallest
coherent correction, including the pane-header layer if the reference source
confirms that it is part of the everyday terminal-pane chrome. Preserve native
divider hit targets, dragging, keyboard resizing, terminal allocation, reflow,
focus routing, and accessibility semantics.

Do not weaken `VISUAL_PARITY_AUDIT.md` findings because implementation exists.
Keep implementation-complete, behavior-verified, accessibility-verified, and
visual-parity-verified claims distinct. Do not add pane boundaries to
`VISUAL_PARITY_ACHIEVED.md` until every gate in that file and the audit is
actually satisfied and no unresolved P1/P2 defect remains.

## Required visual-QA loop

For every correction:

1. Run the real release Linux app natively on Wayland with an isolated profile
   and sanitized QA terminals.
2. Recreate the exact macOS state at the same logical window size.
3. Exercise the real interaction rather than synthesizing only model state.
4. Capture the Linux state and inspect every new image at original resolution.
5. Compare against the retained macOS fixture and record measurements and
   remaining differences in `artifacts/visual-qa/README.md`.
6. Update the audit, parity matrix, implementation-status files, platform
   differences, and `VISUAL_PARITY_ACHIEVED.md` only as warranted by evidence.

Do not log terminal contents, commands, clipboard data, credentials, private
paths, or arbitrary agent output. Do not install packages or use `sudo`
without approval for the exact package list. Do not add CI or hosted
automation. Do not commit or push implementation work without separate
approval. Focused visual-QA screenshot/index commits and pushes remain allowed
only under the repository's existing rules.

Before handoff, run proportionate focused tests, `./script/preflight.sh` for a
completed milestone, and `git diff --check`; inspect every newly captured image
at original resolution; confirm the macOS reference and both pinned submodules
are clean; and report the Linux worktree state. Keep the app runnable after
each milestone. Continue into the next audit roadmap item only after the pane
boundary milestone genuinely passes or a real external blocker requires
Sarah's decision.
