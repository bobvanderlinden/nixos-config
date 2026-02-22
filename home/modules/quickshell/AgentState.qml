pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Singleton that tracks which Hyprland workspace IDs have an active agent.
// The OpenCode plugin writes files to /run/user/<uid>/agent-workspaces/<id>
// when the session is active, and removes them when the session is idle.
//
// Staleness: files older than 30 s without an update are treated as stale
// (handles cases where OpenCode exited without firing session.idle).
Singleton {
    id: root

    // Set of workspace IDs with an active agent: { <id>: true, ... }
    property var activeWorkspaces: ({})

    readonly property int staleThresholdMs: 30000

    Process {
        id: watcher
        // List files with their modification time in seconds since epoch.
        command: ["sh", "-c",
            "mkdir -p /run/user/$(id -u)/agent-workspaces && " +
            "find /run/user/$(id -u)/agent-workspaces -maxdepth 1 -type f " +
            "  -printf '%f %T@\\n' 2>/dev/null || true"]
        running: true

        property string buf: ""

        stdout: SplitParser {
            onRead: data => watcher.buf += data
        }

        onExited: {
            const lines = watcher.buf.trim().split("\n").filter(l => l !== "");
            const nowMs = Date.now();
            const ids = {};
            for (const l of lines) {
                const parts = l.trim().split(" ");
                if (parts.length < 2) continue;
                const n = parseInt(parts[0]);
                const mtimeMs = parseFloat(parts[1]) * 1000;
                if (isNaN(n)) continue;
                // Only mark active if the file was touched recently.
                if (nowMs - mtimeMs < root.staleThresholdMs) {
                    ids[n] = true;
                }
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
