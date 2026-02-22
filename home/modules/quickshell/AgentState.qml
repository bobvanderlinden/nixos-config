pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Singleton that tracks OpenCode agent sessions in real-time.
//
// The OpenCode notify plugin writes JSON files to:
//   /run/user/<uid>/agent-sessions/<sessionId>.json
// Content: { sessionId, windowAddress, workspaceId, state, title }
// state is "active" or "idle".
//
// Two processes:
//   scanner  — reads all JSON files on demand (triggered by watcher or on start)
//   watcher  — long-running inotifywait; fires scanner on any file change
Singleton {
    id: root

    // List of session objects: [{ sessionId, windowAddress, workspaceId, state, title }, ...]
    property var sessions: []

    // Convenience map: workspaceId -> true for active sessions.
    property var activeWorkspaces: ({})

    readonly property string agentDir: "/run/user/" + Qt.platform.os + "/agent-sessions"

    // ── Scanner: reads all JSON files and updates state ───────────────────────

    Process {
        id: scanner
        command: ["sh", "-c",
            "dir=/run/user/$(id -u)/agent-sessions; " +
            "mkdir -p \"$dir\"; " +
            "find \"$dir\" -maxdepth 1 -name '*.json' | " +
            "  while read -r f; do cat \"$f\"; echo; done"]
        running: true  // run once on startup

        property string buf: ""

        stdout: SplitParser {
            onRead: data => scanner.buf += data
        }

        onExited: {
            const lines = scanner.buf.trim().split("\n").filter(l => l !== "");
            scanner.buf = "";

            const newSessions = [];
            const newActive = {};

            for (const line of lines) {
                try {
                    const obj = JSON.parse(line);
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

    // ── Watcher: inotifywait fires scanner on any change ─────────────────────

    Process {
        id: watcher
        // -m = monitor forever, -e = events to watch, --format = output format
        // We create the dir first so inotifywait doesn't fail if it doesn't exist yet.
        command: ["sh", "-c",
            "mkdir -p /run/user/$(id -u)/agent-sessions && " +
            "exec inotifywait -m -e close_write -e moved_to -e delete " +
            "  --format '%e' " +
            "  /run/user/$(id -u)/agent-sessions"]
        running: true

        stdout: SplitParser {
            onRead: _ => {
                // Any change → re-scan immediately
                scanner.running = true;
            }
        }
    }
}
