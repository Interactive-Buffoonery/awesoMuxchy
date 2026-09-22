#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage_root="${AWESOMUX_GHOSTTY_STAGE:-$repo_root/.build/ghostty-stage}"
zig_bin="${AWESOMUX_ZIG:-zig}"
build_jobs="${AWESOMUX_BUILD_JOBS:-2}"

if [[ ! "$build_jobs" =~ ^[1-9][0-9]*$ ]]; then
  echo "AWESOMUX_BUILD_JOBS must be a positive integer." >&2
  exit 1
fi

if [[ ! -d "$stage_root" ]]; then
  "$repo_root/script/stage-ghostty.sh" >/dev/null
fi

for patch in "$repo_root"/patches/ghostty/*.patch; do
  if ! git -C "$stage_root" apply --reverse --check "$patch" 2>/dev/null; then
    echo "Staged Ghostty is missing the current patch: $(basename "$patch")" >&2
    echo "Move or remove only the disposable stage at $stage_root, then rebuild." >&2
    exit 1
  fi
done

if ! command -v "$zig_bin" >/dev/null 2>&1; then
  echo "Zig 0.16.0 is required; set AWESOMUX_ZIG or install the approved toolchain." >&2
  exit 1
fi

version=$($zig_bin version)
if [[ "$version" != "0.16.0" ]]; then
  echo "Zig 0.16.0 is required; found $version" >&2
  exit 1
fi

host_linker_options=()
if [[ -f /etc/arch-release ]]; then
  # Arch's glibc 2.44/GCC 16 crt1.o needs LLVM and LLD for the host helper.
  host_linker_options+=(-Dawesomux-host-llvm-lld=true)
fi

"$zig_bin" build \
  --build-file "$stage_root/build.zig" \
  --prefix "$repo_root/.build/ghostty-prefix" \
  -j"$build_jobs" \
  -Dapp-runtime=none \
  -Doptimize=ReleaseFast \
  "${host_linker_options[@]}"

# Ghostty's installed internal library currently has SONAME libghostty.so but
# is emitted as ghostty-internal.so. Keep that upstream output untouched and
# provide the SONAME alias inside the disposable build prefix.
ln -sfn ghostty-internal.so "$repo_root/.build/ghostty-prefix/lib/libghostty.so"
