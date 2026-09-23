# 0005 — awesoMuxchy as an Omarchy edition of the shared app

- Status: Accepted product direction; implementation pending
- Date: 2026-09-23
- Decider: Sarah

## Decision

Build awesoMuxchy as an Omarchy edition of the shared Linux awesoMux
application. Keep Swift/GTK4, the awesoMux-owned Ghostty shim, workspace and
pane models, persistence, command routing, and provider logic shared. Use a
small edition configuration for Omarchy-specific appearance, shortcuts,
window behavior, desktop integration, and packaging. SwiftGtk4 is the sole
application implementation.

Omarchy is the baseline Linux platform and required acceptance target. If the
app does not run well on Omarchy, it does not pass. Verify terminal behavior,
keyboard and focus, splits, persistence, accessibility, visuals, packaging, and
daily use in a real Omarchy/Hyprland session. Builds, smoke checks, and runs on
other desktops cannot substitute for that acceptance evidence.

The macOS reference remains read-only and supplies shared product behavior.
Omarchy-specific presentation and integration can differ under this decision;
record implemented differences and their verification rather than claiming
macOS visual parity for them.

Sarah renamed the repository to
[`Interactive-Buffoonery/awesoMuxchy`](https://github.com/Interactive-Buffoonery/awesoMuxchy)
and made it public. GitHub reports `main` as its default branch. Existing local
checkouts may retain the `awesomux-linux-gtk` directory name. The current
executable, application ID, and profile names are unchanged; installation and
profile ownership remain implementation decisions, not an implicit migration.

Sarah is setting up repository code-review tools separately. Those tools are
authorized; the local preflight remains the verification authority. This does
not authorize additional agent-created CI, package installation, implementation
commits, or pushes. Existing focused visual-QA publication authorization remains
subject to inspecting evidence for private information before public upload.

## Sequence and evidence

The [Linear project](https://linear.app/interactive-buffoonery/project/awesomuxchy-190ce1959bdf)
tracks the review findings and edition work: shared runtime safety and `amx`,
Omarchy integration, real provider workflows, then packaging and daily use.

The 2026-09-23 review found shared runtime, clipboard, recovery, accessibility,
and keyboard defects. Earlier lifecycle and recovery completion statements
must be read with these open findings; retaining pane IDs alone does not prove
running-process survival. The existing 130-test binary passed, current core
warnings-as-errors typechecking passed, and local text-baseline validation
passed with live reference comparison unavailable. No new full build,
preflight, Hyprland interaction, Orca, or installed-package run was performed.

Existing generic Linux desktop evidence remains tied to its recorded
i5GamingPC runs. That historical evidence does not establish Omarchy acceptance;
record missing Omarchy/Hyprland validation as pending. Neither the rename nor this decision
changes any feature's implementation or verification status.
