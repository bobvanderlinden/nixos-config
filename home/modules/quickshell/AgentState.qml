pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Singleton that tracks live agent state by subscribing to statebus.
//
// statebus runs as a systemd user service and listens on two sockets:
//   statebus-pub.sock  — publishers (e.g. opencode session-status plugin) write state
//   statebus-sub.sock  — subscribers receive a full state replay on connect, then live updates
//
// Each message is a newline-delimited JSON object:
//   { type: "update", key, windowAddress, state, title }
//   { type: "remove", key }
//
// One entry per key is exposed in `sessions`.
// When the statebus daemon restarts, state is cleared and re-replayed on reconnect.
Singleton {
    id: root

    // One entry per published key:
    // [{ windowAddress, state, title }, ...]
    property var sessions: []

    // Internal: key → { windowAddress, state, title }
    property var sessionMap: ({})

    Socket {
        id: socket
        path: "/run/user/" + (Quickshell.env("UID") || "1000") + "/statebus-sub.sock"
        connected: true

        onConnectedChanged: {
            if (!connected) {
                root.sessionMap = {};
                root.sessions = [];
            }
        }

        parser: SplitParser {
            onRead: line => {
                const trimmed = line.trim();
                if (trimmed === "") return;
                try {
                    const obj = JSON.parse(trimmed);
                    if (!obj.key) return;

                    if (obj.type === "remove") {
                        delete root.sessionMap[obj.key];
                    } else if (obj.type === "update") {
                        root.sessionMap[obj.key] = {
                            windowAddress: obj.windowAddress ?? null,
                            state:         obj.state ?? "idle",
                            title:         obj.title ?? "",
                        };
                    }

                    root.sessions = Object.values(root.sessionMap);
                } catch (error) {
                    // Ignore malformed JSON lines
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: !socket.connected
        onTriggered: socket.connected = true
    }
}
