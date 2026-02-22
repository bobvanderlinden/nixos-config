pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Singleton that tracks live OpenCode agent sessions via a Unix socket.
//
// The OpenCode session-status plugin connects to a SocketServer at:
//   /run/user/<uid>/opencode-sessions.sock
//
// Each connected client represents one live OpenCode instance.
// The client sends newline-delimited JSON messages:
//   { sessionId, windowAddress, state, title }
// state is one of: "idle", "busy", "retry"
//
// When a client disconnects, its session is removed immediately.
Singleton {
    id: root

    // List of session objects: [{ sessionId, windowAddress, state, title }, ...]
    property var sessions: []

    // Internal map: sessionId → session object
    property var sessionMap: ({})

    SocketServer {
        id: server
        active: true
        path: "/run/user/" + (Quickshell.env("UID") || "1000") + "/opencode-sessions.sock"

        // The handler is instantiated once per incoming connection.
        // Each Socket instance represents one live OpenCode session.
        handler: Socket {
            // Track which sessionId this socket belongs to
            property string currentSessionId: ""

            onConnectedChanged: {
                if (!connected && currentSessionId !== "") {
                    const map = root.sessionMap;
                    delete map[currentSessionId];
                    root.sessionMap = map;
                    root.sessions = Object.values(map);
                }
            }

            parser: SplitParser {
                onRead: line => {
                    const trimmed = line.trim();
                    if (trimmed === "") return;
                    try {
                        const obj = JSON.parse(trimmed);
                        if (!obj.sessionId) return;

                        parent.currentSessionId = obj.sessionId;
                        const map = root.sessionMap;
                        map[obj.sessionId] = {
                            sessionId:     obj.sessionId,
                            windowAddress: obj.windowAddress ?? null,
                            state:         obj.state ?? "idle",
                            title:         obj.title ?? "",
                        };
                        root.sessionMap = map;
                        root.sessions = Object.values(map);
                    } catch (error) {
                        // Ignore malformed JSON lines
                    }
                }
            }
        }
    }
}
