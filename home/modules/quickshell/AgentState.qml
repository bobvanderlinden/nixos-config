pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Singleton that tracks OpenCode agent sessions via JSON files in
// /run/user/<uid>/agent-sessions/<sessionId>.json
//
// Each file contains:
//   { sessionId, windowAddress, workspaceId, state, title }
// where state is "active" or "idle".
//
// Files with state="active" older than 30 s are treated as stale
// (handles OpenCode exiting without firing session.idle).
Singleton {
    id: root

    // List of session objects: [{ sessionId, windowAddress, workspaceId, state, title }, ...]
    property var sessions: []

    // Convenience map: workspaceId -> true for workspaces with an active (non-stale) agent.
    property var activeWorkspaces: ({})

    // Active session files are touched on every agent event (tool call etc.).
    // If no event fires for 5 minutes, treat the file as stale (agent crashed).
    readonly property int staleThresholdMs: 300000

    Process {
        id: watcher
        // Output one line per file: "<mtime_epoch_float> <json_content>"
        // Using awk to join mtime and content on a single line.
        command: ["sh", "-c",
            "dir=/run/user/$(id -u)/agent-sessions; " +
            "mkdir -p \"$dir\"; " +
            "find \"$dir\" -maxdepth 1 -name '*.json' | " +
            "  while read -r f; do " +
            "    mtime=$(stat -c '%Y' \"$f\"); " +
            "    content=$(cat \"$f\"); " +
            "    echo \"$mtime $content\"; " +
            "  done"]
        running: true

        property string buf: ""

        stdout: SplitParser {
            onRead: data => watcher.buf += data
        }

        onExited: {
            const lines = watcher.buf.trim().split("\n").filter(l => l !== "");
            watcher.buf = "";

            const nowMs = Date.now();
            const newSessions = [];
            const newActive = {};

            for (const line of lines) {
                const spaceIdx = line.indexOf(" ");
                if (spaceIdx < 0) continue;
                const mtimeMs = parseInt(line.substring(0, spaceIdx)) * 1000;
                const jsonStr = line.substring(spaceIdx + 1).trim();
                if (!jsonStr) continue;

                try {
                    const obj = JSON.parse(jsonStr);
                    const isStale = (obj.state === "active") && (nowMs - mtimeMs > root.staleThresholdMs);
                    if (isStale) continue;

                    newSessions.push({
                        sessionId:     obj.sessionId     ?? "",
                        windowAddress: obj.windowAddress ?? null,
                        workspaceId:   obj.workspaceId   ?? null,
                        state:         obj.state         ?? "idle",
                        title:         obj.title         ?? "",
                    });

                    if (obj.state === "active" && obj.workspaceId != null) {
                        newActive[obj.workspaceId] = true;
                    }
                } catch (e) { }
            }

            root.sessions = newSessions;
            root.activeWorkspaces = newActive;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: watcher.running = true
    }
}
