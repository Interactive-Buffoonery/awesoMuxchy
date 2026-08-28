#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
binary="$repo_root/.build/tools/capture-x11-window"
mkdir -p "$(dirname "$binary")"

cc -std=c17 -Wall -Wextra -Werror \
  "$repo_root/script/capture-x11-window.c" \
  $(pkg-config --cflags --libs x11 gdk-pixbuf-2.0) \
  -o "$binary"

exec "$binary" "$@"
