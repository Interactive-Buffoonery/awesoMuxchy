#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
prefix="$repo_root/.build/ghostty-prefix"
output="$repo_root/.build/ghostty-shim"

if ! pkg-config --exists gtk4; then
  echo "GTK4 development files are required (pkg-config gtk4 failed)." >&2
  exit 1
fi
if [[ ! -f "$prefix/include/ghostty.h" ]]; then
  "$repo_root/script/build-ghostty.sh"
fi

mkdir -p "$output/lib" "$output/include"
cp "$repo_root/ghostty-shim/include/awesomux_ghostty.h" "$output/include/"
cp "$repo_root/ghostty-shim/awesomux-ghostty.pc" "$output/"

cc -std=c17 -fPIC -Wall -Wextra -Werror \
  -I"$repo_root/.build/ghostty-stage/vendor/glad/include" \
  -c "$repo_root/.build/ghostty-stage/vendor/glad/src/gl.c" \
  -o "$output/glad.o"

cc -std=c17 -fPIC -fvisibility=hidden -Wall -Wextra -Werror \
  $(pkg-config --cflags gtk4) \
  -I"$prefix/include" \
  -I"$repo_root/ghostty-shim/include" \
  -shared "$repo_root/ghostty-shim/src/awesomux_ghostty.c" \
  "$output/glad.o" \
  "$prefix/lib/ghostty-internal.so" \
  $(pkg-config --libs gtk4) \
  -Wl,-rpath,'$ORIGIN/../../ghostty-prefix/lib' \
  -o "$output/lib/libawesomux-ghostty.so"
