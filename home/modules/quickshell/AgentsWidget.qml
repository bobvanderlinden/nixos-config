import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Agent sessions widget.
//
// Collapsed (bar): a row of coloured dots — one per session.
//   green (#50fa7b) = active, grey (#6272a4) = idle.
//   Hidden entirely when there are no sessions.
//
// Expanded (hover): a PopupWindow appears above the bar listing all
//   sessions with workspace number + title + state badge.
//   Clicking a row focuses the agent's window via hyprctl.
//   Auto-closes when the mouse leaves the popup.
Item {
    id: root

    // Must be set by StatusBar to the enclosing PanelWindow
    // so the PopupWindow can anchor itself above the bar.
    required property var barWindow

    implicitWidth: sessions.length > 0 ? dotRow.implicitWidth + 8 : 0
    implicitHeight: 22
    visible: sessions.length > 0

    property var sessions: AgentState.sessions

    // ── Collapsed: dot row ────────────────────────────────────────────────────

    RowLayout {
        id: dotRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.sessions

            Rectangle {
                required property var modelData
                width: 8
                height: 8
                radius: 4
                color: modelData.state === "active" ? "#50fa7b" : "#6272a4"
            }
        }
    }

    // ── Hover detection on the bar item ──────────────────────────────────────

    HoverHandler {
        id: barHover
    }

    // ── Expanded: popup list ──────────────────────────────────────────────────

    PopupWindow {
        id: popup

        // Show when mouse is over the bar item OR over the popup itself.
        visible: barHover.hovered || popupHover.hovered

        anchor.window: root.barWindow
        // Position above the bar, left-aligned to this widget.
        // root.x is the widget's x within the bar's content item.
        anchor.rect.x: root.x
        anchor.rect.y: -popup.height
        anchor.rect.width: root.width
        anchor.rect.height: root.height

        implicitWidth: 320
        implicitHeight: sessionList.implicitHeight + 12
        color: "#2a2b3d"

        HoverHandler {
            id: popupHover
        }

        ColumnLayout {
            id: sessionList
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 6
            }
            spacing: 2

            Repeater {
                model: root.sessions

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
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 8

                        // State dot
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: session.state === "active" ? "#50fa7b" : "#6272a4"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Label: "Workspace N" or title (fallback to workspace)
                        Text {
                            Layout.fillWidth: true
                            text: {
                                const ws = session.workspaceId != null ? "Workspace " + session.workspaceId : "";
                                const t  = session.title ?? "";
                                if (t !== "") return ws !== "" ? ws + " — " + t : t;
                                return ws !== "" ? ws : "(unknown)";
                            }
                            color: parent.parent.canFocus ? "#f8f8f2" : "#6272a4"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        // State badge
                        Rectangle {
                            implicitWidth: stateLabel.implicitWidth + 8
                            implicitHeight: 16
                            radius: 3
                            color: session.state === "active" ? "#1a3d2b" : "#2d2d3f"

                            Text {
                                id: stateLabel
                                anchors.centerIn: parent
                                text: session.state === "active" ? "active" : "idle"
                                color: session.state === "active" ? "#50fa7b" : "#6272a4"
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
                            popup.visible = false;
                        }
                    }
                }
            }
        }
    }
}
