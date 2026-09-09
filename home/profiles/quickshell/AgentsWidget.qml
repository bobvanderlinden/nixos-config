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

    function normalizedWindowAddress(windowAddress) {
        if (windowAddress === null || windowAddress === undefined || windowAddress === "") return "";
        const address = windowAddress.toString();
        return address.startsWith("0x") ? address.slice(2) : address;
    }

    function windowSelector(windowAddress) {
        return "address:0x" + normalizedWindowAddress(windowAddress);
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
                    color: AgentState.stateColor(AgentState.colorState(modelData))
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
                    property string currentDisplayStatus: AgentState.displayStatus(session)
                    property string currentColorState: AgentState.colorState(session)

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
                            color: AgentState.stateColor(currentColorState)
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
                            color: AgentState.stateBgColor(currentColorState)

                            Text {
                                id: stateLabel
                                anchors.centerIn: parent
                                text: currentDisplayStatus
                                color: AgentState.stateColor(currentColorState)
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
