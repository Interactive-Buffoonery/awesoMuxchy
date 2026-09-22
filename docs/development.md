# Local GTK development on pinguchy

This is the current Arch/Omarchy development host. The active application is
`swift-gtk/`, using the shared Ghostty shim. The target i5GamingPC still owns
Wayland/X11 desktop comparison and daily-use validation evidence; launching on
pinguchy is a local development check, not a parity sign-off.

## Prerequisites

`script/dev.sh` requires verified repository-local Swift 6.3.3 at
`.build/toolchains/swift/usr/bin/swift` and Zig 0.16.0 at
`.build/toolchains/zig/zig`. It does not install them or change system packages.
The official x86_64 archives are:

- [Swift 6.3.3 for Ubuntu 24.04](https://download.swift.org/swift-6.3.3-release/ubuntu2404/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE-ubuntu24.04.tar.gz) and its [PGP signature](https://download.swift.org/swift-6.3.3-release/ubuntu2404/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE-ubuntu24.04.tar.gz.sig). Follow [Swift's signature verification instructions](https://www.swift.org/install/linux/tarball/) using `curl --compressed` to fetch [Swift's keys](https://www.swift.org/keys/all-keys.asc). The tarball expands to `usr/` inside the Swift toolchain directory.
- [Zig 0.16.0 for Linux x86_64](https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz) and its [minisign signature](https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz.minisig). The [official release index](https://ziglang.org/download/index.json) gives SHA-256 `70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00`. Extract the archive's contents directly into the Zig toolchain directory so that `zig` is at the path above.

Swift's archive targets Ubuntu 24.04; Arch is outside [Swift's listed supported
Linux platforms](https://www.swift.org/platform-support/). A valid signature
does not establish that its dynamic libraries work on this host. The official
toolchain needed four Ubuntu 24.04 runtime packages because Arch has different
ncurses and libxml2 library names and ICU 78. They are staged only in
`.build/toolchains/compat/`, and `script/dev.sh`, `script/run-swift-gtk.sh`, and
`script/preflight.sh` prepend its `usr/lib/x86_64-linux-gnu` directory to
`LD_LIBRARY_PATH`. Do not create versioned library symlinks to mask an ABI
mismatch.

| Package | Ubuntu archive | SHA-256 |
| --- | --- | --- |
| `libncurses6` `6.4+20240113-1ubuntu2.2` | [amd64 `.deb`](https://security.ubuntu.com/ubuntu/pool/main/n/ncurses/libncurses6_6.4%2B20240113-1ubuntu2.2_amd64.deb) | `59e8527dfd14473393960bfb7c69566f1ad9d576423421dcb8b8dcdbb3e7fca1` |
| `libtinfo6` `6.4+20240113-1ubuntu2.2` | [amd64 `.deb`](https://security.ubuntu.com/ubuntu/pool/main/n/ncurses/libtinfo6_6.4%2B20240113-1ubuntu2.2_amd64.deb) | `b67a6df2bdab61d273eabebd208bb6a3fb12618a390a067e1ee305a409ff03d9` |
| `libxml2` `2.9.14+dfsg-1.3ubuntu3.9` | [amd64 `.deb`](https://security.ubuntu.com/ubuntu/pool/main/libx/libxml2/libxml2_2.9.14%2Bdfsg-1.3ubuntu3.9_amd64.deb) | `6e578bc383096718c9eea8a76a3edfacfea06e525e1aa7a187ee41906436d94e` |
| `libicu74` `74.2-1ubuntu3.1` | [amd64 `.deb`](https://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu74_74.2-1ubuntu3.1_amd64.deb) | `c9a70989678660eed9a1e904c74fa043da8bec8e2036856fc16e31ced79b04f8` |

These are the current Ubuntu [ncurses](https://packages.ubuntu.com/noble/amd64/libncurses6),
[libxml2](https://packages.ubuntu.com/noble/libxml2), and
[ICU](https://packages.ubuntu.com/noble-updates/libicu74) runtime packages.
`libncurses6` requires the matching `libtinfo6`; `libxml2` requires ICU 74.
After downloading the four files to `.build/downloads/` with the short names
below, verify and extract with the host's `ar` and `bsdtar`:

```sh
sha256sum -c <<'CHECKSUMS'
59e8527dfd14473393960bfb7c69566f1ad9d576423421dcb8b8dcdbb3e7fca1  .build/downloads/libncurses6.deb
b67a6df2bdab61d273eabebd208bb6a3fb12618a390a067e1ee305a409ff03d9  .build/downloads/libtinfo6.deb
6e578bc383096718c9eea8a76a3edfacfea06e525e1aa7a187ee41906436d94e  .build/downloads/libxml2.deb
c9a70989678660eed9a1e904c74fa043da8bec8e2036856fc16e31ced79b04f8  .build/downloads/libicu74.deb
CHECKSUMS
mkdir -p .build/toolchains/compat
for package in libncurses6 libtinfo6 libxml2 libicu74; do
  deb=".build/downloads/$package.deb"
  member=$(ar t "$deb" | sed -n '/^data\.tar\./p')
  ar p "$deb" "$member" | bsdtar -xf - -C .build/toolchains/compat
done
```

With that compatibility directory in `LD_LIBRARY_PATH`, `swift --version` and
`swift package --version` both report 6.3.3, and `ldd` reports no missing
libraries for `swift` or `swift-package`. The awesoMux core also passed Swift
warnings-as-errors typechecking on this host. Those checks do not establish
that the GTK app builds or launches on other hosts. On this host, the completed
debug build and native Wayland launch were subsequently verified: the development
window exposed its workspace action and created a real Ghostty shell. Its
app-only capture was inspected. No i5GamingPC parity claim follows from this
local smoke check. The existing Swift package suite also passes all 130 tests.

This host has GTK4 and ATK development metadata and the ATK GIR. Confirm them
with `pkg-config --modversion gtk4 atk` and
`test -f /usr/share/gir-1.0/Atk-1.0.gir`. The launcher checks these without
installing packages. Arch's `gobject-introspection-runtime` provides the Cairo
typelib, while the missing `cairo-1.0.gir` belongs to the separate
[`gobject-introspection` development package](https://archlinux.org/packages/extra/x86_64/gobject-introspection/files/).
`script/stage-girs.sh` verifies the pinned 1.86.0-2 package's SHA-256
`03b932edc9e8bfaced0fc2a0970ccf2879c5d03961109664f96deb9ac8d9440b`
and Arch package signature, then extracts only missing GIR metadata into the
ignored `.build/sysroot/root/usr/share/gir-1.0/` directory. It links the
host's existing GIRs there because gir2swift requires related GIRs in one
directory. Download the [package](https://geo.mirror.pkgbuild.com/extra/os/x86_64/gobject-introspection-1.86.0-2-x86_64.pkg.tar.zst)
and [signature](https://geo.mirror.pkgbuild.com/extra/os/x86_64/gobject-introspection-1.86.0-2-x86_64.pkg.tar.zst.sig)
to `.build/downloads/` with those basenames before the first run. No system
package installation or pinned Swift dependency change is involved.

The pinned Ghostty and zmx submodules and locked Swift
packages must also be available. The first Swift package resolution may need
network access; it uses `swift-gtk/Package.resolved` with
`--force-resolved-versions` before the existing gir2swift build-copy patches.

Pango 1.58 also introduces a composed C macro Swift cannot import. The
repository patch in `patches/swiftpango/` uses the pinned binding package's
existing verbatim-constant setting to emit the GIR's integer value instead.
`script/patch-swift-dependencies.sh` applies it after dependency resolution.

On this Arch host, Zig 0.16's default linker cannot link Ghostty's
`ghostty-build-data` helper against the system glibc/GCC startup object:
`crt1.o` contains an `.sframe` relocation reported as `R_X86_64_PC64`.
`patches/ghostty/0004-arch-host-build-data-linker.patch` adds an opt-in
LLVM/LLD setting for that host helper; `script/build-ghostty.sh` enables it on
Arch and caps Zig to two jobs by default (`AWESOMUX_BUILD_JOBS` overrides the
count). An isolated Zig probe and the full staged Ghostty plus GTK shim build
passed with the combined setting. Ubuntu's default linker path is unchanged.

## Run

From the repository root:

```sh
./script/dev.sh
```

Use `./script/dev.sh --build-only` to compile without opening a window, or
`./script/dev.sh --test` to run the existing Swift package tests. The build-only
executable is `swift-gtk/.build/debug/awesomux`; use the wrapper to launch it
with the required runtime library and Ghostty resource paths.
`./script/dev.sh --run-only` launches that existing build without invoking
SwiftPM. This is useful while iterating on runtime checks: SwiftPM can still
relink the binding generator and regenerate bindings between build commands.

The wrapper calls `script/run-swift-gtk.sh` with a two-job Swift build limit by
default. Set `AWESOMUX_BUILD_JOBS` to another positive integer if needed.
Other application arguments pass through to `awesomux`.

The development app uses its own GTK application ID and stores configuration
and session snapshots below `.build/dev-profile/`. It leaves `XDG_RUNTIME_DIR`,
the Wayland/X11 display environment, and the normal awesoMux profile alone.
Child shells currently inherit the development profile's `XDG_CONFIG_HOME` and
`XDG_STATE_HOME`, the repository's build-tool `PATH`, and its compatibility
`LD_LIBRARY_PATH`; normal CLI configuration and library resolution may
therefore differ while smoke testing in those shells. Daily-use behavior has
not yet been validated.
`./script/preflight.sh` remains the complete local verification command;
it includes desktop checks that require a suitable display and all pinned
dependencies. Record the actual result and any missing target-machine evidence
in the implementation status documents.
