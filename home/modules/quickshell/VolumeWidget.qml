import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls

// Volume status using WirePlumber/Pipewire.
// Uses the default audio sink (output device).
// PwObjectTracker is required to bind the sink so that audio.volume/muted are usable.
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22

    property var sink: Pipewire.defaultAudioSink
    property bool muted: sink && sink.audio ? sink.audio.muted : false
    property real volume: sink && sink.audio ? sink.audio.volume : 0.0

    // Bind the sink so audio properties become available
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    property string volumeText: {
        if (!sink) return "🔇";
        if (muted) return "🔇";
        const pct = Math.round(volume * 100);
        if (pct >= 67) return pct + "% 🔊";
        if (pct >= 34) return pct + "% 🔉";
        if (pct > 0)   return pct + "% 🔈";
        return "0% 🔇";
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.volumeText
        color: "#f8f8f2"
        font.pixelSize: 12

        MouseArea {
            anchors.fill: parent
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
