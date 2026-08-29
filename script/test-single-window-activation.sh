#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "single-window activation: $*" >&2
  exit 1
}

[[ $# -eq 1 ]] || fail "usage: $0 /path/to/awesomux"
app_bin=$1
[[ -x "$app_bin" ]] || fail "application executable is missing"
command -v xprop >/dev/null || fail "xprop is required"

probe_root=$(mktemp -d)
app_pid=""
cleanup() {
  if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
    kill -TERM "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  rm -r -- "$probe_root"
}
trap cleanup EXIT

export XDG_STATE_HOME="$probe_root/state"
export XDG_CONFIG_HOME="$probe_root/config"
export GDK_BACKEND=x11
export GDK_DEBUG=gl-glx
export GTK_USE_PORTAL=0
export GIO_USE_VFS=local
export NO_AT_BRIDGE=1
export GTK_A11Y=none
export AWESOMUX_SINGLE_WINDOW_PROBE=1

normal_window_count() {
  local count=0 id owner type
  while read -r id; do
    [[ -n "$id" ]] || continue
    owner=$(xprop -id "$id" _NET_WM_PID 2>/dev/null | sed -n 's/.* = //p')
    [[ "$owner" == "$app_pid" ]] || continue
    type=$(xprop -id "$id" _NET_WM_WINDOW_TYPE 2>/dev/null || true)
    if [[ "$type" == *"_NET_WM_WINDOW_TYPE_NORMAL"* ]]; then
      count=$((count + 1))
    fi
  done < <(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -oE '0x[0-9a-fA-F]+' || true)
  echo "$count"
}

"$app_bin" >"$probe_root/app.stdout" 2>"$probe_root/app.stderr" &
app_pid=$!

initial_count=0
for _ in {1..100}; do
  kill -0 "$app_pid" 2>/dev/null || fail "primary process exited during launch"
  initial_count=$(normal_window_count)
  [[ "$initial_count" == 1 ]] && break
  sleep 0.05
done
[[ "$initial_count" == 1 ]] || fail "expected one primary window after launch"

for _ in 1 2 3; do
  "$app_bin" >/dev/null 2>&1 || fail "secondary activation failed"
done

final_count=0
for _ in {1..20}; do
  sleep 0.05
  final_count=$(normal_window_count)
  [[ "$final_count" == 1 ]] || fail "repeated activation created another primary window"
done

echo "single-window activation: passed three secondary activations with one primary window"
