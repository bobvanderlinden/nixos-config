import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Agent sessions widget.
//
// Collapsed (bar): pill with robot emoji + one dot per session.
// Expanded (hover): popup listing sessions with status info + todos + status badge.
//   Clicking a row focuses the agent's window.
PopupWidget {
    id: root

    popupWidth: 320
    visible: AgentState.sessions.length > 0

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

    // Show the most specific status verbatim, even if a publisher introduces a
    // new value. Color selection must instead use a state it understands.
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

    function normalizedWindowAddress(windowAddress) {
        if (windowAddress === null || windowAddress === undefined || windowAddress === "") return "";
        const address = windowAddress.toString();
        return address.startsWith("0x") ? address : "0x" + address;
    }

    function windowSelector(windowAddress) {
        return "address:" + normalizedWindowAddress(windowAddress);
    }

    // ── Pill ──────────────────────────────────────────────────────────────────

    pillContent: Component {
        RowLayout {
            spacing: 4

            Text {
                text: "🤖"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            Repeater {
                model: AgentState.sessions

                Rectangle {
                    required property var modelData
                    width: 8; height: 8; radius: 4
                    Layout.alignment: Qt.AlignVCenter
                    color: root.stateColor(root.colorState(modelData))
                }
            }
        }
    }

    // ── Popup ─────────────────────────────────────────────────────────────────

    popupContent: Component {
        ColumnLayout {
            spacing: 2

            Repeater {
                model: AgentState.sessions

                Rectangle {
                    required property var modelData
                    property var session: modelData
                    property bool canFocus: root.normalizedWindowAddress(session.windowAddress) !== ""

                    property var hyprToplevel: {
                        if (!session.windowAddress) return null;
                        const normalizedAddress = root.normalizedWindowAddress(session.windowAddress);
                        return Hyprland.toplevels.values.find(toplevel => toplevel.address === normalizedAddress) ?? null;
                    }
                    property string workspaceId: (hyprToplevel?.workspace?.id ?? 0) > 0
                        ? hyprToplevel.workspace.id.toString() : ""
                    property string statusSummary: session.sessionDescription ?? session.description ?? ""
                    property string displayText: statusSummary !== "" ? statusSummary
                        : (session.title !== "" ? session.title : "(unknown)")
                    property string currentDisplayStatus: root.displayStatus(session)
                    property string currentColorState: root.colorState(session)

                    Layout.fillWidth: true
                    implicitHeight: rowLayout.implicitHeight + 8
                    radius: 4
                    color: rowHover.hovered && canFocus ? "#313244" : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    HoverHandler { id: rowHover }

                    RowLayout {
                        id: rowLayout
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 6; rightMargin: 6 }
                        spacing: 8

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: root.stateColor(currentColorState)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: displayText
                                color: canFocus ? "#f8f8f2" : "#6272a4"
                                font.pixelSize: 12
                                font.family: "SauceCodePro Nerd Font"
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: workspaceId !== ""
                                text: "workspace " + workspaceId
                                color: "#44475a"
                                font.pixelSize: 10
                                font.family: "SauceCodePro Nerd Font"
                            }
                        }

                        Text {
                            property var activeTodos: (session.todos ?? []).filter(t => t.status !== "cancelled")
                            property int completedCount: activeTodos.filter(t => t.status === "completed").length
                            visible: activeTodos.length > 0
                            text: completedCount + "/" + activeTodos.length
                            color: completedCount === activeTodos.length ? "#50fa7b" : "#6272a4"
                            font.pixelSize: 10
                            font.family: "SauceCodePro Nerd Font"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Rectangle {
                            implicitWidth: stateLabel.implicitWidth + 8
                            implicitHeight: 16
                            radius: 3
                            color: root.stateBgColor(currentColorState)

                            Text {
                                id: stateLabel
                                anchors.centerIn: parent
                                text: currentDisplayStatus
                                color: root.stateColor(currentColorState)
                                font.pixelSize: 10
                                font.family: "SauceCodePro Nerd Font"
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.canFocus
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            Hyprland.dispatch("hl.dsp.focus({ window = \"" + root.windowSelector(session.windowAddress) + "\" })");
                            BarState.activePopupWidget = null;
                        }
                    }
                }
            }
        }
    }
}
