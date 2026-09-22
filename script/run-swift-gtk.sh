#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
shim="$repo_root/.build/ghostty-shim"
atk_root="$repo_root/.build/sysroot/root"
link_root="$repo_root/.build/link-lib"
compat_lib="$repo_root/.build/toolchains/compat/usr/lib/x86_64-linux-gnu"
if [[ -d "$compat_lib" ]]; then
  export LD_LIBRARY_PATH="$compat_lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

export PATH="$repo_root/.build/toolchains/swift/usr/bin:$repo_root/.build/toolchains/zig:$PATH"

"$repo_root/script/stage-atk-dev.sh"
"$repo_root/script/stage-girs.sh"

if [[ ! -f "$shim/lib/libawesomux-ghostty.so" ]]; then
  "$repo_root/script/build-ghostty-shim.sh"
fi

export PKG_CONFIG_PATH="$shim${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="$atk_root/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH"
export LIBRARY_PATH="$link_root${LIBRARY_PATH:+:$LIBRARY_PATH}"
export LD_LIBRARY_PATH="$link_root:$shim/lib:$repo_root/.build/ghostty-prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export GHOSTTY_RESOURCES_DIR="$repo_root/.build/ghostty-prefix/share/ghostty"
export GIR2SWIFT_GIR_PATH="$atk_root/usr/share/gir-1.0:/usr/share/gir-1.0"
export C_INCLUDE_PATH="$atk_root/usr/include/atk-1.0${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
"$repo_root/script/patch-swift-dependencies.sh"
build_jobs="${AWESOMUX_BUILD_JOBS:-}"
swift_options=(--package-path "$repo_root/swift-gtk" --force-resolved-versions)
if [[ -n "$build_jobs" ]]; then
  [[ "$build_jobs" =~ ^[1-9][0-9]*$ ]] || {
    echo "AWESOMUX_BUILD_JOBS must be a positive integer." >&2
    exit 1
  }
  swift_options+=(--jobs "$build_jobs")
fi
case "${1:-}" in
  --run-only)
    shift
    app_bin="$repo_root/swift-gtk/.build/debug/awesomux"
    [[ -x "$app_bin" ]] || {
      echo "Build the development app first with ./script/dev.sh --build-only." >&2
      exit 1
    }
    exec "$app_bin" "$@"
    ;;
  --build-only)
    shift
    exec swift build "${swift_options[@]}" --product awesomux "$@"
    ;;
  --test)
    shift
    exec swift test "${swift_options[@]}" "$@"
    ;;
  *)
    exec swift run "${swift_options[@]}" awesomux "$@"
    ;;
esac
