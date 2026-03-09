import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Reusable GitHub PR pill.
//
// Collapsed (bar): pill with icon + count. Hidden when list is empty.
// Expanded (hover): popup listing each PR (repo + title). Click opens URL.
PopupWidget {
    id: root

    required property var openProcess
    required property string pillIcon
    required property color pillColor
    required property var pullRequests

    popupWidth: 420
    visible: pullRequests.length > 0

    // ── Pill ──────────────────────────────────────────────────────────────────

    pillContent: Component {
        RowLayout {
            spacing: 4

            Text {
                text: root.pillIcon
                color: root.pillColor
                font.pixelSize: 12
                font.family: "SauceCodePro Nerd Font"
            }

            Text {
                text: root.pullRequests.length.toString()
                color: root.pillColor
                font.pixelSize: 11
                font.family: "SauceCodePro Nerd Font"
            }
        }
    }

    // ── Popup ─────────────────────────────────────────────────────────────────

    popupContent: Component {
        ColumnLayout {
            spacing: 2

            Repeater {
                model: root.pullRequests

                Rectangle {
                    required property var modelData
                    property var pr: modelData

                    Layout.fillWidth: true
                    implicitHeight: rowLayout.implicitHeight + 10
                    radius: 4
                    color: rowHover.hovered ? "#313244" : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    HoverHandler { id: rowHover }

                    RowLayout {
                        id: rowLayout
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 6; rightMargin: 6 }
                        spacing: 8

                        Text {
                            text: pr.repo
                            color: "#8be9fd"
                            font.pixelSize: 10
                            font.family: "SauceCodePro Nerd Font"
                            Layout.preferredWidth: 110
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "#" + pr.number + " " + pr.title
                            color: "#f8f8f2"
                            font.pixelSize: 12
                            font.family: "SauceCodePro Nerd Font"
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.openProcess.url = pr.url;
                            root.openProcess.running = true;
                            BarState.activePopupWidget = null;
                        }
                    }
                }
            }
        }
    }
}
