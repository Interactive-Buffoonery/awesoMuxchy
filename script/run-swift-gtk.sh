#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
shim="$repo_root/.build/ghostty-shim"
atk_root="$repo_root/.build/sysroot/root"
link_root="$repo_root/.build/link-lib"

export PATH="$repo_root/.build/toolchains/swift/usr/bin:$repo_root/.build/toolchains/zig:$PATH"

"$repo_root/script/stage-atk-dev.sh"

if [[ ! -f "$shim/lib/libawesomux-ghostty.so" ]]; then
  "$repo_root/script/build-ghostty-shim.sh"
fi

export PKG_CONFIG_PATH="$shim${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="$atk_root/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH"
export LIBRARY_PATH="$link_root${LIBRARY_PATH:+:$LIBRARY_PATH}"
export LD_LIBRARY_PATH="$link_root:$shim/lib:$repo_root/.build/ghostty-prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export GIR2SWIFT_GIR_PATH="$atk_root/usr/share/gir-1.0"
export C_INCLUDE_PATH="$atk_root/usr/include/atk-1.0${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
"$repo_root/script/patch-swift-dependencies.sh"
exec swift run --package-path "$repo_root/swift-gtk" awesomux "$@"
