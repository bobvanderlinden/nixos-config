pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Instantiated lazily once, regardless of the number of screen-local OSDs.
Singleton {
    id: root

    property bool available: false
    property string device: ""
    property real brightness: 0
    signal brightnessChange()

    Process {
        id: monitor
        command: ["python3", Quickshell.shellPath("brightness-monitor.py")]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const sample = JSON.parse(line);
                    root.available = sample.available;
                    root.device = sample.device;
                    root.brightness = sample.brightness;
                    if (sample.changed)
                        root.brightnessChange();
                } catch (error) {
                    console.warn("BrightnessProvider: invalid sample:", error);
                }
            }
        }
        onExited: {
            root.available = false;
            root.device = "";
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: monitor.running = true
    }
}
