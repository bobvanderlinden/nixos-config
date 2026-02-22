pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Singleton that tracks OpenCode agent sessions in real-time.
//
// The OpenCode session-status plugin writes JSON files to:
//   /run/user/<uid>/agent-sessions/<sessionId>.json
// Content: { sessionId, windowAddress, state, title }
// state mirrors SessionStatus.type: "idle", "busy", or "retry".
//
// Two processes:
//   scanner  — reads all JSON files on demand (triggered by watcher or on start)
//   watcher  — long-running inotifywait; fires scanner on any file change
//
// Staleness: non-idle files not touched for 5 minutes are treated as idle
// (handles OpenCode exiting without firing a final session.status).
Singleton {
    id: root

    // List of session objects: [{ sessionId, windowAddress, state, title }, ...]
    property var sessions: []

    // Non-idle files not updated within this window are treated as stale/idle.
    readonly property int staleMs: 5 * 60 * 1000

    // ── Scanner: reads all JSON files and updates state ───────────────────────

    Process {
        id: scanner
        // Output one line per file: "<mtime_epoch_seconds> <json>"
        command: ["sh", "-c",
            "dir=/run/user/$(id -u)/agent-sessions; " +
            "mkdir -p \"$dir\"; " +
            "find \"$dir\" -maxdepth 1 -name '*.json' | " +
            "  while read -r f; do " +
            "    printf '%s ' \"$(stat -c '%Y' \"$f\")\"; cat \"$f\"; echo; " +
            "  done"]
        running: true

        property string buf: ""

        stdout: SplitParser {
            onRead: data => scanner.buf += data + "\n"
        }

        onExited: {
            const lines = scanner.buf.trim().split("\n").filter(l => l !== "");
            scanner.buf = "";

            const nowMs = Date.now();
            const newSessions = [];

            for (const line of lines) {
                try {
                    const spaceIdx = line.indexOf(" ");
                    if (spaceIdx < 0) continue;
                    const mtimeMs = parseInt(line.substring(0, spaceIdx)) * 1000;
                    const obj = JSON.parse(line.substring(spaceIdx + 1));

                    // Treat non-idle files not touched in 5 min as idle.
                    const effectiveState = (obj.state !== "idle" && nowMs - mtimeMs > root.staleMs)
                        ? "idle"
                        : (obj.state ?? "idle");

                    newSessions.push({
                        sessionId:     obj.sessionId     ?? "",
                        windowAddress: obj.windowAddress ?? null,
                        state:         effectiveState,
                        title:         obj.title         ?? "",
                    });
                } catch (e) { }
            }

            root.sessions = newSessions;
        }
    }

    // ── Watcher: inotifywait fires scanner on any change ─────────────────────

    Process {
        id: watcher
        command: ["sh", "-c",
            "mkdir -p /run/user/$(id -u)/agent-sessions && " +
            "exec inotifywait -m -e close_write -e moved_to -e delete " +
            "  --format '%e' " +
            "  /run/user/$(id -u)/agent-sessions"]
        running: true

        stdout: SplitParser {
            onRead: _ => scanner.running = true
        }
    }

    // ── Fallback poll: re-scan every minute to catch staleness transitions ────

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: scanner.running = true
    }
}
