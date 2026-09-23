#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
command -v gtk4-broadwayd >/dev/null || {
  echo "clipboard permission test requires gtk4-broadwayd for an isolated clipboard" >&2
  exit 1
}
mkdir -p "$repo_root/.build/clipboard-permission"
cc -std=c17 -Wall -Wextra -Werror \
  $(pkg-config --cflags gtk4) \
  -I"$repo_root/.build/ghostty-prefix/include" \
  -I"$repo_root/ghostty-shim/include" \
  "$repo_root/ghostty-shim/tests/clipboard_permission.c" \
  "$repo_root/.build/ghostty-shim/glad.o" \
  "$repo_root/.build/ghostty-prefix/lib/ghostty-internal.so" \
  $(pkg-config --libs gtk4) \
  -o "$repo_root/.build/clipboard-permission/test"
# Keep synthetic clipboard mutations inside a private GTK Broadway display.
# The user's live Wayland clipboard must never be used as a test fixture.
broadway_display=":$((1000 + $$ % 50000))"
gtk4-broadwayd -p 0 "$broadway_display" >/dev/null 2>&1 &
broadway_pid=$!
trap 'kill "$broadway_pid" 2>/dev/null || true; wait "$broadway_pid" 2>/dev/null || true' EXIT
sleep 0.3
GDK_BACKEND=broadway BROADWAY_DISPLAY="$broadway_display" \
  LD_LIBRARY_PATH="$repo_root/.build/ghostty-prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$repo_root/.build/clipboard-permission/test"
