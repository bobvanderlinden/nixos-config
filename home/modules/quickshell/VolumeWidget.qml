import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Volume widget — shows current sink icon + volume %.
// Scroll to adjust ±5%. Click to open popup with:
//   - horizontal volume slider + mute toggle
//   - output device list (sinks)
//   - input device list (sources)
BarPill {
    id: root

    required property var barWindow

    property var sink: Pipewire.preferredDefaultAudioSink
    property var source: Pipewire.preferredDefaultAudioSource
    property bool muted: sink?.audio?.muted ?? false
    property real volume: sink?.audio?.volume ?? 0.0

    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => o != null)
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

    property bool popupShown: false

    // ── Popup ─────────────────────────────────────────────────────────────────
    PopupWindow {
        id: popup
        visible: root.popupShown

        anchor.window: root.barWindow
        anchor.rect: {
            if (!root.barWindow) return Qt.rect(0, 0, 0, 0);
            const mapped = root.mapToItem(root.barWindow.contentItem, 0, 0);
            return Qt.rect(
                mapped.x + root.width / 2 - implicitWidth / 2,
                -implicitHeight - 4,
                implicitWidth,
                1
            );
        }

        implicitWidth: popupColumn.implicitWidth + 24
        implicitHeight: popupColumn.implicitHeight + 24
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 8
            border.color: "#44475a"
            border.width: 1

            // Click outside (on the background) to close
            MouseArea {
                anchors.fill: parent
                onClicked: root.popupShown = false
            }

            ColumnLayout {
                id: popupColumn
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 10

                // ── Volume slider ─────────────────────────────────────────────
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    // Mute toggle icon
                    Text {
                        text: root.muted ? "󰝟"
                            : root.volume >= 0.67 ? "󰕾"
                            : root.volume >= 0.34 ? "󰖀"
                            : "󰕿"
                        color: root.muted ? "#ff5555" : "#cdd6f4"
                        font.pixelSize: 14
                        font.family: "SauceCodePro Nerd Font"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.sink?.audio)
                                    root.sink.audio.muted = !root.muted;
                            }
                        }
                    }

                    // Slider track
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 16

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 4
                            radius: 2
                            color: "#44475a"

                            // Fill
                            Rectangle {
                                width: Math.min(1.0, root.volume) * parent.width
                                height: parent.height
                                radius: parent.radius
                                color: root.muted ? "#ff5555" : "#bd93f9"

                                Behavior on width {
                                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                                }
                            }

                            // Handle
                            Rectangle {
                                x: Math.min(1.0, root.volume) * (track.width - width)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                height: 12
                                radius: 6
                                color: "#cdd6f4"

                                Behavior on x {
                                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => {
                                if (!root.sink?.audio) return;
                                root.sink.audio.volume = Math.max(0.0, Math.min(1.5, mouse.x / width));
                            }
                            onMouseXChanged: {
                                if (!pressed || !root.sink?.audio) return;
                                root.sink.audio.volume = Math.max(0.0, Math.min(1.5, mouseX / width));
                            }
                        }
                    }

                    Text {
                        text: Math.round(root.volume * 100) + "%"
                        color: "#f8f8f2"
                        font.pixelSize: 11
                        font.family: "SauceCodePro Nerd Font"
                        width: 32
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // ── Output devices ────────────────────────────────────────────
                Text {
                    text: "Output"
                    color: "#6272a4"
                    font.pixelSize: 10
                    font.family: "SauceCodePro Nerd Font"
                    font.bold: true
                }

                Repeater {
                    model: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

                    DeviceRow {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitWidth: 220
                        deviceName: modelData.description || modelData.nickname || modelData.name || "Unknown"
                        isDefault: root.sink && modelData.id === root.sink.id
                        onSelectDevice: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }

                // ── Input devices ─────────────────────────────────────────────
                Text {
                    text: "Input"
                    color: "#6272a4"
                    font.pixelSize: 10
                    font.family: "SauceCodePro Nerd Font"
                    font.bold: true
                }

                Repeater {
                    model: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)

                    DeviceRow {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitWidth: 220
                        deviceName: modelData.description || modelData.nickname || modelData.name || "Unknown"
                        isDefault: root.source && modelData.id === root.source.id
                        onSelectDevice: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }
        }
    }

    // ── Bar pill content ──────────────────────────────────────────────────────
    Text {
        id: label
        text: root.volumeText
        color: root.muted ? "#ff5555" : "#f8f8f2"
        font.pixelSize: 12
        font.family: "SauceCodePro Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onWheel: event => {
            if (!root.sink?.audio) return;
            const delta = event.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0.0, Math.min(1.5, root.volume + delta));
        }
        onClicked: root.popupShown = !root.popupShown
    }
}
