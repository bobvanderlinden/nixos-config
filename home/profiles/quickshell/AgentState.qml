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
//   { type: "update", key, windowAddress, state, agentStatus, title, label, cwd, sessionStatus, sessionDescription, todos }
//   { type: "remove", key }
//
// One entry per key is exposed in `sessions`.
// When the statebus daemon restarts, state is cleared and re-replayed on reconnect.
Singleton {
    id: root

    // One entry per published key:
    // [{ windowAddress, agentStatus, title, label, cwd, sessionStatus, sessionDescription, updatedAt, todos }, ...]
    property var sessions: []

    // Internal: key → { windowAddress, agentStatus, title, label, cwd, sessionStatus, sessionDescription, updatedAt, todos }
    property var sessionMap: ({})

    function isKnownState(state) {
        switch (state) {
            case "error":
            case "permission":
            case "question":
            case "waiting":
            case "busy":
            case "retry":
            case "working":
            case "done":
            case "idle":
                return true;
            default:
                return false;
        }
    }

    function displayStatus(session) {
        return session.sessionStatus ?? session.sessionState ?? session.agentStatus
            ?? session.agentState ?? session.state ?? "idle";
    }

    function colorState(session) {
        for (const state of [
            session.sessionStatus,
            session.sessionState,
            session.agentStatus,
            session.agentState,
            session.state,
        ]) {
            if (isKnownState(state)) return state;
        }
        return "idle";
    }

    function stateColor(state) {
        switch (state) {
            case "error":      return "#ff5555";
            case "permission": return "#f1fa8c";
            case "question":
            case "waiting":    return "#8be9fd";
            case "busy":
            case "retry":
            case "working":    return "#fab283";
            default:             return "#6272a4";
        }
    }

    function stateBgColor(state) {
        switch (state) {
            case "error":      return "#3d1a1a";
            case "permission": return "#3d3a1a";
            case "question":
            case "waiting":    return "#1a2d3a";
            case "busy":
            case "retry":
            case "working":    return "#3d2a1a";
            default:             return "#2d2d3f";
        }
    }

    function statePriority(state) {
        switch (state) {
            case "error":                         return 4;
            case "permission":
            case "question":
            case "waiting":                       return 3;
            case "busy":
            case "retry":
            case "working":                       return 2;
            default:                                return 1;
        }
    }

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
                            windowAddress:      obj.windowAddress ?? null,
                            // Preserve each schema version so consumers can select a
                            // supported state rather than stopping at an unknown value.
                            agentStatus:        obj.agentStatus ?? null,
                            agentState:         obj.agentState ?? null,
                            state:              obj.state ?? null,
                            title:              obj.title ?? "",
                            label:              obj.label ?? "",
                            cwd:                obj.cwd ?? "",
                            sessionStatus:      obj.sessionStatus ?? null,
                            sessionState:       obj.sessionState ?? null,
                            sessionDescription: obj.sessionDescription ?? obj.description ?? "",
                            description:        obj.description ?? "",
                            // A legacy publisher has no ordering data. Do not let its
                            // replay time outrank a publisher that supplied one.
                            updatedAt:          typeof obj.updatedAt === "number" ? obj.updatedAt : 0,
                            todos:              obj.todos ?? [],
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
