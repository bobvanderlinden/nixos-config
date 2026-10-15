pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property string sessionTime: "--:--"
    property bool failed: false
    function refresh() { if (!sessionProcess.running) sessionProcess.running = true; }
    Process {
        id: sessionProcess
        command: ["timeout", "10", "session-time"]
        stdout: StdioCollector { id: sessionOutput }
        onExited: exitCode => {
            root.failed = exitCode !== 0 || sessionOutput.text.trim().length === 0;
            if (!root.failed) root.sessionTime = sessionOutput.text.trim();
        }
    }
    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
