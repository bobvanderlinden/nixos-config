import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A single notification popup shown in the bottom-right corner above the bar.
// popupIndex determines vertical stacking (0 = lowest, closest to bar).
PanelWindow {
    id: root
    required property var notification
    property int popupIndex: 0

    // Each popup is offset upward by its index × (popup height + gap).
    // Base margin is bar height (28) + small gap (8).
    readonly property int baseMargin: 36
    readonly property int popupHeight: 100
    readonly property int popupGap: 8

    anchors {
        right: true
        bottom: true
    }
    margins.bottom: baseMargin + popupIndex * (popupHeight + popupGap)
    margins.right: 8

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notif"

    implicitWidth: 360
    implicitHeight: notifBox.implicitHeight + 16
    color: "transparent"

    Rectangle {
        id: notifBox
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        implicitHeight: content.implicitHeight + 16
        color: "#2a2b3d"
        radius: 8
        border.color: "#44475a"
        border.width: 1

        ColumnLayout {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 4

            // Header: app name + close button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.notification.appName
                    color: "#8be9fd"
                    font.bold: true
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: "✕"
                    color: "#6272a4"
                    font.pixelSize: 14
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.notification.dismiss()
                    }
                }
            }

            // Summary
            Text {
                text: root.notification.summary
                color: "#f8f8f2"
                font.bold: true
                font.pixelSize: 13
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: root.notification.summary !== ""
            }

            // Body
            Text {
                text: root.notification.body
                color: "#f8f8f2"
                font.pixelSize: 12
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                visible: root.notification.body !== ""
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.notification.actions.length > 0

                Repeater {
                    model: root.notification.actions

                    Button {
                        required property var modelData
                        text: modelData.text
                        onClicked: modelData.invoke()

                        background: Rectangle {
                            color: parent.hovered ? "#44475a" : "#383a59"
                            radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#f8f8f2"
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        // Auto-dismiss timer
        Timer {
            interval: root.notification.expireTimeout
            running: root.notification.expireTimeout > 0
            onTriggered: root.notification.dismiss()
        }
    }
}
