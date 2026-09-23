#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage_dir="$repo_root/.build/sysroot/root/usr/share/gir-1.0"
system_dir=/usr/share/gir-1.0
archive="$repo_root/.build/downloads/gobject-introspection-1.86.0-2-x86_64.pkg.tar.zst"
signature="$archive.sig"
expected_sha=03b932edc9e8bfaced0fc2a0970ccf2879c5d03961109664f96deb9ac8d9440b

[[ -d "$system_dir" ]] || {
  echo "System GIR directory is missing: $system_dir" >&2
  exit 1
}
mkdir -p "$stage_dir"

# gir2swift requires all GIRs for a target in one directory. Link the host's
# metadata into the existing ignored ATK staging directory.
for gir in "$system_dir"/*.gir; do
  [[ -f "$gir" ]] || continue
  staged="$stage_dir/${gir##*/}"
  if [[ -L "$staged" && "$(readlink "$staged")" == "$gir" ]]; then
    continue
  fi
  if [[ -f "$staged" && ! -L "$staged" ]] && cmp -s "$gir" "$staged"; then
    continue
  fi
  ln -sfnT "$gir" "$staged"
done

if [[ ! -f "$system_dir/cairo-1.0.gir" ]]; then
  [[ -f /etc/arch-release ]] || {
    echo "Cairo GIR is missing from $system_dir. Provide this host's gobject-introspection development GIR files; the Arch archive fallback applies only to Arch." >&2
    exit 1
  }
  [[ -f "$archive" && -f "$signature" ]] || {
    echo "Missing Arch gobject-introspection 1.86.0-2 archive and signature in .build/downloads/." >&2
    echo "Download both from https://geo.mirror.pkgbuild.com/extra/os/x86_64/; see docs/development.md." >&2
    exit 1
  }
  echo "$expected_sha  $archive" | sha256sum --check --status || {
    echo "Arch gobject-introspection archive checksum mismatch." >&2
    exit 1
  }
  pacman-key --verify "$signature" "$archive" >/dev/null || {
    echo "Arch gobject-introspection archive signature verification failed." >&2
    exit 1
  }

  # Extract only missing GIR metadata. Do not install the package or copy its
  # implementation, headers, executables, or Python modules.
  while IFS= read -r member; do
    gir_name=${member##*/}
    [[ -f "$system_dir/$gir_name" ]] && continue
    temporary=$(mktemp "$stage_dir/.$gir_name.XXXXXXXX")
    bsdtar -xOf "$archive" "$member" > "$temporary"
    staged="$stage_dir/$gir_name"
    if [[ -f "$staged" && ! -L "$staged" ]] && cmp -s "$temporary" "$staged"; then
      rm -f "$temporary"
    else
      mv -fT "$temporary" "$staged"
    fi
  done < <(bsdtar -tf "$archive" | sed -n '/^usr\/share\/gir-1\.0\/.*\.gir$/p')
fi

[[ -f "$stage_dir/cairo-1.0.gir" ]] || {
  echo "Cairo GIR is unavailable after staging." >&2
  exit 1
}
