import Quickshell
import Quickshell.Io
import QtQuick

// hyprwhspr-rs processing OSD — follows the status file written by hyprwhspr-rs.
Scope {
    id: root

    required property var screen

    readonly property string statusDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/hyprwhspr-rs"
    readonly property string statusFile: statusDir + "/status.json"

    property bool shown: false
    property string label: "Recording"
    property real pulseValue: 0.25

    function updateStatus(json) {
        if (json.trim() === "") return;

        try {
            const status = JSON.parse(json);
            // hyprwhspr-rs writes class "active" while recording and
            // "processing" while transcribing — show the OSD for both.
            root.shown = status.class === "active" || status.class === "processing";
            root.label = status.class === "processing" ? "Transcribing" : "Recording";
        } catch (e) {
            root.shown = false;
        }
    }

    Process {
        id: statusReader
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || printf '%s' '{\"class\":\"inactive\",\"tooltip\":\"Not running\"}'", "sh", root.statusFile]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.updateStatus(this.text)
        }
    }

    Process {
        id: watcher
        command: ["sh", "-c",
            "dir=$1; mkdir -p \"$dir\" && exec inotifywait --monitor --event create --event close_write --event moved_to --format %f \"$dir\"",
            "sh", root.statusDir]
        running: true

        stdout: SplitParser {
            onRead: file => {
                if (file.trim() === "status.json") statusReader.running = true;
            }
        }
    }

    SequentialAnimation on pulseValue {
        running: root.shown
        loops: Animation.Infinite

        NumberAnimation { to: 1.0; duration: 850; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.25; duration: 850; easing.type: Easing.InOutSine }
    }

    BarOsd {
        screen: root.screen
        shown: root.shown

        icon: "󰍬"
        iconColor: "#8be9fd"
        value: root.pulseValue
        trackColor: "#8be9fd"
        label: root.label
        labelWidth: 82
    }
}
