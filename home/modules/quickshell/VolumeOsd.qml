import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Volume OSD that animates in/out above the bar when volume or mute state changes.
// Delegates rendering to BarOsd (icon + track + percentage).
Scope {
    id: root

    required property var screen

    property var sink: Pipewire.defaultAudioSink
    property bool muted: sink?.audio?.muted ?? false
    property real volume: sink?.audio?.volume ?? 0.0

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    property bool shown: false

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.show() }
        function onMutedChanged() { root.show() }
    }

    function show() {
        root.shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    BarOsd {
        screen: root.screen
        shown: root.shown

        icon: root.muted ? "󰝟"
            : root.volume >= 0.67 ? "󰕾"
            : root.volume >= 0.34 ? "󰖀"
            : "󰕿"
        iconColor: root.muted ? "#ff5555" : "#f8f8f2"
        value: Math.min(1.0, root.volume)
        trackColor: root.muted ? "#ff5555" : "#bd93f9"
        label: Math.round(root.volume * 100) + "%"
    }
}
