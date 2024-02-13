#!/usr/bin/env python3
import subprocess
import json
import os
import argparse

parser = argparse.ArgumentParser(
    prog="sway-open",
    description="Open application in current workspace",
)

parser.add_argument("--app_id",
                    required=True,
                    type=str,
                    help="Sway Application ID"
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


tree = json.loads(exec("swaymsg -t get_tree --raw"))


def get_nodes(type, parent):
    def get_focus_index(node):
        return (
            parent["focus"].index(
                node["id"]) if node["id"] in parent["focus"] else 9999
        )

    return sorted(
        [
            node
            for node in parent["nodes"]
            if node["type"] == type
        ],
        key=get_focus_index
    )


def get_nodes_recursive(type, parent):
    for node in get_nodes(type, parent):
        yield node
        yield from get_nodes_recursive(type, node)


apps = [
    app
    for output in get_nodes("output", tree)
    for workspace in get_nodes("workspace", output)[:1]
    for app in get_nodes_recursive("con", workspace)
    if "app_id" in app
    if app["app_id"] == args.app_id
]

program = args.command[0]
command_args = args.command[1:]

match apps:
    case [app, *_]:
        exec(f'swaymsg [con_id={app["id"]}] focus')
        os.execvp(program, [program, *command_args])
    case []:
        os.execvp(program, [program, args.new_window_argument, *command_args])
    case _:
        raise Exception("unreachable")
