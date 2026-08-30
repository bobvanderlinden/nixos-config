import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Plain workspace switcher. Click to activate, scroll to navigate.
// Wrapped in a subtle pill background matching the other bar widgets.
Item {
    id: root

    property var barWindow: null
    readonly property int notificationPopupWidth: 360

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 22

    function normalizedWindowAddress(windowAddress) {
        if (windowAddress === null || windowAddress === undefined || windowAddress === "") return "";
        const address = windowAddress.toString();
        return address.startsWith("0x") ? address.slice(2) : address;
    }

    function agentLabel(session) {
        return session?.label || session?.title || "";
    }

    function workspaceMostRecentAgent(workspaceId) {
        let mostRecentSession = null;
        for (const session of AgentState.sessions) {
            const windowAddress = normalizedWindowAddress(session.windowAddress);
            const toplevel = Hyprland.toplevels.values.find(item => item.address === windowAddress);
            if (toplevel?.workspace?.id !== workspaceId) continue;
            if (!mostRecentSession || session.updatedAt > mostRecentSession.updatedAt) {
                mostRecentSession = session;
            }
        }
        return mostRecentSession;
    }

    function workspaceIdForWindowAddress(windowAddress) {
        const address = normalizedWindowAddress(windowAddress);
        return Hyprland.toplevels.values.find(item => item.address === address)?.workspace?.id ?? null;
    }

    function workspaceHasNotification(workspaceId) {
        return NotificationService.notifications.some(notification =>
            workspaceIdForWindowAddress(notification.windowAddress) === workspaceId,
        );
    }

    function workspaceItemForWindowAddress(windowAddress) {
        const workspaceId = workspaceIdForWindowAddress(windowAddress);
        for (let index = 0; index < workspaceRepeater.count; index += 1) {
            const item = workspaceRepeater.itemAt(index);
            if (item?.workspace?.id === workspaceId) return item;
        }
        return null;
    }

    function notificationStackIndex(notification) {
        const workspaceId = workspaceIdForWindowAddress(notification.windowAddress);
        return NotificationService.notifications
            .slice(0, NotificationService.notifications.indexOf(notification))
            .filter(item => workspaceIdForWindowAddress(item.windowAddress) === workspaceId)
            .length;
    }

    Rectangle {
        anchors.fill: parent
        color: "#252535"
        radius: 4
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

    Repeater {
        id: workspaceRepeater
        model: Hyprland.workspaces

        delegate: Rectangle {
            required property var modelData
            property var workspace: modelData

            // Hide special workspaces (scratchpad etc. have negative IDs)
            visible: workspace.id > 0
            property bool hasNotification: root.workspaceHasNotification(workspace.id)
            property var mostRecentAgent: root.workspaceMostRecentAgent(workspace.id)
            property string agentText: root.agentLabel(mostRecentAgent)
            implicitWidth: workspace.id > 0
                ? (hasNotification ? root.notificationPopupWidth : (agentText !== "" ? 160 : 28))
                : 0
            implicitHeight: 22
            radius: 4

            color: workspace.focused ? "#64727D"
                 : workspace.urgent  ? "#eb4d4b"
                                     : "transparent"

            // Active workspace stripe.
            Rectangle {
                visible: workspace.focused
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 8
                height: 3
                color: "#ffffff"
                radius: 1.5
            }

            // An agent belongs to this workspace via its Hyprland window.
            Rectangle {
                property string agentState: mostRecentAgent ? AgentState.colorState(mostRecentAgent) : ""
                visible: agentState !== ""
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 3
                anchors.rightMargin: 3
                width: 6
                height: 6
                radius: 3
                color: AgentState.stateColor(agentState)
            }

            // hypr-notify attaches its source window address as a D-Bus hint.
            Rectangle {
                visible: root.workspaceHasNotification(workspace.id)
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 3
                anchors.leftMargin: 3
                width: 6
                height: 6
                radius: 3
                color: "#bd93f9"
            }

            RowLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 8
                    rightMargin: 8
                }
                spacing: 6

                Text {
                    text: workspace.id.toString()
                    color: workspace.focused ? "#ffffff"
                         : workspace.urgent  ? "#ffffff"
                                             : "#aaaaaa"
                    font.pixelSize: 12
                    font.bold: workspace.focused
                }

                Text {
                    Layout.fillWidth: true
                    visible: agentText !== ""
                    text: agentText
                    color: AgentState.stateColor(mostRecentAgent ? AgentState.colorState(mostRecentAgent) : "idle")
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
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

    Instantiator {
        model: NotificationService.notifications.filter(notification => notification.windowAddress !== "")

        delegate: WorkspaceNotificationPopup {
            required property var modelData
            barWindow: root.barWindow
            notification: modelData
            workspaceItem: root.workspaceItemForWindowAddress(modelData.windowAddress)
            stackIndex: root.notificationStackIndex(modelData)
        }
    }
}
