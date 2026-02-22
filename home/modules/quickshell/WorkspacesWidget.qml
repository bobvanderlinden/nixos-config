import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Workspace switcher with per-workspace agent activity icon.
RowLayout {
    spacing: 2

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            required property var modelData
            property var workspace: modelData
            // Show agent icon when a state file exists for this workspace ID
            property bool isAgentActive: AgentState.activeWorkspaces[workspace.id] === true

            // Hide special workspaces (scratchpad etc. have negative IDs)
            visible: workspace.id > 0
            implicitWidth: workspace.id > 0 ? 28 : 0
            implicitHeight: 22
            radius: 4

            // Background color based on state
            color: workspace.focused ? "#64727D"
                 : workspace.urgent  ? "#eb4d4b"
                 : workspace.active  ? "#3a3a5c"
                                     : "transparent"

            // Active indicator stripe at bottom (like Waybar)
            Rectangle {
                visible: workspace.focused
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 8
                height: 3
                color: "#ffffff"
                radius: 1.5
            }

            // Workspace label: robot icon when agent active, else workspace number
            Text {
                anchors.centerIn: parent
                text: parent.isAgentActive ? "⚙" : workspace.id.toString()
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
