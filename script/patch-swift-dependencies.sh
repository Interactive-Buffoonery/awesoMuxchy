#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
checkout="$repo_root/swift-gtk/.build/checkouts/gir2swift"

[[ -d "$checkout/.git" ]] || {
  echo "Resolve the Swift package before applying dependency patches." >&2
  exit 1
}

for patch in "$repo_root"/patches/gir2swift/*.patch; do
  if git -C "$checkout" apply --unidiff-zero --reverse --check "$patch" 2>/dev/null; then
    echo "gir2swift patch already applied: $(basename "$patch")"
  elif git -C "$checkout" apply --unidiff-zero --check "$patch"; then
    git -C "$checkout" apply --unidiff-zero "$patch"
    echo "gir2swift patch applied: $(basename "$patch")"
  else
    echo "gir2swift patch does not apply cleanly: $patch" >&2
    exit 1
  fi
done
