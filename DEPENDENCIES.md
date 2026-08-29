# Dependency policy and pins

All source dependencies are pinned to immutable commits. Runtime discovery must
not silently select a different checkout or system library.

| Dependency | Commit/version | License | Role |
|---|---|---|---|
| Ghostty | `f2d5758f6305867dc36b36293c6165d8152b853e` | MIT | Complete terminal runtime and renderer, consumed through the awesoMux shim |
| zmx | `67c6f63c9f27e96733015f3099363a92d73e836e` | MIT | Optional remote-owned session transport |
| SwiftGtk | `ee963714f3e45c3201bf9cd45ae41cc360699304` (`gtk4`) | BSD-2-Clause | GTK4 Swift bindings |
| gir2swift | `e2b894e3ba0197d7c2ebe1cde62e5c1faa404b75` | BSD-2-Clause | Binding generation plugin |
| SwiftGraphene | `b39a5e33ab00d5c565b618d3b12e83b3900c79c2` | MIT | SwiftGtk transitive binding |
| SwiftAtk | `acaaa7fabfa94242ca896ad4fb957ed4c6dd18e3` | MIT | SwiftGtk transitive binding |
| SwiftGsk | `bd3417c4255167a40e8a0015ab7f81defd940afb` | MIT | SwiftGtk transitive binding |
| SwiftGObject | `a959fc96fe441048c71972a6708ef9fea22ccbb6` | MIT | SwiftGtk transitive binding |
| SwiftGdk | `54474e94af355bf88283d3cc342daa15cc32b67b` (`gtk4`) | MIT | SwiftGtk transitive binding |
| SwiftGLib | `66d258cea8b7c2f870f9c4dea543c4bd7ef04d08` | MIT | SwiftGtk transitive binding |
| SwiftGdkPixbuf | `a0fee7dbaeca5f954b7bc04ae7996ed62c10c8c1` | MIT | SwiftGtk transitive binding |
| SwiftPangoCairo | `0318374a18fc8ac183ad906d83df5b19c9e03f48` | MIT | SwiftGtk transitive binding |
| SwiftGIO | `9a2ee26f08383d489988a837006992323b005bec` | MIT | SwiftGtk transitive binding |
| SwiftGModule | `eecf947483b81361a1ff242b606d581358963a15` | MIT | SwiftGtk transitive binding |
| SwiftCairo | `87cd2aa586853fbeed192a42455fc43e9289b605` | MIT | SwiftGtk transitive binding |
| SwiftPango | `1670dc5109759fe53beaaa1aac2a77e131735500` | MIT | SwiftGtk transitive binding |
| SwiftHarfBuzz | `c699025869c261447c5ed02f6d650a1d21b81d83` | MIT | SwiftGtk transitive binding |
| Fontconfig | system `2.15.0` | MIT-style | Process-local registration of bundled interface fonts |
| Geist Sans | pinned macOS baseline `fed33ff47c559344fc6db6fa53f16e75fcc4a116` | SIL OFL 1.1 | Bundled Regular, Medium, SemiBold, and Bold interface faces |

SwiftGtk itself is an immutable revision requirement. Its manifests use branch
requirements for generated binding packages; SwiftPM rejects adding conflicting
direct revision requirements. Therefore `Package.resolved`, generated with the
approved Swift toolchain and checked for drift by local preflight, is the
machine-readable immutable lock for every transitive branch tip listed above.

Ghostty is staged into a disposable build directory before applying the patches
in `patches/ghostty/`; `vendor/ghostty` must remain clean. The shim is
awesoMux-owned and exposes no GTK or Zig implementation details to Swift. The
second patch exports only Ghostty's existing semantic-prompt-observed bit so
the host can distinguish startup state from trustworthy close-risk evidence.
The third patch installs Ghostty's canonical terminfo and shell-integration
resources beside the embedded library; local launch wrappers pass that staged
resource location explicitly.

No GPL, AGPL, or unlicensed source may be copied into this repository. System
GTK libraries remain dynamically linked under their own distribution terms.
The exact Geist faces and OFL text live under
`swift-gtk/Sources/AwesoMuxApp/Resources`; Fontconfig registers them only for
the awesoMux process and does not modify the user's font installation.

The approved `libgtk-4-dev` package is installed on i5GamingPC. SwiftGtk also
requires the legacy `libatk1.0-dev` development files even though GTK4 no
longer uses Atk directly. While the system-wide ATK install waits for Sarah,
`script/stage-atk-dev.sh` downloads that exact package without installing it,
extracts only its public development artifacts beneath the ignored
`.build/sysroot`, and links them to the already-installed ATK runtime. No root
access or system mutation is involved.

The pinned gir2swift checkout receives two audited, idempotent build-copy
patches from `patches/gir2swift/`. They add `GIR2SWIFT_GIR_PATH` to both the
plugin and library lookup paths so the repo-local ATK GIR is discoverable.

## Upstream maintenance risk

The pinned SwiftGtk manifest applies `-suppress-warnings` to its generated
binding target and still depends on the legacy Atk GIR on GTK4. awesoMux source
uses no warning suppression and is checked with warnings-as-errors; the
upstream flags and Atk dependency must be reevaluated at every SwiftGtk pin
update.
