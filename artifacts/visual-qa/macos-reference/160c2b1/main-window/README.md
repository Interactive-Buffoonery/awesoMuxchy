# Main-window reference — macOS 160c2b1

Release built at `160c2b17589c688efd88a5a63652f807c45d8ffc` on Purple iMac,
then captured on MiniMighty in the isolated development QA profile. Original
macOS checkouts were unchanged and clean before/after inspection. No system
packages were installed. The QA bundle is ad-hoc signed and notification
channels / terminal command bridge are disabled in this synthetic profile.

| State | Screenshot |
| --- | --- |
| Dark, populated | [dark.png](dark.png) |
| Light, populated | [light.png](light.png) |
| Dark, empty | [empty.png](empty.png) |

1440×888 logical window; 2880×1776 PNG at Retina 2×; expanded sidebar 296 points.
Geist UI font at 100% text scale. Populated fixture: Development (mauve) with
Primary terminal and Review; Projects (teal) with Documentation. Primary terminal
has two equal side-by-side panes with right-pane focus. Synthetic shells display
only `qa$` and report `/tmp`; dormant rows use `~`. The empty fixture has no groups.
Terminal backgrounds stay dark in both appearances, following the reference.
Cursor blink phase may differ; it is not a chrome comparison signal.

AX resized the standard window; capture selected that process's main CG window
and excluded the native shadow. Slow launches were retried until a real standard
window existed. These are unedited final frames without modal/recovery warnings.
The isolated QA app was stopped after capture.

Ghostty gitlink `492300cad104195411d12217dd22f1cd05f31376`; zmx gitlink
`39ce461e994c4d34fd8bf3434c768d04a8b40d13`. The current macOS native scrollback
extension was rebuilt with this release. Linux embedding pins are unchanged.
Main-window design sources are unchanged since the earlier `2fd33a0` pass;
these images nevertheless come from the newly built revision.
