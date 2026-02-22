import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls

// Volume status using WirePlumber/Pipewire. Reactive, no polling.
// Format: <icon> <pct>%
//   󰕾  high (≥67%), 󰖀  mid (≥34%), 󰕿  low (>0%), 󰝟  muted/zero
// Scroll: adjust volume ±5%. Click: toggle mute.
BarPill {
    id: root

    property var sink: Pipewire.defaultAudioSink
    property bool muted: sink?.audio?.muted ?? false
    property real volume: sink?.audio?.volume ?? 0.0

    // Bind the sink so audio properties become available
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function volumeIcon(pct, muted) {
        if (muted || pct === 0) return "󰝟";
        if (pct >= 67) return "󰕾";
        if (pct >= 34) return "󰖀";
        return "󰕿";
    }

    property string volumeText: {
        if (!sink) return "󰝟";
        const pct = Math.round(volume * 100);
        return volumeIcon(pct, muted) + " " + pct + "%";
    }

    property string volumeTooltip: {
        if (!sink) return "No audio sink";
        return (sink?.description || sink?.name || "Unknown sink") + "\n" + Math.round(volume * 100) + "%";
    }

    Text {
        id: label
        text: root.volumeText
        color: root.muted ? "#ff5555" : "#f8f8f2"
        font.pixelSize: 12

        ToolTip.visible: hoverArea.containsMouse
        ToolTip.text: root.volumeTooltip
        ToolTip.delay: 500

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onWheel: event => {
                if (!root.sink || !root.sink.audio) return;
                const delta = event.angleDelta.y > 0 ? 0.05 : -0.05;
                root.sink.audio.volume = Math.max(0.0, Math.min(1.5, root.volume + delta));
            }
            onClicked: {
                if (root.sink && root.sink.audio)
                    root.sink.audio.muted = !root.muted;
            }
        }
    }
}
