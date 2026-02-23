import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Notification toast stack — top-right corner, newest on top.
// One instance per screen.
PanelWindow {
    id: root

    required property var screen

    screen: root.screen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.margins.bottom: 38    // 28px bar height + 10px gap
    WlrLayershell.margins.right: 10

    anchors {
        bottom: true
        right: true
    }

    // Size to fit the list; invisible when empty.
    implicitWidth: 360
    implicitHeight: Math.max(1, toastList.contentHeight)
    color: "transparent"
    visible: NotificationService.notifications.length > 0

    ListView {
        id: toastList

        anchors {
            fill: parent
            margins: 0
        }
        spacing: 8
        model: NotificationService.notifications
        clip: false
        interactive: false

        // Slide in from bottom, fade in
        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { property: "y"; from: 60; duration: 220; easing.type: Easing.OutQuad }
            }
        }

        // Slide out to right, fade out
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutQuad }
                NumberAnimation { property: "x"; to: 380; duration: 250; easing.type: Easing.InBack; easing.overshoot: 1.2 }
            }
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutQuad }
        }

        delegate: Item {
            id: toastItem

            // modelData is a Notification object.
            // It is cached at creation time so it stays valid during remove
            // animations, when QML may set modelData to null.
            required property var modelData
            property var notification: null

            Component.onCompleted: notification = modelData

            width: toastList.width
            implicitHeight: toastCard.implicitHeight

            // Auto-dismiss after expireTimeout. 0 means never auto-dismiss.
            Timer {
                id: dismissTimer
                interval: notification && notification.expireTimeout > 0 ? notification.expireTimeout : 5000
                running: notification !== null && notification.expireTimeout !== 0
                onTriggered: if (notification) notification.dismiss()
            }

            Rectangle {
                id: toastCard
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: toastContent.implicitHeight + 24
                radius: 12
                color: "#1e1e2e"
                border.color: notification && notification.urgency === 2 ? "#ff5555" : "#44475a"
                border.width: 1

                // Progress bar draining from right → left (hidden when no timeout)
                Rectangle {
                    id: timerBar
                    visible: notification && notification.expireTimeout !== 0
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                        bottomMargin: 0
                    }
                    height: 2
                    radius: 1
                    color: notification && notification.urgency === 2 ? "#ff5555" : "#bd93f9"

                    property real progress: 1.0
                    width: parent.width * progress

                    NumberAnimation on progress {
                        from: 1.0; to: 0.0
                        duration: dismissTimer.interval
                        running: true
                    }
                }

                ColumnLayout {
                    id: toastContent
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 6

                    // Header row: app icon + name + close button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // App icon
                        Item {
                            implicitWidth: 20
                            implicitHeight: 20

                            Image {
                                id: appIconImg
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                source: {
                                    var icon = notification ? (notification.appIcon ?? "") : "";
                                    if (icon === "") return "";
                                    if (icon.startsWith("/")) return "file://" + icon;
                                    return "image://icon/" + icon;
                                }
                                visible: status === Image.Ready
                                cache: false
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\udb80\udcd8"   // nf-md-bell (󰃘)
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 14
                                color: "#6272a4"
                                visible: !appIconImg.visible
                            }
                        }

                        Text {
                            text: notification ? (notification.appName ?? "") : ""
                            color: "#8be9fd"
                            font.bold: true
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Close button
                        Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 10
                            color: closeArea.containsMouse ? "#ff5555" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: closeArea.containsMouse ? "#1e1e2e" : "#6272a4"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (notification) notification.dismiss()
                            }

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    // Summary
                    Text {
                        text: notification ? (notification.summary ?? "") : ""
                        color: "#f8f8f2"
                        font.bold: true
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        visible: notification && (notification.summary ?? "") !== ""
                    }

                    // Body
                    Text {
                        text: notification ? (notification.body ?? "") : ""
                        color: "#cdd6f4"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        visible: notification && (notification.body ?? "") !== ""
                    }

                    // Action buttons
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: notification && notification.actions && notification.actions.length > 0

                        Repeater {
                            model: notification ? notification.actions : []

                            Rectangle {
                                required property var modelData
                                readonly property var action: modelData

                                implicitWidth: actionLabel.implicitWidth + 20
                                implicitHeight: 26
                                radius: 6
                                color: actionArea.containsMouse ? "#44475a" : "#313244"
                                border.color: "#6272a4"
                                border.width: 1

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: action.text ?? action.id ?? ""
                                    color: "#f8f8f2"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    id: actionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        action.invoke();
                                        if (toastItem.notification) toastItem.notification.dismiss();
                                    }
                                }

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                    }
                }

                // Dismiss on click anywhere on the card (child mouse areas take priority)
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: if (notification) notification.dismiss()
                }
            }
        }
    }

    // Transparent window mask to only intercept input on actual toasts
    mask: Region {
        item: toastList.contentHeight > 0 ? toastList : null
    }
}
