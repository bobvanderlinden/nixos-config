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
//   { type, sessionId, windowAddress, state, title }
// type is "update" or "remove".
//
// When a client disconnects, all its sessions are removed immediately.
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

        // One Socket instance is created per incoming connection.
        handler: Socket {
            // Track which sessionIds this socket has published
            property var ownedSessionIds: []

            onConnectedChanged: {
                if (!connected) {
                    // Remove all sessions owned by this socket
                    const map = root.sessionMap;
                    for (const id of ownedSessionIds) {
                        delete map[id];
                    }
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

                        const map = root.sessionMap;

                        if (obj.type === "remove") {
                            delete map[obj.sessionId];
                            const idx = parent.ownedSessionIds.indexOf(obj.sessionId);
                            if (idx >= 0) parent.ownedSessionIds.splice(idx, 1);
                        } else {
                            // "update" or any other type — upsert
                            if (!parent.ownedSessionIds.includes(obj.sessionId))
                                parent.ownedSessionIds.push(obj.sessionId);

                            map[obj.sessionId] = {
                                sessionId:     obj.sessionId,
                                windowAddress: obj.windowAddress ?? null,
                                state:         obj.state ?? "idle",
                                title:         obj.title ?? "",
                            };
                        }

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
