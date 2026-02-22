import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Agent sessions widget.
//
// Collapsed (bar): a row of coloured dots — one per session.
//   orange (#fab283, OpenCode brand) = busy/retry, grey (#6272a4) = idle.
//   Hidden entirely when there are no sessions.
//
// Expanded (hover): a PopupWindow appears above the bar listing all
//   sessions with title + state badge.
//   Clicking a row focuses the agent's window via hyprctl.
//   Auto-closes when the mouse leaves.
RowLayout {
    id: root

    spacing: 3
    visible: AgentState.sessions.length > 0

    // Must be set by StatusBar to the enclosing PanelWindow.
    required property var barWindow

    // ── Collapsed: robot emoji prefix + one dot per session ─────────────────

    Text {
        text: "🤖"
        font.pixelSize: 12
        Layout.alignment: Qt.AlignVCenter
    }

    Repeater {
        id: dotRepeater
        model: AgentState.sessions

        Rectangle {
            required property var modelData
            width: 8
            height: 8
            radius: 4
            Layout.alignment: Qt.AlignVCenter
            color: modelData.state !== "idle" ? "#fab283" : "#6272a4"
        }
    }

    // ── Hover detection ───────────────────────────────────────────────────────

    HoverHandler {
        id: barHover
    }

    // ── Expanded: popup above the bar ────────────────────────────────────────

    // Small delay before hiding so the mouse can travel from bar to popup
    // without the popup disappearing in the gap.
    Timer {
        id: hideTimer
        interval: 200
        onTriggered: popup.visible = false
    }

    PopupWindow {
        id: popup
        visible: false

        onVisibleChanged: if (visible) hideTimer.stop()

        Connections {
            target: barHover
            function onHoveredChanged() {
                if (barHover.hovered) {
                    hideTimer.stop();
                    popup.visible = true;
                } else if (!popupHover.hovered) {
                    hideTimer.restart();
                }
            }
        }

        Connections {
            target: popupHover
            function onHoveredChanged() {
                if (popupHover.hovered) {
                    hideTimer.stop();
                } else if (!barHover.hovered) {
                    hideTimer.restart();
                }
            }
        }

        anchor.window: root.barWindow
        anchor.rect.x: root.x
        anchor.rect.y: -popup.implicitHeight
        anchor.rect.width: 1
        anchor.rect.height: 1

        implicitWidth: 320
        implicitHeight: popupCol.implicitHeight + 12
        color: "#2a2b3d"

        HoverHandler { id: popupHover }

        ColumnLayout {
            id: popupCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 6
            }
            spacing: 2

            Repeater {
                model: AgentState.sessions

                Rectangle {
                    required property var modelData
                    property var session: modelData
                    property bool canFocus: session.windowAddress !== null

                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 4
                    color: rowHover.hovered && canFocus ? "#383a59" : "transparent"

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 8

                        // State dot
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: session.state !== "idle" ? "#fab283" : "#6272a4"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Title
                        Text {
                            Layout.fillWidth: true
                            text: session.title !== "" ? session.title : "(unknown)"
                            color: canFocus ? "#f8f8f2" : "#6272a4"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        // State badge
                        Rectangle {
                            implicitWidth: stateLabel.implicitWidth + 8
                            implicitHeight: 16
                            radius: 3
                            color: session.state !== "idle" ? "#3d2a1a" : "#2d2d3f"

                            Text {
                                id: stateLabel
                                anchors.centerIn: parent
                                text: session.state
                                color: session.state !== "idle" ? "#fab283" : "#6272a4"
                                font.pixelSize: 10
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.canFocus
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            Hyprland.dispatch("focuswindow address:" + session.windowAddress);
                            hideTimer.stop();
                            popup.visible = false;
                        }
                    }
                }
            }
        }
    }
}
