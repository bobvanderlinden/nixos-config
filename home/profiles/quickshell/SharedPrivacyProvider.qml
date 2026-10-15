pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    PwObjectTracker {
        objects: Pipewire.ready ? [...Pipewire.nodes.values, ...Pipewire.links.values] : []
    }

    // These bindings observe node properties and link states, not a polling timer.
    readonly property var micApps: captureApps(false)
    readonly property var scrApps: captureApps(true)
    readonly property bool micActive: micApps.length > 0
    readonly property bool scrActive: scrApps.length > 0
    property var camApps: []
    readonly property bool camActive: camApps.length > 0
    property bool cameraFailed: false

    function captureApps(screenCapture) {
        if (!Pipewire.ready) return [];
        const nodes = Pipewire.nodes.values;
        const links = Pipewire.links.values;
        const apps = [];
        for (const node of nodes) {
            if (!node || !node.properties) continue;
            const linked = links.some(link => link && link.state === PwLinkState.Active
                && (link.source === node || link.target === node));
            if (!linked) continue;
            const properties = node.properties;
            const mediaClass = properties["media.class"] || "";
            if (screenCapture) {
                if (mediaClass.indexOf("Video") === -1 || mediaClass.indexOf("Audio") >= 0) continue;
                const mediaName = (properties["media.name"] || "").toLowerCase();
                if (!/^(xdph-streaming|gsr-default|game capture|screen|desktop|display|cast|webrtc)/.test(mediaName)
                    && !/screen-cast|screen-capture|desktop-capture|monitor-capture|window-capture|game-capture/.test(mediaName)) continue;
            } else {
                if (!node.isStream || !node.audio || node.isSink || mediaClass !== "Stream/Input/Audio") continue;
                if (properties["stream.capture.sink"] === "true") continue;
            }
            const name = properties["application.name"] || node.nickname || node.name || "";
            if (name && apps.indexOf(name) === -1) apps.push(name);
        }
        return apps;
    }

    // An open camera descriptor is an activity heuristic, not proof of streaming.
    // /proc is scanned once for all non-metadata video devices. Access is limited
    // to processes visible to the shell user.
    Process {
        id: cameraProcess
        command: ["timeout", "3", "sh", Qt.resolvedUrl("shared-camera-users.sh").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector { id: cameraOutput }
        onExited: exitCode => {
            root.cameraFailed = exitCode !== 0;
            if (exitCode === 0)
                root.camApps = cameraOutput.text.trim().split("\n").filter(name => name.length > 0);
        }
    }
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: { if (!cameraProcess.running) cameraProcess.running = true; }
    }
}
