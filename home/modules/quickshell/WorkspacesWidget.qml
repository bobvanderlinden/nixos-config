import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Plain workspace switcher. Click to activate, scroll to navigate.
RowLayout {
    spacing: 2

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            required property var modelData
            property var workspace: modelData

            // Hide special workspaces (scratchpad etc. have negative IDs)
            visible: workspace.id > 0
            implicitWidth: workspace.id > 0 ? 28 : 0
            implicitHeight: 22
            radius: 4

            color: workspace.focused ? "#64727D"
                 : workspace.urgent  ? "#eb4d4b"
                                     : "transparent"

            // Active indicator stripe at bottom
            Rectangle {
                visible: workspace.focused
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 8
                height: 3
                color: "#ffffff"
                radius: 1.5
            }

            Text {
                anchors.centerIn: parent
                text: workspace.id.toString()
                color: workspace.focused ? "#ffffff"
                     : workspace.urgent  ? "#ffffff"
                                         : "#aaaaaa"
                font.pixelSize: 12
                font.bold: workspace.focused
            }

            MouseArea {
                anchors.fill: parent
                onClicked: workspace.activate()
                onWheel: event => {
                    if (event.angleDelta.y > 0)
                        Hyprland.dispatch("workspace e-1")
                    else
                        Hyprland.dispatch("workspace e+1")
                }
            }
        }
    }
}
