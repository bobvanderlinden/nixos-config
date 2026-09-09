import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Privacy indicator — shows icons when microphone, camera, or screen sharing is active.
// Hidden entirely when nothing is active.
// Hover to see a tooltip listing which apps are using each resource.
BarPill {
    id: root

    required property var barWindow

    // ── Pipewire state ────────────────────────────────────────────────────────

    PwObjectTracker {
        objects: Pipewire.ready ? Pipewire.nodes.values : []
    }

    property bool micActive: false
    property bool scrActive: false
    property var micApps: []
    property var scrApps: []

    // Camera detection runs as a shell command every second (no Pipewire API for this).
    property bool camActive: false
    property var camApps: []

    Process {
        id: cameraProcess
        command: [
            "sh", "-c",
            "for dev in /sys/class/video4linux/video*; do " +
            "  [ -e \"$dev/name\" ] && grep -qv 'Metadata' \"$dev/name\" && " +
            "  dev_name=$(basename \"$dev\") && " +
            "  find /proc/[0-9]*/fd -lname \"/dev/$dev_name\" 2>/dev/null; " +
            "done | cut -d/ -f3 | xargs -r ps -o comm= -p | sort -u | tr '\\n' ',' | sed 's/,$//'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim();
                root.camApps = text.length > 0 ? text.split(",") : [];
                root.camActive = root.camApps.length > 0;
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.updateMicState();
            root.updateScrState();
            cameraProcess.running = true;
        }
    }

    function hasLinks(node, links) {
        for (var i = 0; i < links.length; i++) {
            var link = links[i];
            if (link && (link.source === node || link.target === node)) return true;
        }
        return false;
    }

    function appName(node) {
        return node.properties["application.name"] || node.nickname || node.name || "";
    }

    function updateMicState() {
        if (!Pipewire.ready) return;
        var nodes = Pipewire.nodes.values;
        var links = Pipewire.links.values;
        var apps = [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            if (!node || !node.isStream || !node.audio || node.isSink) continue;
            if (!hasLinks(node, links) || !node.properties) continue;
            if ((node.properties["media.class"] || "") !== "Stream/Input/Audio") continue;
            if (node.properties["stream.capture.sink"] === "true") continue;
            var name = appName(node);
            if (name && apps.indexOf(name) === -1) apps.push(name);
        }
        root.micActive = apps.length > 0;
        root.micApps = apps;
    }

    function updateScrState() {
        if (!Pipewire.ready) return;
        var nodes = Pipewire.nodes.values;
        var links = Pipewire.links.values;
        var apps = [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            if (!node || !hasLinks(node, links) || !node.properties) continue;
            var mediaClass = node.properties["media.class"] || "";
            if (mediaClass.indexOf("Audio") >= 0 || mediaClass.indexOf("Video") === -1) continue;
            var mediaName = (node.properties["media.name"] || "").toLowerCase();
            var isScreenShare = mediaName.match(/^(xdph-streaming|gsr-default|game capture|screen|desktop|display|cast|webrtc|v4l2)/) ||
                mediaName.match(/screen-cast|screen-capture|desktop-capture|monitor-capture|window-capture|game-capture/i);
            if (!isScreenShare) continue;
            var name = appName(node);
            if (name && apps.indexOf(name) === -1) apps.push(name);
        }
        root.scrActive = apps.length > 0;
        root.scrApps = apps;
    }

    // ── Visibility ────────────────────────────────────────────────────────────

    visible: micActive || camActive || scrActive

    // ── Bar pill content ──────────────────────────────────────────────────────

    RowLayout {
        spacing: 4

        Text {
            visible: root.micActive
            text: "󰍬"
            color: "#ff5555"
            font.pixelSize: 13
            font.family: "SauceCodePro Nerd Font"
        }

        Text {
            visible: root.camActive
            text: "󰄀"
            color: "#ff5555"
            font.pixelSize: 13
            font.family: "SauceCodePro Nerd Font"
        }

        Text {
            visible: root.scrActive
            text: "󱍊"
            color: "#ff5555"
            font.pixelSize: 13
            font.family: "SauceCodePro Nerd Font"
        }
    }

    // ── Tooltip ───────────────────────────────────────────────────────────────

    BarTooltip {
        id: tooltip
        barWindow: root.barWindow
        widget: root
        shown: hoverHandler.hovered
        text: {
            var parts = [];
            if (root.micActive)
                parts.push("Mic: " + (root.micApps.length > 0 ? root.micApps.join(", ") : "active"));
            if (root.camActive)
                parts.push("Camera: " + (root.camApps.length > 0 ? root.camApps.join(", ") : "active"));
            if (root.scrActive)
                parts.push("Screen share: " + (root.scrApps.length > 0 ? root.scrApps.join(", ") : "active"));
            return parts.join("\n");
        }
    }

    HoverHandler {
        id: hoverHandler
    }
}
