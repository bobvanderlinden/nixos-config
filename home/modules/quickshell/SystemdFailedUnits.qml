import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Shows count of failed systemd user units. Hidden when count is 0.
Item {
    id: root
    implicitWidth: visible ? failedText.implicitWidth + 12 : 0
    implicitHeight: 22
    visible: failedCount > 0

    property int failedCount: 0

    Process {
        id: systemdCheck
        command: ["systemctl", "--user", "--state=failed", "--no-legend", "--no-pager",
                  "list-units", "--output=json"]
        running: true

        property string buf: ""

        stdout: SplitParser {
            onRead: data => systemdCheck.buf += data
        }

        onExited: {
            try {
                const units = JSON.parse(systemdCheck.buf);
                root.failedCount = Array.isArray(units) ? units.length : 0;
            } catch (e) {
                root.failedCount = 0;
            }
            systemdCheck.buf = "";
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: systemdCheck.running = true
    }

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
