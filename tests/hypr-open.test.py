import json
from pathlib import Path
import runpy
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "packages/hypr-open/hypr-open.py"


def workspace(address, name=None, workspace_type="normal", numbered_id=None):
    result = {
        "address": address,
        "name": name if name is not None else address,
        "type": workspace_type,
    }
    if numbered_id is not None:
        result["id"] = numbered_id
    return result


def client(address, client_workspace, focus_history=0):
    return {
        "address": address,
        "workspace": client_workspace,
        "class": "chromium-browser",
        "focusHistoryID": focus_history,
    }


class HyprOpenTests(unittest.TestCase):
    def run_wrapper(self, active_workspace, snapshots, monitors=None, arguments=None):
        client_snapshots = iter(snapshots)

        def command_output(command, **options):
            if isinstance(command, list):
                return unittest.mock.Mock()
            if command == "hyprctl -j activeworkspace":
                result = active_workspace
            elif command == "hyprctl -j monitors":
                result = monitors
            elif command == "hyprctl -j clients":
                result = next(client_snapshots)
            else:
                self.fail(f"Unexpected command: {command}")
            process = unittest.mock.Mock()
            process.communicate.return_value = (json.dumps(result).encode(), None)
            return process

        with (
            patch("sys.argv", [
                str(SCRIPT), "--window-class", "chromium-browser",
                "--new-window-argument=--new-window", "--", "browser",
                *(arguments or []),
            ]),
            patch("subprocess.Popen", side_effect=command_output) as spawn,
            patch("subprocess.run") as dispatch,
            patch("os.execvp") as execute,
        ):
            # Real execvp never returns. Stop execution after recording its call.
            execute.side_effect = SystemExit
            try:
                runpy.run_path(str(SCRIPT), run_name="__main__")
            except SystemExit:
                pass
            return spawn, dispatch, execute

    def test_special_client_does_not_break_numbered_workspace_matching(self):
        target = workspace("2", numbered_id=2)
        clients = [
            client("0x1", workspace("special:slack", workspace_type="special")),
            client("0x2", target, focus_history=2),
            client("0x3", target, focus_history=0),
            client("0x4", workspace("1", numbered_id=1)),
        ]
        _, dispatch, execute = self.run_wrapper(target, [clients])
        dispatch.assert_called_once_with([
            "hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:0x3" })',
        ], check=False)
        execute.assert_called_once_with("browser", ["browser"])

    def test_named_workspace_matches_address_not_display_name(self):
        target = workspace("work", name="Renamed")
        clients = [
            client("0x1", workspace("other", name="Renamed")),
            client("0x2", target),
        ]
        _, dispatch, _ = self.run_wrapper(target, [clients])
        self.assertIn("address:0x2", dispatch.call_args.args[0][2])

    def test_special_workspace_uses_focused_monitor_normal_workspace(self):
        target = workspace("work")
        special = workspace("special:term", name="Terminal", workspace_type="special")
        monitors = [
            {"focused": False, "activeWorkspace": workspace("other")},
            {"focused": True, "activeWorkspace": target},
        ]
        _, dispatch, _ = self.run_wrapper(
            special, [[client("0x1", special), client("0x2", target)]], monitors,
        )
        self.assertIn("address:0x2", dispatch.call_args.args[0][2])

    def test_special_workspace_without_focused_monitor_has_no_id(self):
        target = workspace("special:term", workspace_type="special")
        _, dispatch, _ = self.run_wrapper(target, [[client("0x1", target)]], [])
        self.assertIn("address:0x1", dispatch.call_args.args[0][2])

    def test_new_window_moves_to_address_not_renamed_display_name(self):
        target = workspace("2", name="Renamed", numbered_id=2)
        existing = client("0x1", workspace("special:slack", workspace_type="special"))
        created = client("0x2", workspace("1", numbered_id=1))

        spawn, dispatch, _ = self.run_wrapper(
            target, [[existing], [existing, created]],
        )
        spawn.assert_any_call(["browser", "--new-window"])
        move_command = dispatch.call_args_list[0].args[0][2]
        self.assertIn('workspace = "2"', move_command)
        self.assertNotIn("Renamed", move_command)

    def test_flags_only_command_with_special_clients(self):
        target = workspace("2", numbered_id=2)
        _, dispatch, execute = self.run_wrapper(
            target,
            [[client("0x1", workspace("special:slack", workspace_type="special"))]],
            arguments=["--new-window"],
        )
        dispatch.assert_not_called()
        execute.assert_called_once_with("browser", ["browser", "--new-window"])


if __name__ == "__main__":
    unittest.main()
