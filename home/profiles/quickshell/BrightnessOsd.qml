import Quickshell
import QtQuick

// Each screen owns its OSD and hide timer, but shares brightness monitoring.
Scope {
    id: root

    required property var screen

    readonly property real brightness: BrightnessProvider.brightness
    property bool shown: false

    Connections {
        target: BrightnessProvider
        function onBrightnessChange() {
            root.shown = true;
            hideTimer.restart();
        }
        function onAvailableChanged() {
            if (!BrightnessProvider.available) {
                root.shown = false;
                hideTimer.stop();
            }
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
