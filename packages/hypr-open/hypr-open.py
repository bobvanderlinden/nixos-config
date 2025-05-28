import argparse
import json
import os
import subprocess

parser = argparse.ArgumentParser(
    prog="hypr-open",
    description="Open application in current workspace",
)

parser.add_argument("--window-class",
                    required=True,
                    type=str,
                    help="Window class",
                    )
parser.add_argument(
    "--new-window-argument",
    type=str,
    help="Argument to add when opening a new window"
)
parser.add_argument(
    "command",
    nargs="*",
    type=str,
    help="Command to run"
)
args = parser.parse_args()


def exec(cmd):
    stdout, stderr = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, shell=True
    ).communicate()
    return stdout.decode("utf-8").strip()


active_workspace = json.loads(exec("hyprctl -j activeworkspace"))

active_workspace_id = active_workspace["id"]

clients = json.loads(exec("hyprctl -j clients"))

matching_clients = sorted((
    client
    for client in clients
    if "class" in client
    if client["workspace"]["id"] == active_workspace_id
    if client["class"] == args.window_class
), key=lambda client: client["focusHistoryID"])

command_program = args.command[0]
command_args = args.command[1:]

match matching_clients:
    case []:
        os.execvp(command_program, [
            command_program,
            args.new_window_argument,
            *command_args
        ])
    case [{"address": str(address)}, *_]:
        exec(f'hyprctl dispatch focuswindow address:{address}')
        os.execvp(command_program, [command_program, *command_args])
    case _:
        raise Exception("unreachable")
