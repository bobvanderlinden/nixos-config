pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property var tasks: []
    property bool failed: false
    property bool hasSnapshot: false
    readonly property string status: !hasSnapshot ? "unavailable" : failed ? "stale" : "ready"
    readonly property string queryMessage: status === "ready" ? "" : status === "stale" ? "Task query failed. Showing last known tasks." : "Tasks unavailable."
    signal actionFinished(bool successful)

    function acceptSnapshot(output, exitCode, exitStatus = 0) {
        failed = true;
        if (exitCode !== 0 || exitStatus !== 0) return;
        try {
            const nextTasks = [];
            const identifiers = new Set();
            const lines = output.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "").split("\n");
            for (const line of lines) {
                if (!line.trim() || /^--$/.test(line.trim()) || /^TODO: \d+ of \d+ tasks shown$/.test(line.trim())) continue;
                const match = line.match(/^\s*(\d+)\s+(?:\(([A-Z])\)\s+)?(.+)$/);
                if (!match || !match[3].trim() || identifiers.has(Number(match[1]))) throw new Error("Invalid task row");
                identifiers.add(Number(match[1]));
                nextTasks.push({ id: Number(match[1]), priority: match[2] ?? "", title: match[3] });
            }
            tasks = nextTasks;
            hasSnapshot = true;
            failed = false;
        } catch (error) { console.warn("SharedTodoProvider:", error); }
    }
    property bool actionFailed: false
    property bool refreshPending: false
    readonly property bool busy: actionProcess.running

    function refresh() {
        if (fetchProcess.running || actionProcess.running) refreshPending = true;
        else { refreshPending = false; fetchProcess.running = true; }
    }
    function addTask(title) { return act(["timeout", "10", "todo.sh", "add", title]); }
    function completeTask(taskId) { return act(["timeout", "10", "todo.sh", "do", taskId.toString()]); }
    function act(command) {
        // Task numbers can change after a mutation. Do not act on a snapshot
        // while another command or its completion refresh is still running.
        if (actionProcess.running || fetchProcess.running || refreshPending || status !== "ready") return false;
        actionFailed = false;
        actionProcess.command = command;
        actionProcess.running = true;
        return true;
    }
    Process {
        id: fetchProcess
        command: ["timeout", "10", "todo.sh", "ls"]
        stdout: StdioCollector { id: fetchOutput }
        onExited: (exitCode, exitStatus) => {
            root.acceptSnapshot(fetchOutput.text, exitCode, exitStatus);
            if (root.refreshPending) Qt.callLater(root.refresh);
        }
    }
    Process {
        id: actionProcess
        onExited: (exitCode, exitStatus) => {
            root.actionFailed = exitCode !== 0 || exitStatus !== 0;
            root.actionFinished(!root.actionFailed);
            root.refresh();
        }
    }
    // Keep observing edits made outside the shell, including todo CLI changes.
    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
