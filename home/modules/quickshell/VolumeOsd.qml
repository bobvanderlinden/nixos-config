import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Floating volume OSD that appears briefly when volume or mute state changes.
// Shown on every screen that has an active bar. Dismissed after 1.5 s of inactivity.
// Pattern from the official quickshell volume-osd example.
Scope {
    id: root

    required property var screen

    property var sink: Pipewire.defaultAudioSink
    property bool muted: sink?.audio?.muted ?? false
    property real volume: sink?.audio?.volume ?? 0.0

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    property bool visible: false

    // Watch for volume or mute changes
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.show() }
        function onMutedChanged() { root.show() }
    }

    function show() {
        root.visible = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.visible = false
    }

    LazyLoader {
        active: root.visible

        PanelWindow {
            screen: root.screen

            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            // Float above bar (28px) with a gap
            margins.bottom: 44

            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-volume-osd"

            implicitWidth: osdRow.implicitWidth + 32
            implicitHeight: 36
            color: "transparent"
            // Empty click mask so the OSD never blocks mouse events
            mask: Region {}

            Rectangle {
                anchors.centerIn: parent
                implicitWidth: osdRow.implicitWidth + 32
                implicitHeight: 36
                radius: 18
                color: "#cc1e1e2e"
                border.color: "#44475a"
                border.width: 1

                RowLayout {
                    id: osdRow
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: root.muted ? "󰝟" : (root.volume >= 0.67 ? "󰕾" : root.volume >= 0.34 ? "󰖀" : "󰕿")
                        color: root.muted ? "#ff5555" : "#f8f8f2"
                        font.pixelSize: 14
                    }

                    // Track background
                    Rectangle {
                        implicitWidth: 160
                        implicitHeight: 6
                        radius: 3
                        color: "#44475a"

                        // Filled portion
                        Rectangle {
                            width: Math.min(1.0, root.volume) * parent.width
                            height: parent.height
                            radius: parent.radius
                            color: root.muted ? "#ff5555" : "#bd93f9"

                            Behavior on width {
                                NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    Text {
                        text: Math.round(root.volume * 100) + "%"
                        color: root.muted ? "#ff5555" : "#f8f8f2"
                        font.pixelSize: 12
                        // fixed width so OSD doesn't resize as digits change
                        implicitWidth: 34
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
