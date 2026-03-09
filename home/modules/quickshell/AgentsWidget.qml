import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Agent sessions widget.
//
// Collapsed (bar): pill with robot emoji + one dot per session.
// Expanded (hover): popup listing sessions with title + todos + state badge.
//   Clicking a row focuses the agent's window.
PopupWidget {
    id: root

    popupWidth: 320
    visible: AgentState.sessions.length > 0

    function stateColor(state) {
        switch (state) {
            case "error":      return "#ff5555";
            case "permission": return "#f1fa8c";
            case "question":   return "#8be9fd";
            case "busy":
            case "retry":      return "#fab283";
            default:           return "#6272a4";
        }
    }

    function stateBgColor(state) {
        switch (state) {
            case "error":      return "#3d1a1a";
            case "permission": return "#3d3a1a";
            case "question":   return "#1a2d3a";
            case "busy":
            case "retry":      return "#3d2a1a";
            default:           return "#2d2d3f";
        }
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
                    color: root.stateColor(modelData.state)
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
                    property bool canFocus: session.windowAddress !== null

                    property var hyprToplevel: {
                        if (!session.windowAddress) return null;
                        return Hyprland.toplevels.values.find(t => t.address === session.windowAddress) ?? null;
                    }
                    property string workspaceId: (hyprToplevel?.workspace?.id ?? 0) > 0
                        ? hyprToplevel.workspace.id.toString() : ""

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
                            color: root.stateColor(session.state)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: session.title !== "" ? session.title : "(unknown)"
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
                            color: root.stateBgColor(session.state)

                            Text {
                                id: stateLabel
                                anchors.centerIn: parent
                                text: session.state
                                color: root.stateColor(session.state)
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
                            Hyprland.dispatch("focuswindow address:0x" + session.windowAddress);
                            BarState.activePopupWidget = null;
                        }
                    }
                }
            }
        }
    }
}
