import Quickshell
import QtQuick
import QtQuick.Layouts

// A notification with an explicit Hyprland window address, placed below the
// workspace that owns that window.
PopupWindow {
    id: root

    required property var barWindow
    required property var notification
    required property Item workspaceItem
    property int stackIndex: 0

    visible: notification !== null && workspaceItem !== null
    anchor.item: root.workspaceItem
    anchor.adjustment: PopupAdjustment.Flip
    anchor.rect: Qt.rect(0, (root.workspaceItem?.height ?? 0) + 4 + root.stackIndex * 104, 1, 1)

    implicitWidth: root.workspaceItem?.width ?? 360
    implicitHeight: card.implicitHeight
    color: "transparent"

    Timer {
        interval: root.notification?.expireTimeout > 0 ? root.notification.expireTimeout : 5000
        running: root.notification !== null && root.notification.expireTimeout !== 0
        onTriggered: root.notification.dismiss()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: content.implicitHeight + 24
        radius: 12
        color: "#1e1e2e"
        border.color: root.notification?.urgency === 2 ? "#ff5555" : "#44475a"
        border.width: 1

        ColumnLayout {
            id: content
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.notification?.appName ?? ""
                    color: "#8be9fd"
                    font.bold: true
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: "✕"
                    color: "#6272a4"
                    font.pixelSize: 11

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notification.dismiss()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.notification?.summary ?? ""
                color: "#f8f8f2"
                font.bold: true
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: (root.notification?.body ?? "") !== ""
                text: root.notification?.body ?? ""
                color: "#cdd6f4"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.StyledText
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const defaultAction = root.notification.actions.find(action => action.identifier === "default");
                if (defaultAction) defaultAction.invoke();
                root.notification.dismiss();
            }
        }
    }
}
