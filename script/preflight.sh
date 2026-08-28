#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
swift_bin="$repo_root/.build/toolchains/swift/usr/bin/swift"
swiftc_bin="$repo_root/.build/toolchains/swift/usr/bin/swiftc"
zig_bin="$repo_root/.build/toolchains/zig/zig"
ghostty_commit=f2d5758f6305867dc36b36293c6165d8152b853e
zmx_commit=67c6f63c9f27e96733015f3099363a92d73e836e

fail() {
  echo "preflight: $*" >&2
  exit 1
}

[[ -x "$swift_bin" ]] || fail "verified repo-local Swift 6.3.3 is missing"
[[ -x "$zig_bin" ]] || fail "verified repo-local Zig 0.16.0 is missing"
[[ "$($zig_bin version)" == "0.16.0" ]] || fail "Zig pin mismatch"
"$swift_bin" --version | grep -q 'Swift version 6.3.3' || fail "Swift pin mismatch"
pkg-config --exists gtk4 || fail "gtk4 development metadata is missing"
"$repo_root/script/stage-atk-dev.sh"

[[ "$(git -C "$repo_root/vendor/ghostty" rev-parse HEAD)" == "$ghostty_commit" ]] ||
  fail "Ghostty submodule pin mismatch"
[[ -z "$(git -C "$repo_root/vendor/ghostty" status --short)" ]] ||
  fail "Ghostty submodule is dirty"
[[ "$(git -C "$repo_root/vendor/zmx" rev-parse HEAD)" == "$zmx_commit" ]] ||
  fail "zmx submodule pin mismatch"
[[ -z "$(git -C "$repo_root/vendor/zmx" status --short)" ]] ||
  fail "zmx submodule is dirty"
git -C "$repo_root/vendor/ghostty" apply --check \
  "$repo_root/patches/ghostty/0001-embedded-linux-opengl-host.patch"

"$repo_root/script/check-text-baseline.py"
"$swiftc_bin" -warnings-as-errors -typecheck \
  "$repo_root/swift-gtk/Sources/AwesoMuxCore/SessionModel.swift" \
  "$repo_root/swift-gtk/Sources/AwesoMuxCore/SessionStore.swift"

cc -std=c17 -fsyntax-only -Wall -Wextra -Werror \
  $(pkg-config --cflags gtk4) \
  -I"$repo_root/.build/ghostty-prefix/include" \
  -I"$repo_root/ghostty-shim/include" \
  "$repo_root/ghostty-shim/src/awesomux_ghostty.c"

"$repo_root/script/build-ghostty-shim.sh"
export PATH="$repo_root/.build/toolchains/swift/usr/bin:$repo_root/.build/toolchains/zig:$PATH"
export PKG_CONFIG_PATH="$repo_root/.build/ghostty-shim:$repo_root/.build/sysroot/root/usr/lib/x86_64-linux-gnu/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LIBRARY_PATH="$repo_root/.build/link-lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
export LD_LIBRARY_PATH="$repo_root/.build/link-lib:$repo_root/.build/ghostty-shim/lib:$repo_root/.build/ghostty-prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export GIR2SWIFT_GIR_PATH="$repo_root/.build/sysroot/root/usr/share/gir-1.0"
export C_INCLUDE_PATH="$repo_root/.build/sysroot/root/usr/include/atk-1.0${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
"$repo_root/script/patch-swift-dependencies.sh"
swift test --package-path "$repo_root/swift-gtk"
swift build --package-path "$repo_root/swift-gtk" -c release
release_bin=$(swift build --package-path "$repo_root/swift-gtk" -c release --show-bin-path)
qa_display=${DISPLAY:-:1}
env GDK_BACKEND=x11 GDK_DEBUG=gl-glx DISPLAY="$qa_display" \
  "$release_bin/awesomux-terminal-integration"
env GDK_BACKEND=x11 GDK_DEBUG=gl-glx DISPLAY="$qa_display" \
  "$release_bin/awesomux-lifecycle-stress"

git -C "$repo_root" diff --check
echo "preflight: passed"
