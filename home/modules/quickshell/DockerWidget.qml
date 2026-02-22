import Quickshell.Io
import QtQuick
import QtQuick.Controls

// Running Docker container count. Polls every 10 s.
Item {
    id: root
    implicitWidth: 60
    implicitHeight: 22

    property int containerCount: 0

    Process {
        id: dockerProc
        command: ["docker-count"]
        running: true

        property string buf: ""

        stdout: SplitParser {
            onRead: data => dockerProc.buf += data
        }

        onExited: {
            root.containerCount = parseInt(dockerProc.buf.trim()) || 0;
            dockerProc.buf = "";
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: dockerProc.running = true
    }

    Rectangle {
        anchors.fill: parent
        color: "#1D63ED"
        radius: 4

        Text {
            id: label
            anchors.centerIn: parent
            text: root.containerCount + "  "
            color: "#ffffff"
            font.pixelSize: 11
        }

        ToolTip.visible: hoverArea.containsMouse
        ToolTip.text: root.containerCount + " containers running"
        ToolTip.delay: 500

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
        }
    }
}
