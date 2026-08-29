#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "dynamic command enablement: $*" >&2
  exit 1
}

[[ $# -eq 1 ]] || fail "usage: $0 /path/to/awesomux"
app_bin=$1
[[ -x "$app_bin" ]] || fail "application executable is missing"
command -v gdbus >/dev/null || fail "gdbus is required"
command -v python3 >/dev/null || fail "python3 is required"

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

application=com.interactivebuffoonery.awesomux.activationprobe
object_path=/com/interactivebuffoonery/awesomux/activationprobe
snapshot="$XDG_STATE_HOME/awesomux/profiles/default/session.json"

activate() {
  gdbus call --session --dest "$application" --object-path "$object_path" \
    --method org.gtk.Actions.Activate "$1" '[]' '{}' >/dev/null
}

action_enabled() {
  gdbus call --session --dest "$application" --object-path "$object_path" \
    --method org.gtk.Actions.Describe "$1" | grep -q '((true,'
}

snapshot_state() {
  python3 - "$snapshot" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(1)
value = json.loads(path.read_text())
workspaces = [workspace for group in value["groups"] for workspace in group["workspaces"]]
selected = next((item for item in workspaces if item["id"] == value.get("selectedWorkspaceID")), None)
if selected is None:
    print(len(workspaces), 0, 0)
    raise SystemExit(0)

def pane_ids(layout):
    if "pane" in layout:
        return [layout["pane"]["_0"]["id"]]
    split = layout["split"]
    return pane_ids(split["first"]) + pane_ids(split["second"])

panes = pane_ids(selected["layout"])
focused_is_second = len(panes) > 1 and selected["focusedPaneID"] == panes[1]
print(len(workspaces), len(panes), int(focused_is_second))
PY
}

wait_for_state() {
  local expected=$1 actual=""
  for _ in {1..100}; do
    kill -0 "$app_pid" 2>/dev/null || fail "application exited during probe"
    actual=$(snapshot_state 2>/dev/null || true)
    [[ "$actual" == "$expected" ]] && return
    sleep 0.05
  done
  fail "timed out waiting for state $expected"
}

"$app_bin" >"$probe_root/app.stdout" 2>"$probe_root/app.stderr" &
app_pid=$!
for _ in {1..100}; do
  kill -0 "$app_pid" 2>/dev/null || fail "application exited during launch"
  gdbus introspect --session --dest "$application" --object-path "$object_path" \
    >/dev/null 2>&1 && break
  sleep 0.05
done

action_enabled newWorkspaceInCurrentDirectory &&
  fail "New Workspace in Current Directory was enabled without a selected workspace"
activate newWorkspace
wait_for_state "1 1 0"
action_enabled newWorkspaceInCurrentDirectory ||
  fail "New Workspace in Current Directory did not enable with a selected workspace"
action_enabled focusPane2 && fail "Focus Pane 2 was enabled for one pane"

activate splitRight
wait_for_state "1 2 1"
action_enabled focusPane2 || fail "Focus Pane 2 did not enable after split"

activate newWorkspace
wait_for_state "2 1 0"
action_enabled focusPane2 && fail "Focus Pane 2 stayed enabled on one-pane workspace"

activate jumpWorkspace1
wait_for_state "2 2 1"
action_enabled focusPane2 || fail "Focus Pane 2 did not refresh after workspace switch"
activate focusPane2
wait_for_state "2 2 1"

echo "dynamic command enablement: passed one/two-pane workspace transitions and pane-2 routing"
