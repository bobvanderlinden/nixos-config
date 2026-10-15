import QtQuick
import QtQuick.Layouts

// Shows count of failed systemd user units. Hidden when count is 0.
Item {
    id: root
    implicitWidth: visible ? failedText.implicitWidth + 12 : 0
    implicitHeight: 22
    visible: failedCount > 0

    readonly property int failedCount: SharedSystemdProvider.failedCount

    Rectangle {
        anchors.fill: parent
        color: "#eb4d4b"
        radius: 4

        Text {
            id: failedText
            anchors.centerIn: parent
            text: "⚠ " + root.failedCount + " failed"
            color: "#ffffff"
            font.pixelSize: 12
        }
    }
}
