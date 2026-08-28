#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_tree="$repo_root/vendor/ghostty"
stage_root="${AWESOMUX_GHOSTTY_STAGE:-$repo_root/.build/ghostty-stage}"
expected_commit=f2d5758f6305867dc36b36293c6165d8152b853e

actual_commit=$(git -C "$source_tree" rev-parse HEAD)
if [[ "$actual_commit" != "$expected_commit" ]]; then
  echo "Ghostty pin mismatch: expected $expected_commit, found $actual_commit" >&2
  exit 1
fi
if [[ -n "$(git -C "$source_tree" status --short)" ]]; then
  echo "Refusing to stage from a dirty Ghostty checkout" >&2
  exit 1
fi

mkdir -p "$(dirname "$stage_root")"
if [[ -e "$stage_root" ]]; then
  echo "Stage path already exists: $stage_root" >&2
  echo "Remove that disposable directory explicitly, then rerun." >&2
  exit 1
fi

git clone --quiet --no-hardlinks "$source_tree" "$stage_root"
git -C "$stage_root" checkout --quiet --detach "$expected_commit"
for patch in "$repo_root"/patches/ghostty/*.patch; do
  git -C "$stage_root" apply --check "$patch"
  git -C "$stage_root" apply "$patch"
done

echo "$stage_root"
