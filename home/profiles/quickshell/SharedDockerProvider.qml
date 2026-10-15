pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property var containers: []
    property bool failed: false
    property bool actionFailed: false
    property bool refreshPending: false
    readonly property bool stopping: stopProcess.running

    function refresh() {
        if (listProcess.running) refreshPending = true;
        else { refreshPending = false; listProcess.running = true; }
    }
    function stopContainer(containerId) {
        if (stopProcess.running) return false;
        stopProcess.command = ["timeout", "30", "docker", "stop", containerId];
        stopProcess.running = true;
        return true;
    }

    Process {
        id: listProcess
        command: ["timeout", "10", "docker", "ps", "--format", "{{json .}}"]
        stdout: StdioCollector { id: listOutput }
        onExited: exitCode => {
            root.failed = exitCode !== 0;
            if (exitCode === 0) {
                try {
                    root.containers = listOutput.text.trim().split("\n").filter(line => line.length > 0).map(line => {
                        const container = JSON.parse(line);
                        return { id: container.ID, name: container.Names, image: container.Image, status: container.Status };
                    });
                } catch (error) { root.failed = true; console.warn("SharedDockerProvider:", error); }
            }
            if (root.failed) retryTimer.restart();
            else retryTimer.stop();
            if (root.refreshPending) Qt.callLater(root.refresh);
        }
    }
    Process {
        id: eventsProcess
        command: ["docker", "events", "--filter", "type=container", "--format", "{{json .}}"]
        stdout: SplitParser { onRead: root.refresh() }
        onExited: reconnectTimer.restart()
    }
    // Subscribe before taking a snapshot. Reconnect always resnapshots, since
    // events during a daemon outage may have been lost.
    function reconnect() {
        if (!eventsProcess.running) eventsProcess.running = true;
        refresh();
    }
    Timer { id: reconnectTimer; interval: 5000; onTriggered: root.reconnect() }
    Timer { id: retryTimer; interval: 10000; onTriggered: root.refresh() }
    Process {
        id: stopProcess
        onExited: exitCode => { root.actionFailed = exitCode !== 0; root.refresh(); }
    }
    Component.onCompleted: reconnect()
}
