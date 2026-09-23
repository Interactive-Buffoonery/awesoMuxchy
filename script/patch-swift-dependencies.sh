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

# Pango 1.58 exposes RENDER_COMPONENT_ALL as a C macro that Swift cannot import.
# Its GIR records the integer value; SwiftPango's verbatim list selects that
# value for generated Swift without changing the generator for other constants.
pango_checkout="$repo_root/swift-gtk/.build/checkouts/SwiftPango"
[[ -d "$pango_checkout/.git" ]] || {
  echo "Resolve SwiftPango before applying dependency patches." >&2
  exit 1
}
for patch in "$repo_root"/patches/swiftpango/*.patch; do
  if git -C "$pango_checkout" apply --reverse --check "$patch" 2>/dev/null; then
    echo "SwiftPango patch already applied: $(basename "$patch")"
  elif git -C "$pango_checkout" apply --check "$patch"; then
    git -C "$pango_checkout" apply "$patch"
    echo "SwiftPango patch applied: $(basename "$patch")"
  else
    echo "SwiftPango patch does not apply cleanly: $patch" >&2
    exit 1
  fi
done
