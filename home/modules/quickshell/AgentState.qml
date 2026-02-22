pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Singleton that tracks live OpenCode agent sessions via a Unix socket.
//
// The OpenCode session-status plugin connects to a SocketServer at:
//   /run/user/<uid>/opencode-sessions.sock
//
// Each connected client represents one live OpenCode instance (one process).
// The client sends newline-delimited JSON messages:
//   { type, sessionId, windowAddress, state, title }
// type is "update" or "remove".
//
// One entry per connected socket is exposed in `sessions` — the most active
// state across all sessions on that socket is used (busy > retry > idle).
// When a client disconnects its entry is removed immediately.
Singleton {
    id: root

    // One entry per connected OpenCode process:
    // [{ windowAddress, state, title }, ...]
    // state is the "most active" across all sessions on that connection.
    property var sessions: []

    // Internal: socketId (sequential int) → { windowAddress, sessionStates: { sessionId → state }, sessionTitles: { sessionId → title } }
    property var connectionMap: ({})
    property int nextSocketId: 0

    SocketServer {
        id: server
        active: true
        path: "/run/user/" + (Quickshell.env("UID") || "1000") + "/opencode-sessions.sock"

        onActiveChanged: {
            if (active) {
                root.connectionMap = {};
                root.sessions = [];
            }
        }

        handler: Socket {
            id: clientSocket

            property int socketId: -1

            Component.onCompleted: {
                socketId = root.nextSocketId++;
                root.connectionMap[socketId] = {
                    windowAddress: null,
                    sessionStates: {},
                    sessionTitles: {},
                };
                root.rebuild();
            }

            onConnectedChanged: {
                if (!connected) {
                    delete root.connectionMap[socketId];
                    root.rebuild();
                }
            }

            parser: SplitParser {
                onRead: line => {
                    const trimmed = line.trim();
                    if (trimmed === "") return;
                    try {
                        const obj = JSON.parse(trimmed);
                        if (!obj.sessionId) return;

                        const conn = root.connectionMap[clientSocket.socketId];
                        if (!conn) return;

                        if (obj.type === "remove") {
                            delete conn.sessionStates[obj.sessionId];
                            delete conn.sessionTitles[obj.sessionId];
                        } else {
                            conn.windowAddress = obj.windowAddress ?? conn.windowAddress;
                            conn.sessionStates[obj.sessionId] = obj.state ?? "idle";
                            conn.sessionTitles[obj.sessionId] = obj.title ?? "";
                        }

                        root.rebuild();
                    } catch (error) {
                        // Ignore malformed JSON lines
                    }
                }
            }
        }
    }

    // Priority: busy > retry > idle
    function dominantState(states) {
        const values = Object.values(states);
        if (values.includes("busy"))  return "busy";
        if (values.includes("retry")) return "retry";
        return "idle";
    }

    // Most recently active title (first non-empty)
    function dominantTitle(titles) {
        return Object.values(titles).find(t => t !== "") ?? "";
    }

    function rebuild() {
        root.sessions = Object.values(root.connectionMap).map(conn => ({
            windowAddress: conn.windowAddress,
            state:         root.dominantState(conn.sessionStates),
            title:         root.dominantTitle(conn.sessionTitles),
        }));
    }
}
