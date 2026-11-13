import Quickshell
import QtQuick
import QtQuick.Layouts

// A notification with an explicit Hyprland window address, placed above the
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
    // Stack notifications upward from the bottom bar, leaving a 4px gap.
    anchor.rect: Qt.rect(0, -4 - root.stackIndex * (root.implicitHeight + 8), 1, 1)

    implicitWidth: root.workspaceItem?.width ?? 360
    implicitHeight: card.implicitHeight
    color: "transparent"

    property var retainedNotification: null
    Component.onCompleted: {
        retainedNotification = notification;
        retainedNotification.retainView();
    }
    Component.onDestruction: if (retainedNotification) retainedNotification.releaseView()

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: content.implicitHeight + 16
        radius: 12
        color: "#b31e1e2e"
        border.color: root.notification?.urgency === 2 ? "#ff5555" : "#44475a"
        border.width: 1

        RowLayout {
            id: content
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: (root.notification?.body ?? "").trim() !== ""
                    ? root.notification.body
                    : (root.notification?.summary ?? "")
                color: "#cdd6f4"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.StyledText
            }

            Text {
                Layout.alignment: Qt.AlignTop
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

        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.notification) root.notification.activate();
            }
        }
    }
}
