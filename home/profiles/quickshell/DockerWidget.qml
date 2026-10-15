import Quickshell
import QtQuick
import QtQuick.Layouts

// Docker widget.
//
// Collapsed (bar): container count badge. Hidden when no containers running.
// Expanded (hover): popup listing container name + image, with a kill button.
PopupWidget {
    id: root

    popupWidth: 360
    visible: containers.length > 0

    readonly property var containers: SharedDockerProvider.containers

    // ── Pill ──────────────────────────────────────────────────────────────────

    pillContent: Component {
        Text {
            text: "🐳 " + root.containers.length
            color: "#89b4fa"
            font.pixelSize: 11
            font.family: "SauceCodePro Nerd Font"
        }
    }

    // ── Popup ─────────────────────────────────────────────────────────────────

    popupContent: Component {
        ColumnLayout {
            spacing: 2

            Repeater {
                model: root.containers

                Rectangle {
                    required property var modelData
                    property var container: modelData

                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 4
                    color: rowHover.hovered ? "#313244" : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: container.name
                            color: "#f8f8f2"
                            font.pixelSize: 12
                            font.family: "SauceCodePro Nerd Font"
                            elide: Text.ElideRight
                        }

                        Text {
                            text: container.image
                            color: "#6272a4"
                            font.pixelSize: 11
                            font.family: "SauceCodePro Nerd Font"
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                        }

                        Rectangle {
                            implicitWidth: 20; implicitHeight: 20
                            radius: 3
                            color: killHover.hovered ? "#ff5555" : "#44475a"
                            Behavior on color { ColorAnimation { duration: 80 } }

                            HoverHandler { id: killHover }

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: "#f8f8f2"
                                font.pixelSize: 12
                                font.family: "SauceCodePro Nerd Font"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    SharedDockerProvider.stopContainer(container.id);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
