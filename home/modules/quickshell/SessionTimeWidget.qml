import Quickshell.Io
import QtQuick

// Session time (HH:MM 🔒). Polls every 60 s.
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22

    property string sessionTime: "--:--"

    Process {
        id: sessionProc
        command: ["session-time"]
        running: true

        property string buf: ""

        stdout: SplitParser {
            onRead: data => sessionProc.buf += data
        }

        onExited: {
            root.sessionTime = sessionProc.buf.trim();
            sessionProc.buf = "";
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: sessionProc.running = true
    }

    Rectangle {
        anchors.fill: parent
        color: "#008261"
        radius: 4

        Text {
            id: label
            anchors.centerIn: parent
            text: "🔓 " + root.sessionTime
            color: "#ffffff"
            font.pixelSize: 12
        }
    }
}
