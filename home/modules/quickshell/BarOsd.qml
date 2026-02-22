import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Reusable OSD pill that animates in/out above the bar.
//
// Usage:
//   BarOsd {
//       screen: modelData
//       shown: root.shouldShow
//
//       icon: "󰕾"
//       iconColor: "#f8f8f2"
//       value: 0.75          // 0.0–1.0 fill fraction
//       trackColor: "#bd93f9"
//       label: "75%"
//   }
Scope {
    id: root

    required property var screen

    // Show/hide
    property bool shown: false

    // Content
    property string icon: ""
    property color iconColor: "#f8f8f2"
    property real value: 0.0          // 0.0–1.0, controls track fill
    property color trackColor: "#bd93f9"
    property string label: ""

    PanelWindow {
        screen: root.screen

        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        margins.bottom: 44

        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"

        implicitWidth: osdRow.implicitWidth + 32
        implicitHeight: 36
        color: "transparent"
        mask: Region {}
        visible: true

        Rectangle {
            anchors.centerIn: parent
            implicitWidth: osdRow.implicitWidth + 32
            implicitHeight: 36
            radius: 18
            color: "#cc1e1e2e"
            border.color: "#44475a"
            border.width: 1

            opacity: root.shown ? 1.0 : 0.0
            scale: root.shown ? 1.0 : 0.9

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            RowLayout {
                id: osdRow
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: root.icon
                    color: root.iconColor
                    font.pixelSize: 14
                    font.family: "SauceCodePro Nerd Font"
                }

                Rectangle {
                    implicitWidth: 160
                    implicitHeight: 6
                    radius: 3
                    color: "#44475a"

                    Rectangle {
                        width: Math.max(0, Math.min(1.0, root.value)) * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: root.trackColor

                        Behavior on width {
                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                        }
                    }
                }

                Text {
                    text: root.label
                    color: "#f8f8f2"
                    font.pixelSize: 12
                    font.family: "SauceCodePro Nerd Font"
                    width: 34
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
