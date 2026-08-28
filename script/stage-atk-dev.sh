#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage_root="$repo_root/.build/sysroot/root"
download_root="$repo_root/.build/atk-dev-download"
link_root="$repo_root/.build/link-lib"
pc_file="$stage_root/usr/lib/x86_64-linux-gnu/pkgconfig/atk.pc"

if [[ ! -f "$pc_file" ]]; then
  mkdir -p "$download_root" "$stage_root"
  (
    cd "$download_root"
    apt-get download libatk1.0-dev
  )
  deb=$(find "$download_root" -maxdepth 1 -type f -name 'libatk1.0-dev_*.deb' | sort | tail -n 1)
  [[ -n "$deb" ]] || {
    echo "Could not download the approved libatk1.0-dev archive." >&2
    exit 1
  }
  dpkg-deb -x "$deb" "$stage_root"
fi

runtime_library=$(ldconfig -p | awk '/libatk-1\.0\.so\.0 \(/{print $NF; exit}')
[[ -f "$runtime_library" ]] || {
  echo "The ATK runtime library is missing." >&2
  exit 1
}

mkdir -p "$link_root"
ln -sfn "$runtime_library" "$link_root/libatk-1.0.so"
ln -sfn "$repo_root/.build/ghostty-shim/lib/libawesomux-ghostty.so" \
  "$link_root/libawesomux-ghostty.so"
