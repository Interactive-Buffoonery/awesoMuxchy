#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage_root="$repo_root/.build/sysroot/root"
download_root="$repo_root/.build/atk-dev-download"
link_root="$repo_root/.build/link-lib"
pc_file="$stage_root/usr/lib/x86_64-linux-gnu/pkgconfig/atk.pc"
gir_file="$stage_root/usr/share/gir-1.0/Atk-1.0.gir"
include_dir="$stage_root/usr/include/atk-1.0"
system_gir=/usr/share/gir-1.0/Atk-1.0.gir

system_pkg_config() {
  env -u PKG_CONFIG_PATH -u PKG_CONFIG_LIBDIR -u PKG_CONFIG_SYSROOT_DIR pkg-config "$@"
}

link_if_needed() {
  local source=$1 destination=$2
  if [[ -L "$destination" && "$(readlink "$destination")" == "$source" ]]; then
    return
  fi
  ln -sfnT "$source" "$destination"
}

if system_pkg_config --exists atk && [[ -f "$system_gir" ]]; then
  system_pc="$(system_pkg_config --variable=pcfiledir atk)/atk.pc"
  system_include="$(system_pkg_config --variable=includedir atk)/atk-1.0"
  system_library="$(system_pkg_config --variable=libdir atk)/libatk-1.0.so"
  [[ -f "$system_pc" && -f "$system_include/atk/atk.h" && -f "$system_library" ]] || {
    echo "System ATK metadata is incomplete: expected atk.pc, headers, and libatk-1.0.so from pkg-config." >&2
    exit 1
  }
  mkdir -p "$(dirname "$pc_file")" "$(dirname "$gir_file")" "$(dirname "$include_dir")"
  link_if_needed "$system_pc" "$pc_file"
  link_if_needed "$system_gir" "$gir_file"
  if [[ ! -d "$include_dir" || -L "$include_dir" ]]; then
    link_if_needed "$system_include" "$include_dir"
  fi
  runtime_library="$system_library"
else
  if [[ ! -f "$pc_file" || ! -f "$gir_file" ]]; then
    if [[ ! -f /etc/debian_version ]] || ! command -v apt-get >/dev/null || ! command -v dpkg-deb >/dev/null; then
      echo "ATK development metadata is missing: need system atk.pc and Atk-1.0.gir; Ubuntu/Debian archive staging is unavailable on this host." >&2
      exit 1
    fi
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
  [[ -f "$pc_file" && -f "$gir_file" ]] || {
    echo "Staged libatk1.0-dev is missing atk.pc or Atk-1.0.gir." >&2
    exit 1
  }
  runtime_library=$(ldconfig -p | awk '/libatk-1\.0\.so\.0 \(/{if (!library) library=$NF} END {print library}')
fi

[[ -f "$runtime_library" ]] || {
  echo "The ATK runtime library is missing." >&2
  exit 1
}

mkdir -p "$link_root"
link_if_needed "$runtime_library" "$link_root/libatk-1.0.so"
link_if_needed "$repo_root/.build/ghostty-shim/lib/libawesomux-ghostty.so" \
  "$link_root/libawesomux-ghostty.so"
