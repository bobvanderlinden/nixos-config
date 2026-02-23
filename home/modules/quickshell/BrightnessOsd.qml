import Quickshell
import Quickshell.Io
import QtQuick

// Brightness OSD — appears briefly when screen brightness changes.
// Uses inotifywait to watch the sysfs brightness file for changes.
Scope {
    id: root

    required property var screen

    readonly property string backlightDir: "/sys/class/backlight/intel_backlight"

    property real brightness: 0.0
    property bool shown: false

    // Read max_brightness once at startup
    Process {
        id: maxReader
        command: ["cat", root.backlightDir + "/max_brightness"]
        running: true
        property real maxBrightness: 96000

        stdout: SplitParser {
            onRead: line => {
                const val = parseFloat(line.trim());
                if (val > 0) maxReader.maxBrightness = val;
                // Now read current brightness
                brightnessReader.running = true;
            }
        }
    }

    // Read current brightness on demand
    Process {
        id: brightnessReader
        command: ["cat", root.backlightDir + "/brightness"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                const val = parseFloat(line.trim());
                if (val >= 0) {
                    root.brightness = val / maxReader.maxBrightness;
                    root.shown = true;
                    hideTimer.restart();
                }
            }
        }
    }

    // Watch for brightness file changes with inotifywait
    Process {
        id: watcher
        command: ["inotifywait", "--monitor", "--event", "modify",
                  "--format", "%e",
                  root.backlightDir + "/brightness"]
        running: true

        stdout: SplitParser {
            onRead: _ => brightnessReader.running = true
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    BarOsd {
        screen: root.screen
        shown: root.shown

        icon: root.brightness >= 0.67 ? "󰃠"
            : root.brightness >= 0.34 ? "󰃟"
            : "󰃞"
        value: root.brightness
        trackColor: "#f1fa8c"
        label: Math.round(root.brightness * 100) + "%"
    }
}
