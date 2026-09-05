# Current macOS titlebar/sidebar reference

Captured 2026-09-05 from the real release app at
`2fd33a099368bddb7774ceb957f4ae371726c146`, the verified remote `main` at the
start of this pass. Built in a separate cache checkout on Purple iMac;
window-only captures taken on MiniMighty. The regular macOS checkouts were
not changed. The QA bundle has its own development profile and ad-hoc signature.

| State | Image | Logical window | PNG | Scale |
| --- | --- | --- | --- | --- |
| Dark, expanded sidebar, right pane focused | [macos-dark.png](macos-dark.png) | 1440×888 | 2880×1776 | Retina 2× |
| Light, expanded sidebar, right pane focused | [macos-light.png](macos-light.png) | 1440×888 | 2880×1776 | Retina 2× |

The fixture contains Development (mauve: Primary terminal, Review) and
Projects (teal: Documentation). Primary terminal owns two equally sized,
side-by-side terminal panes; the right pane is focused. Both selected panes
show `/tmp` as their title/location and `qa$` as their only terminal text.
Dormant workspaces have a home-relative location. Geist is the UI font and
chrome text scale is 100%. The terminal background remains dark in both
appearance modes, as in the current reference's defaults.

The isolated profile disables notification delivery and the command bridge;
no OS notification permission was granted. The fixture restores home-relative
paths, then its synthetic shell changes to `/tmp` and reports that location.
This avoids the current macOS restore validator's intentional rejection of
saved directories outside the home tree. The preliminary recovery/onboarding
frames were discarded; neither final capture has a modal or recovery warning.

Dependency pins: Ghostty `492300cad104195411d12217dd22f1cd05f31376`, zmx
`39ce461e994c4d34fd8bf3434c768d04a8b40d13`. These are macOS reference pins;
Linux's independently verified embedding pins were not changed.

The AX standard window was explicitly resized, and the captured CG window was
filtered by the isolated process identity and main-window geometry. Native
shadows are excluded; screenshots are otherwise unedited. PNG color profiles
and the different native mono/symbol rasterizers must be considered before
interpreting raw RGB differences as design-token drift.

Scope: current dark/light expanded-shell inputs only. These frames do not
verify menus, hover/drag, keyboard focus, accessibility, narrow windows, or the
full feature set introduced since the previous `fed33ff` reference.
