pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property var containers: []
    property bool failed: false
    property bool hasSnapshot: false
    readonly property string status: !hasSnapshot ? "unavailable" : failed ? "stale" : "ready"
    readonly property string queryMessage: status === "ready" ? "" : status === "stale" ? "Docker updates unavailable. Showing last known containers." : "Docker status unavailable."

    function acceptSnapshot(output, exitCode, exitStatus = 0) {
        failed = true;
        if (exitCode !== 0 || exitStatus !== 0) return;
        try {
            const nextContainers = output.trim().split("\n").filter(line => line.length > 0).map(line => {
                const container = JSON.parse(line);
                if (!container || [container.ID, container.Names, container.Image, container.Status].some(value => typeof value !== "string" || !value))
                    throw new Error("Invalid container row");
                return { id: container.ID, name: container.Names, image: container.Image, status: container.Status };
            });
            containers = nextContainers;
            hasSnapshot = true;
            failed = false;
        } catch (error) { console.warn("SharedDockerProvider:", error); }
    }
    property bool actionFailed: false
    property bool refreshPending: false
    readonly property bool stopping: stopProcess.running

    function refresh() {
        if (listProcess.running) refreshPending = true;
        else { refreshPending = false; listProcess.running = true; }
    }
    function stopContainer(containerId) {
        if (stopProcess.running) return false;
        actionFailed = false;
        stopProcess.command = ["timeout", "30", "docker", "stop", containerId];
        stopProcess.running = true;
        return true;
    }

    Process {
        id: listProcess
        command: ["timeout", "10", "docker", "ps", "--format", "{{json .}}"]
        stdout: StdioCollector { id: listOutput }
        onExited: (exitCode, exitStatus) => {
            root.acceptSnapshot(listOutput.text, exitCode, exitStatus);
            if (root.failed) retryTimer.restart();
            else retryTimer.stop();
            if (root.refreshPending) Qt.callLater(root.refresh);
        }
    }
    Process {
        id: eventsProcess
        command: ["docker", "events", "--filter", "type=container", "--format", "{{json .}}"]
        stdout: SplitParser { onRead: root.refresh() }
        onExited: { root.failed = true; reconnectTimer.restart(); }
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
        onExited: (exitCode, exitStatus) => { root.actionFailed = exitCode !== 0 || exitStatus !== 0; root.refresh(); }
    }
    Component.onCompleted: reconnect()
}
