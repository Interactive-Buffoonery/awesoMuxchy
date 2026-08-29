#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 1 ]] || { echo "forced-termination persistence: missing probe" >&2; exit 2; }
probe=$1
[[ -x "$probe" ]] || { echo "forced-termination persistence: probe is unavailable" >&2; exit 2; }

test_root=$(mktemp -d /tmp/awesomux-forced-termination-XXXXXX)
child_pid=
cleanup() {
  if [[ -n "$child_pid" ]]; then kill -KILL "$child_pid" 2>/dev/null || true; fi
  rm -rf "$test_root"
}
trap cleanup EXIT

wait_until_ready() {
  for _ in {1..100}; do
    [[ -f "$test_root/ready" ]] && return 0
    sleep 0.05
  done
  echo "forced-termination persistence: probe did not become ready" >&2
  return 1
}

"$probe" seed "$test_root"
"$probe" stage "$test_root" &
child_pid=$!
wait_until_ready
sleep 0.1
kill -KILL "$child_pid"
wait "$child_pid" 2>/dev/null || true
child_pid=
"$probe" verify "$test_root" Baseline

rm -f "$test_root/ready"
"$probe" stage "$test_root" &
child_pid=$!
wait_until_ready
sleep 0.8
kill -KILL "$child_pid"
wait "$child_pid" 2>/dev/null || true
child_pid=
"$probe" verify "$test_root" Latest

echo "forced-termination persistence: passed pre-debounce safety and post-debounce durability"
