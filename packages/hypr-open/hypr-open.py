import argparse
import json
import os
import subprocess
import sys
import time

parser = argparse.ArgumentParser(
    prog="hypr-open",
    description="Open application in current workspace",
)

parser.add_argument(
    "--window-class",
    required=True,
    type=str,
    help="Window class",
)
parser.add_argument(
    "--new-window-argument",
    type=str,
    help="Argument to add when opening a new window",
)
parser.add_argument(
    "--window-title-suffix",
    type=str,
    help="Window title suffix to use as a fallback match",
)
parser.add_argument(
    "command",
    nargs="*",
    type=str,
    help="Command to run",
)
args = parser.parse_args()


def execvp(file, args):
    os.execvp(file, args)
    print("Unexpected return from execvp!", file=sys.stderr)
    exit(1)


def exec(cmd):
    stdout, stderr = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, shell=True
    ).communicate()
    return stdout.decode("utf-8").strip()


def lua_string(value):
    return value.replace("\\", "\\\\").replace('"', '\\"')


def load_clients():
    return json.loads(exec("hyprctl -j clients"))


def load_monitors():
    return json.loads(exec("hyprctl -j monitors"))


def is_special_workspace(workspace):
    return workspace["name"].startswith("special:")


def current_workspace():
    active_workspace = json.loads(exec("hyprctl -j activeworkspace"))
    if not is_special_workspace(active_workspace):
        return active_workspace

    focused_monitors = [
        monitor
        for monitor in load_monitors()
        if monitor.get("focused", False)
    ]
    if len(focused_monitors) == 0:
        return active_workspace

    monitor_workspace = focused_monitors[0]["activeWorkspace"]
    if is_special_workspace(monitor_workspace):
        return active_workspace

    return monitor_workspace


def dispatch(command):
    subprocess.run(["hyprctl", "dispatch", command], check=False)


def move_to_workspace(address, workspace):
    move_command = (
        'hl.dsp.window.move({ '
        f'workspace = "{lua_string(workspace)}", '
        f'window = "address:{lua_string(address)}", '
        "silent = true })"
    )
    dispatch(move_command)


def matches_client(client):
    if client.get("class") == args.window_class:
        return True

    if args.window_title_suffix is None:
        return False

    return client.get("title", "").endswith(args.window_title_suffix)


target_workspace = current_workspace()

target_workspace_id = target_workspace["id"]

clients = load_clients()

matching_clients = sorted(
    (
        client
        for client in clients
        if client["workspace"]["id"] == target_workspace_id
        if matches_client(client)
    ),
    key=lambda client: client["focusHistoryID"],
)

command_program = args.command[0]
command_args = args.command[1:]


def wait_for_new_client(before_addresses):
    deadline = time.monotonic() + 10

    while time.monotonic() < deadline:
        for client in load_clients():
            if not matches_client(client):
                continue
            if client["address"] in before_addresses:
                continue
            return client

        time.sleep(0.1)

    return None


def exec_new_window():
    before_addresses = {
        client["address"]
        for client in clients
        if "address" in client
    }
    new_window_args = (
        [args.new_window_argument]
        if args.new_window_argument is not None
        else []
    )

    subprocess.Popen(
        [
            command_program,
            *new_window_args,
            *command_args,
        ],
    )

    new_client = wait_for_new_client(before_addresses)
    if new_client is None:
        return

    move_to_workspace(new_client["address"], target_workspace["name"])
    new_client_address = lua_string(new_client["address"])
    focus_command = (
        f'hl.dsp.focus({{ window = "address:{new_client_address}" }})'
    )
    dispatch(focus_command)


only_flags = len(command_args) > 0 and all(
    arg.startswith("-")
    for arg in command_args
)

if only_flags:
    execvp(
        command_program,
        [command_program, *command_args],
    )

match matching_clients:
    case []:
        exec_new_window()
    case [{"address": str(address)}, *_]:
        focus_command = f'hl.dsp.focus({{ window = "address:{address}" }})'
        dispatch(focus_command)
        execvp(
            command_program,
            [
                command_program,
                *command_args,
            ],
        )
    case _:
        raise Exception("unreachable")
