pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property var tasks: []
    property bool failed: false
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
        if (actionProcess.running || fetchProcess.running || refreshPending) return false;
        actionProcess.command = command;
        actionProcess.running = true;
        return true;
    }
    Process {
        id: fetchProcess
        command: ["timeout", "10", "todo.sh", "ls"]
        stdout: StdioCollector { id: fetchOutput }
        onExited: exitCode => {
            root.failed = exitCode !== 0;
            if (exitCode === 0) {
                const tasks = [];
                const lines = fetchOutput.text.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "").split("\n");
                for (const line of lines) {
                    const match = line.match(/^\s*(\d+)\s+(?:\(([A-Z])\)\s+)?(.*)$/);
                    if (match) tasks.push({ id: Number(match[1]), priority: match[2] ?? "", title: match[3] });
                }
                root.tasks = tasks;
            }
            if (root.refreshPending) Qt.callLater(root.refresh);
        }
    }
    Process {
        id: actionProcess
        onExited: exitCode => { root.actionFailed = exitCode !== 0; root.refresh(); }
    }
    // Keep observing edits made outside the shell, including todo CLI changes.
    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
