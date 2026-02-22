import Quickshell.Io
import QtQuick

// Session time (HH:MM 🔒). Polls every 60 s.
BarPill {
    id: root
    color: "#1a2e28"

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

    Text {
        id: label
        text: "🔓 " + root.sessionTime
        color: "#50fa7b"
        font.pixelSize: 12
    }
}
