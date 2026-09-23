#!/usr/bin/env python3
"""Exercise command-palette focus and activation in a real Omarchy GTK session.

Run after building the debug app. This uses a temporary profile and only
reports structural AT-SPI state; it never prints workspace names or paths.
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi


REPO = Path(__file__).resolve().parent.parent
APP = REPO / "swift-gtk/.build/debug/awesomux"
APP_ID = "com.interactivebuffoonery.awesomux.activationprobe"
OBJECT_PATH = "/com/interactivebuffoonery/awesomux/activationprobe"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def wait_for(predicate, message, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(0.05)
    raise RuntimeError(message)


def descendants(node):
    yield node
    try:
        for index in range(node.get_child_count()):
            yield from descendants(node.get_child_at_index(index))
    except Exception:
        return


def app_accessible(pid):
    desktop = Atspi.get_desktop(0)
    for index in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(index)
        if app.get_process_id() == pid:
            return app
    return None


def palette_nodes(pid):
    app = app_accessible(pid)
    if app is None:
        return None
    nodes = list(descendants(app))
    search = next((node for node in nodes if node.get_name() == "Command palette search"), None)
    if search is None:
        return None
    rows = [node for node in nodes if node.get_name().startswith(("Workspace:", "Action:"))]
    return search, rows


def selected(rows):
    return [index for index, row in enumerate(rows)
            if row.get_state_set().contains(Atspi.StateType.SELECTED)]


def focused_nodes(pid):
    app = app_accessible(pid)
    if app is None:
        return []
    return [node for node in descendants(app)
            if node.get_state_set().contains(Atspi.StateType.FOCUSED)]


def hyprland_json(env, command):
    return json.loads(subprocess.check_output(
        ["hyprctl", "-j", command], env=env, stderr=subprocess.DEVNULL
    ))


def move_cursor(env, x, y):
    subprocess.run(["hyprctl", "eval", f"hl.dispatch(hl.dsp.cursor.move({{x={x},y={y}}}))"],
                   env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def focus_app_window(env, pid):
    clients = hyprland_json(env, "clients")
    window = next((client for client in clients
                   if client.get("pid") == pid and client.get("class") == APP_ID), None)
    require(window is not None, "app window missing in Hyprland")
    previous_cursor = hyprland_json(env, "cursorpos")
    x = window["at"][0] + window["size"][0] // 2
    y = window["at"][1] + window["size"][1] // 2
    move_cursor(env, x, y)
    subprocess.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({window=\"address:"
                    + window["address"] + "\"}))"], env=env, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    wait_for(lambda: hyprland_json(env, "activewindow").get("address") == window["address"],
             "Hyprland did not focus the app window")
    return previous_cursor


def shortcut_sequence(env, keys, pause=0.08):
    # Hyprland 0.56 can send a key to this window without taking focus from
    # another app in Sarah's live desktop session.
    expression = "; ".join(
        'hl.dispatch(hl.dsp.send_shortcut({window="class:' + APP_ID
        + '",mods="' + mods + '",key="' + key + '"}))'
        for key, mods in keys
    )
    subprocess.run(["hyprctl", "eval", expression], env=env, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if pause:
        time.sleep(pause)


def shortcut(env, key, mods="", pause=0.08):
    shortcut_sequence(env, [(key, mods)], pause=pause)


def activate_new_workspace(env):
    subprocess.run([
        "gdbus", "call", "--session", "--dest", APP_ID,
        "--object-path", OBJECT_PATH, "--method", "org.gtk.Actions.Activate",
        "newWorkspace", "[]", "{}",
    ], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def snapshot(path):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def workspaces(value):
    return [workspace for group in value["groups"] for workspace in group["workspaces"]]


def main():
    require(APP.is_file(), "build the debug app first")
    require("ID=omarchy" in Path("/etc/os-release").read_text().splitlines(),
            "this check requires the Omarchy target host")
    user_environment = subprocess.check_output(
        ["systemctl", "--user", "show-environment"], text=True
    )
    session = dict(line.split("=", 1) for line in user_environment.splitlines() if "=" in line)
    require(session.get("WAYLAND_DISPLAY") and session.get("HYPRLAND_INSTANCE_SIGNATURE"),
            "a live Omarchy/Hyprland Wayland session is required")
    env = os.environ.copy()
    env.update({key: session[key] for key in
                ("XDG_RUNTIME_DIR", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE")})
    env.update({
        "GDK_BACKEND": "wayland",
        "AWESOMUX_SINGLE_WINDOW_PROBE": "1",
        "AWESOMUX_DEVELOPMENT": "1",
        "GHOSTTY_RESOURCES_DIR": str(REPO / ".build/ghostty-prefix/share/ghostty"),
        "LD_LIBRARY_PATH": ":".join((
            str(REPO / ".build/link-lib"),
            str(REPO / ".build/ghostty-shim/lib"),
            str(REPO / ".build/ghostty-prefix/lib"),
            str(REPO / ".build/toolchains/compat/usr/lib/x86_64-linux-gnu"),
            env.get("LD_LIBRARY_PATH", ""),
        )),
    })
    with tempfile.TemporaryDirectory(prefix="awesomux-palette-") as profile:
        env["XDG_STATE_HOME"] = str(Path(profile) / "state")
        env["XDG_CONFIG_HOME"] = str(Path(profile) / "config")
        state_path = Path(profile) / "state/awesomux/profiles/default/session.json"
        process = subprocess.Popen([str(APP)], env=env,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        previous_cursor = None
        try:
            wait_for(lambda: app_accessible(process.pid), "app did not appear in AT-SPI")
            for count in (1, 2):
                activate_new_workspace(env)
                wait_for(lambda: (value := snapshot(state_path)) and
                         len(workspaces(value)) == count, "workspace setup failed")

            previous_cursor = focus_app_window(env, process.pid)
            initial_focus = wait_for(lambda: focused_nodes(process.pid),
                                     "app had no focused widget before palette")
            require(len(initial_focus) == 1, "app had ambiguous focus before palette")
            shortcut(env, "K", "CTRL")
            search, rows = wait_for(lambda: palette_nodes(process.pid), "palette did not open")
            require(len(rows) >= 2, "palette needs multiple results")
            require(search.get_state_set().contains(Atspi.StateType.FOCUSABLE),
                    "search is not keyboard focusable")
            wait_for(lambda: search.get_state_set().contains(Atspi.StateType.FOCUSED),
                     "search did not gain actual focus")
            require(all(not row.get_state_set().contains(Atspi.StateType.FOCUSABLE)
                        for row in rows), "a result can take Tab focus")
            shortcut(env, "Down")
            require(selected(palette_nodes(process.pid)[1]) == [0], "Down did not select first")
            for key, mods in (("Tab", ""), ("Tab", ""), ("Tab", "SHIFT")):
                shortcut(env, key, mods)
            require(selected(palette_nodes(process.pid)[1]) == [0],
                    "Tab changed the active result")
            shortcut(env, "Return")
            wait_for(lambda: (value := snapshot(state_path)) and
                     value["selectedWorkspaceID"] == workspaces(value)[0]["id"],
                     "Return did not activate the selected first workspace")

            shortcut(env, "K", "CTRL")
            wait_for(lambda: palette_nodes(process.pid), "palette did not reopen")
            shortcut(env, "Down")
            shortcut(env, "Down")
            require(selected(palette_nodes(process.pid)[1]) == [1],
                    "second Down did not select second")
            shortcut(env, "Return")
            wait_for(lambda: (value := snapshot(state_path)) and
                     value["selectedWorkspaceID"] == workspaces(value)[1]["id"],
                     "Return did not activate the selected second workspace")

            shortcut(env, "K", "CTRL")
            _, rows = wait_for(lambda: palette_nodes(process.pid), "palette did not reopen")
            require(rows[0].get_action_iface().do_action(0), "row Click action failed")
            wait_for(lambda: (value := snapshot(state_path)) and
                     value["selectedWorkspaceID"] == workspaces(value)[0]["id"],
                     "clicked row did not activate")

            before_filter_focus = wait_for(lambda: focused_nodes(process.pid),
                                           "app lost focus before filter palette")
            require(len(before_filter_focus) == 1,
                    "app had ambiguous focus before filter palette")
            before_filter_focus_path = before_filter_focus[0].path

            shortcut(env, "K", "CTRL")
            search, _ = wait_for(lambda: palette_nodes(process.pid), "palette did not reopen")
            require(search.get_editable_text_iface().set_text_contents("> split"),
                    "actions-only filter failed")
            _, rows = wait_for(lambda: (nodes := palette_nodes(process.pid)) and
                               len(nodes[1]) == 2 and nodes, "actions-only results missing")
            require(all(row.get_name().startswith("Action:") for row in rows),
                    "workspace leaked into actions-only results")
            require(selected(rows) == [0], "filtered selection did not reset")
            shortcut(env, "Down")
            require(selected(palette_nodes(process.pid)[1]) == [1],
                    "filtered Down did not select second")

            require(search.get_editable_text_iface().set_text_contents("zzzxqnevermatch"),
                    "empty filter failed")
            wait_for(lambda: (nodes := palette_nodes(process.pid)) and
                     len(nodes[1]) == 0, "empty filter still has results")
            shortcut(env, "Return")
            require(palette_nodes(process.pid) is not None, "empty Return dismissed palette")
            shortcut(env, "Escape")
            wait_for(lambda: palette_nodes(process.pid) is None,
                     "Escape did not dismiss palette")
            try:
                wait_for(lambda: any(node.path == before_filter_focus_path
                                     for node in focused_nodes(process.pid)),
                         "Escape did not restore the previous widget's focus")
            except RuntimeError as error:
                roles = [node.get_role_name() for node in focused_nodes(process.pid)]
                raise RuntimeError(f"{error}; focused roles: {roles}") from error
            before_rapid_focus_path = focused_nodes(process.pid)[0].path
            shortcut(env, "K", "CTRL")
            wait_for(lambda: palette_nodes(process.pid), "palette did not reopen")
            shortcut(env, "Escape", pause=0)
            shortcut(env, "K", "CTRL")
            try:
                wait_for(lambda: palette_nodes(process.pid),
                         "rapid reopen did not create a new palette")
            except RuntimeError as error:
                active_app = hyprland_json(env, "activewindow").get("class") == APP_ID
                raise RuntimeError(f"{error}; app active={active_app}; "
                                   f"app alive={process.poll() is None}") from error
            time.sleep(0.3)
            require(palette_nodes(process.pid) is not None,
                    "old palette cleanup dismissed the new palette")
            shortcut(env, "Escape")
            wait_for(lambda: palette_nodes(process.pid) is None,
                     "second Escape did not dismiss palette")
            wait_for(lambda: any(node.path == before_rapid_focus_path
                                 for node in focused_nodes(process.pid)),
                     "rapid reopen did not restore the previous widget's focus")
            time.sleep(2)
            require(process.poll() is None, "app crashed after Escape")
            print("command-palette focus: passed on native Omarchy Wayland")
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
            if previous_cursor is not None:
                move_cursor(env, previous_cursor["x"], previous_cursor["y"])


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"command-palette focus: {error}", file=sys.stderr)
        sys.exit(1)
