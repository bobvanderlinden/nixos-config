pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property int failedCount: 0
    property bool failed: false
    property bool hasSnapshot: false
    readonly property string status: !hasSnapshot ? "unavailable" : failed ? "stale" : "ready"
    function acceptSnapshot(output, exitCode, exitStatus = 0) {
        failed = true;
        if (exitCode !== 0 || exitStatus !== 0) return;
        try {
            const units = JSON.parse(output);
            if (!Array.isArray(units) || units.some(unit => !unit || typeof unit.unit !== "string" || !unit.unit || unit.active !== "failed"))
                throw new Error("Expected failed unit array");
            failedCount = units.length;
            hasSnapshot = true;
            failed = false;
        } catch (error) { console.warn("SharedSystemdProvider:", error); }
    }
    function refresh() { if (!checkProcess.running) checkProcess.running = true; }
    Process {
        id: checkProcess
        command: ["timeout", "10", "systemctl", "--user", "--state=failed", "--no-legend", "--no-pager", "list-units", "--output=json"]
        stdout: StdioCollector { id: checkOutput }
        onExited: (exitCode, exitStatus) => root.acceptSnapshot(checkOutput.text, exitCode, exitStatus)
    }
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
