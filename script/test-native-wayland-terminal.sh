#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
release_bin=${1:-"$repo_root/swift-gtk/.build/release"}

user_environment=$(systemctl --user show-environment 2>/dev/null || true)
environment_value() {
  local name=$1
  local value
  value=$(printf '%s\n' "$user_environment" | sed -n "s/^${name}=//p" | head -n 1)
  printf '%s' "$value"
}

wayland_display=${WAYLAND_DISPLAY:-$(environment_value WAYLAND_DISPLAY)}
runtime_directory=${XDG_RUNTIME_DIR:-$(environment_value XDG_RUNTIME_DIR)}

if [[ -z "$wayland_display" || -z "$runtime_directory" ]]; then
  echo "native Wayland test: no user Wayland session is available" >&2
  exit 1
fi

common_environment=(
  -u DISPLAY
  "XDG_RUNTIME_DIR=$runtime_directory"
  "WAYLAND_DISPLAY=$wayland_display"
  XDG_SESSION_TYPE=wayland
  GDK_BACKEND=wayland
  "GHOSTTY_RESOURCES_DIR=$repo_root/.build/ghostty-prefix/share/ghostty"
  "LD_LIBRARY_PATH=$repo_root/.build/link-lib:$repo_root/.build/ghostty-shim/lib:$repo_root/.build/ghostty-prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
)

env "${common_environment[@]}" \
  "$release_bin/awesomux-terminal-integration"
env "${common_environment[@]}" \
  "$release_bin/awesomux-lifecycle-stress"

echo "native Wayland test: passed terminal integration and lifecycle stress"
