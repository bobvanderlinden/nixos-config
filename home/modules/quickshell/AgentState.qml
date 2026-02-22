pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Singleton that tracks which Hyprland workspace IDs have an active agent.
// The OpenCode plugin writes files to /run/user/<uid>/agent-workspaces/<id>
// when the session is active, and removes them when the session is idle.
Singleton {
    id: root

    // Set of workspace IDs with an active agent: { <id>: true, ... }
    property var activeWorkspaces: ({})

    Process {
        id: watcher
        command: ["sh", "-c",
            "mkdir -p /run/user/$(id -u)/agent-workspaces && ls -1 /run/user/$(id -u)/agent-workspaces/ 2>/dev/null || true"]
        running: true

        property string buf: ""

        stdout: SplitParser {
            onRead: data => watcher.buf += data
        }

        onExited: {
            const lines = watcher.buf.trim().split("\n").filter(l => l !== "");
            const ids = {};
            for (const l of lines) {
                const n = parseInt(l);
                if (!isNaN(n)) ids[n] = true;
            }
            root.activeWorkspaces = ids;
            watcher.buf = "";
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: watcher.running = true
    }
}
