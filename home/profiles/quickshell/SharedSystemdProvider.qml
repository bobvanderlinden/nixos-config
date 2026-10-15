pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property int failedCount: 0
    property bool failed: false
    function refresh() { if (!checkProcess.running) checkProcess.running = true; }
    Process {
        id: checkProcess
        command: ["timeout", "10", "systemctl", "--user", "--state=failed", "--no-legend", "--no-pager", "list-units", "--output=json"]
        stdout: StdioCollector { id: checkOutput }
        onExited: exitCode => {
            root.failed = exitCode !== 0;
            if (exitCode === 0) {
                try {
                    const units = JSON.parse(checkOutput.text);
                    if (!Array.isArray(units)) throw new Error("Expected unit array");
                    root.failedCount = units.length;
                } catch (error) { root.failed = true; console.warn("SharedSystemdProvider:", error); }
            }
        }
    }
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
