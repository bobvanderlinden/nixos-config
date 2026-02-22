import Quickshell
import Quickshell.Io
import QtQuick

// Brightness OSD — appears briefly when screen brightness changes.
Scope {
    id: root

    required property var screen

    readonly property string backlightPath: "/sys/class/backlight/intel_backlight/"

    property real brightness: 0.0
    property real maxBrightness: 1.0
    property bool shouldShowOsd: false

    FileView {
        id: maxFile
        path: root.backlightPath + "max_brightness"
        blockLoading: true
        onLoaded: root.maxBrightness = parseFloat(maxFile.text()) || 1.0
    }

    FileView {
        id: brightnessFile
        path: root.backlightPath + "brightness"
        watchChanges: true
        onLoaded: root.brightness = parseFloat(brightnessFile.text()) / root.maxBrightness
        onFileChanged: {
            reload();
            root.brightness = parseFloat(brightnessFile.text()) / root.maxBrightness;
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shouldShowOsd = false
    }

    BarOsd {
        screen: root.screen
        shown: root.shouldShowOsd

        icon: root.brightness >= 0.67 ? "󰃠"
            : root.brightness >= 0.34 ? "󰃟"
            : "󰃞"
        value: root.brightness
        trackColor: "#f1fa8c"
        label: Math.round(root.brightness * 100) + "%"
    }
}
