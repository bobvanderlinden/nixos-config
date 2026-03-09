import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Polkit authentication agent.
// Listens for privilege escalation requests and shows a password dialog.
// One instance is enough for the whole session (instantiated once in shell.qml).
Item {
    id: root

    // ── Authentication dialog ─────────────────────────────────────────────────

    PanelWindow {
        id: dialog

        // Declarative binding: show whenever polkit has an active request.
        visible: agent.isActive

        // Center on the primary screen.
        screen: Quickshell.screens[0]

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.exclusiveZone: -1

        anchors.top: true
        anchors.left: true
        anchors.right: true

        implicitWidth: 400
        implicitHeight: contentCol.implicitHeight + 48

        color: "transparent"

        // Grab keyboard focus so password can be typed immediately.
        HyprlandFocusGrab {
            active: agent.isActive
            windows: [dialog]
            onCleared: {
                if (agent.flow) agent.flow.cancelAuthenticationRequest();
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 400
            height: contentCol.implicitHeight + 48
            radius: 12
            color: "#1e1e2e"
            border.color: "#44475a"
            border.width: 1

            // Error shake animation
            SequentialAnimation {
                id: shakeBackground
                property real shakeX: 0
                running: agent.flow && agent.flow.failed
                loops: 1
                NumberAnimation { target: shakeBackground; property: "shakeX"; from: 0;   to: -8; duration: 50 }
                NumberAnimation { target: shakeBackground; property: "shakeX"; from: -8;  to:  8; duration: 50 }
                NumberAnimation { target: shakeBackground; property: "shakeX"; from:  8;  to: -8; duration: 50 }
                NumberAnimation { target: shakeBackground; property: "shakeX"; from: -8;  to:  8; duration: 50 }
                NumberAnimation { target: shakeBackground; property: "shakeX"; from:  8;  to:  0; duration: 50 }
            }
            transform: Translate { x: shakeBackground.shakeX }

            ColumnLayout {
                id: contentCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 24
                }
                spacing: 12

                // Header
                RowLayout {
                    spacing: 12
                    Layout.fillWidth: true

                    // Lock icon
                    Text {
                        text: "󰌆"
                        font.pixelSize: 28
                        font.family: "SauceCodePro Nerd Font"
                        color: "#bd93f9"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: agent.flow?.message ?? "Authentication Required"
                            color: "#f8f8f2"
                            font.pixelSize: 14
                            font.bold: true
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: (agent.flow?.actionId ?? "") !== ""
                            text: agent.flow?.actionId ?? ""
                            color: "#6272a4"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // Supplementary message (error or prompt from agent)
                Text {
                    visible: (agent.flow?.supplementaryMessage ?? "") !== ""
                    text: agent.flow?.supplementaryMessage ?? ""
                    color: (agent.flow?.supplementaryIsError ?? false) ? "#ff5555" : "#6272a4"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                // Password input
                Rectangle {
                    visible: agent.flow?.isResponseRequired ?? false
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 6
                    color: "#313244"
                    border.color: passwordInput.activeFocus
                        ? ((agent.flow?.failed ?? false) ? "#ff5555" : "#bd93f9")
                        : "#44475a"
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    TextInput {
                        id: passwordInput
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: (agent.flow?.responseVisible ?? false)
                            ? TextInput.Normal
                            : TextInput.Password
                        color: "#f8f8f2"
                        font.pixelSize: 13
                        font.family: "SauceCodePro Nerd Font"
                        selectionColor: "#44475a"

                        // Submit on Enter
                        Keys.onReturnPressed: submitPassword()
                        Keys.onEnterPressed: submitPassword()
                        Keys.onEscapePressed: {
                            if (agent.flow) agent.flow.cancelAuthenticationRequest();
                        }
                    }

                    // Placeholder
                    Text {
                        anchors {
                            fill: parent
                            leftMargin: 10
                        }
                        verticalAlignment: Text.AlignVCenter
                        text: agent.flow?.inputPrompt ?? "Password"
                        color: "#44475a"
                        font.pixelSize: 13
                        font.family: "SauceCodePro Nerd Font"
                        visible: passwordInput.text === "" && !passwordInput.activeFocus
                    }
                }

                // Action buttons
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 0
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    // Cancel
                    Rectangle {
                        implicitWidth: cancelLabel.implicitWidth + 24
                        implicitHeight: 32
                        radius: 6
                        color: cancelHover.hovered ? "#44475a" : "#313244"
                        border.color: "#44475a"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 100 } }

                        HoverHandler { id: cancelHover }

                        Text {
                            id: cancelLabel
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: "#f8f8f2"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (agent.flow) agent.flow.cancelAuthenticationRequest();
                            }
                        }
                    }

                    // Authenticate
                    Rectangle {
                        implicitWidth: authLabel.implicitWidth + 24
                        implicitHeight: 32
                        radius: 6
                        color: authHover.hovered ? "#a070e0" : "#bd93f9"
                        enabled: agent.flow?.isResponseRequired ?? false

                        Behavior on color { ColorAnimation { duration: 100 } }

                        HoverHandler { id: authHover }

                        Text {
                            id: authLabel
                            anchors.centerIn: parent
                            text: "Authenticate"
                            color: "#1e1e2e"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: submitPassword()
                        }
                    }
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                passwordInput.text = "";
                passwordInput.forceActiveFocus();
            }
        }

        // Reset password field when flow changes (new auth request after failure)
        Connections {
            target: agent.flow
            enabled: agent.flow !== null
            function onIsResponseRequiredChanged() {
                passwordInput.text = "";
                if (agent.flow?.isResponseRequired) {
                    passwordInput.forceActiveFocus();
                }
            }
        }
    }

    PolkitAgent {
        id: agent
    }

    function submitPassword() {
        if (!agent.flow) return;
        agent.flow.submit(passwordInput.text);
        passwordInput.text = "";
    }
}
