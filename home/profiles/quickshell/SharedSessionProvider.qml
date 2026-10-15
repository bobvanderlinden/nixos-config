pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property string sessionTime: "--:--"
    property bool failed: false
    property bool hasSnapshot: false
    readonly property string status: !hasSnapshot ? "unavailable" : failed ? "stale" : "ready"
    function acceptSnapshot(output, exitCode, exitStatus = 0) {
        failed = exitCode !== 0 || exitStatus !== 0 || !/^\d{2,}:[0-5]\d$/.test(output.trim());
        if (!failed) { sessionTime = output.trim(); hasSnapshot = true; }
    }
    function refresh() { if (!sessionProcess.running) sessionProcess.running = true; }
    Process {
        id: sessionProcess
        command: ["timeout", "10", "session-time"]
        stdout: StdioCollector { id: sessionOutput }
        onExited: (exitCode, exitStatus) => root.acceptSnapshot(sessionOutput.text, exitCode, exitStatus)
    }
    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
