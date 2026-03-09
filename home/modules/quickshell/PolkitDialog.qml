import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Polkit authentication agent — OSD-style panel above the bar.
// One instance for the whole session (instantiated once in shell.qml).
//
// Two modes driven by flow.isResponseRequired:
//   false — fingerprint / waiting: big icon + message, no input
//   true  — password prompt:       icon + prompt + password field
Item {
    id: root

    PanelWindow {
        id: panel

        visible: agent.isActive

        screen: Quickshell.screens[0]

        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        margins.bottom: 44

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.exclusiveZone: 0

        // Square-ish: fixed 200×200, grows to 200×260 when password field shown.
        implicitWidth: 200
        implicitHeight: (agent.flow?.isResponseRequired ?? false) ? 220 : 180

        Behavior on implicitHeight {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        color: "transparent"
        mask: Region {}

        // Grab keyboard focus when a password is needed.
        HyprlandFocusGrab {
            active: agent.flow?.isResponseRequired ?? false
            windows: [panel]
            onCleared: {
                if (agent.flow) agent.flow.cancelAuthenticationRequest();
            }
        }

        // ── OSD card ─────────────────────────────────────────────────────────

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: panel.implicitWidth
            height: panel.implicitHeight
            radius: 16
            color: "#cc1e1e2e"
            border.color: "#44475a"
            border.width: 1

            opacity: agent.isActive ? 1.0 : 0.0
            scale: agent.isActive ? 1.0 : 0.88

            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            // Shake on authentication failure
            SequentialAnimation {
                id: shakeAnimation
                property real shakeX: 0
                running: agent.flow?.failed ?? false
                loops: 1
                NumberAnimation { target: shakeAnimation; property: "shakeX"; from: 0;  to: -8; duration: 50 }
                NumberAnimation { target: shakeAnimation; property: "shakeX"; from: -8; to:  8; duration: 50 }
                NumberAnimation { target: shakeAnimation; property: "shakeX"; from:  8; to: -8; duration: 50 }
                NumberAnimation { target: shakeAnimation; property: "shakeX"; from: -8; to:  8; duration: 50 }
                NumberAnimation { target: shakeAnimation; property: "shakeX"; from:  8; to:  0; duration: 50 }
            }
            transform: Translate { x: shakeAnimation.shakeX }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 12

                // ── Icon ─────────────────────────────────────────────────────

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (agent.flow?.isResponseRequired ?? false) ? "󰌋" : "󰈷"
                    font.pixelSize: 48
                    font.family: "SauceCodePro Nerd Font"
                    color: (agent.flow?.failed ?? false) ? "#ff5555" : "#bd93f9"

                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // ── Message ───────────────────────────────────────────────────

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (agent.flow?.supplementaryMessage ?? "" !== "")
                            return agent.flow.supplementaryMessage;
                        if (agent.flow?.isResponseRequired ?? false)
                            return agent.flow?.inputPrompt ?? "Enter password";
                        return agent.flow?.message ?? "Authenticating…";
                    }
                    color: (agent.flow?.supplementaryIsError ?? false) ? "#ff5555" : "#8be9fd"
                    font.pixelSize: 12
                    font.family: "SauceCodePro Nerd Font"
                    wrapMode: Text.Wrap
                }

                // ── Password field (password mode only) ───────────────────────

                Rectangle {
                    visible: agent.flow?.isResponseRequired ?? false
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 8
                    color: "#313244"
                    border.color: passwordInput.activeFocus
                        ? ((agent.flow?.failed ?? false) ? "#ff5555" : "#bd93f9")
                        : "#44475a"
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    TextInput {
                        id: passwordInput
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: (agent.flow?.responseVisible ?? false)
                            ? TextInput.Normal : TextInput.Password
                        color: "#f8f8f2"
                        font.pixelSize: 13
                        font.family: "SauceCodePro Nerd Font"
                        selectionColor: "#44475a"

                        Keys.onReturnPressed: submitPassword()
                        Keys.onEnterPressed:  submitPassword()
                        Keys.onEscapePressed: {
                            if (agent.flow) agent.flow.cancelAuthenticationRequest();
                        }
                    }

                    // Placeholder text
                    Text {
                        anchors { fill: parent; leftMargin: 10 }
                        verticalAlignment: Text.AlignVCenter
                        text: agent.flow?.inputPrompt ?? "Password"
                        color: "#6272a4"
                        font.pixelSize: 13
                        font.family: "SauceCodePro Nerd Font"
                        visible: passwordInput.text === "" && !passwordInput.activeFocus
                    }
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                passwordInput.text = "";
                if (agent.flow?.isResponseRequired ?? false)
                    passwordInput.forceActiveFocus();
            }
        }

        Connections {
            target: agent.flow
            enabled: agent.flow !== null
            function onIsResponseRequiredChanged() {
                passwordInput.text = "";
                if (agent.flow?.isResponseRequired)
                    passwordInput.forceActiveFocus();
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
