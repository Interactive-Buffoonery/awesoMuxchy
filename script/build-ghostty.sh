#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage_root="${AWESOMUX_GHOSTTY_STAGE:-$repo_root/.build/ghostty-stage}"
zig_bin="${AWESOMUX_ZIG:-zig}"

if [[ ! -d "$stage_root" ]]; then
  "$repo_root/script/stage-ghostty.sh" >/dev/null
fi

if ! command -v "$zig_bin" >/dev/null 2>&1; then
  echo "Zig 0.16.0 is required; set AWESOMUX_ZIG or install the approved toolchain." >&2
  exit 1
fi

version=$($zig_bin version)
if [[ "$version" != "0.16.0" ]]; then
  echo "Zig 0.16.0 is required; found $version" >&2
  exit 1
fi

"$zig_bin" build \
  --build-file "$stage_root/build.zig" \
  --prefix "$repo_root/.build/ghostty-prefix" \
  -Dapp-runtime=none \
  -Doptimize=ReleaseFast

# Ghostty's installed internal library currently has SONAME libghostty.so but
# is emitted as ghostty-internal.so. Keep that upstream output untouched and
# provide the SONAME alias inside the disposable build prefix.
ln -sfn ghostty-internal.so "$repo_root/.build/ghostty-prefix/lib/libghostty.so"
