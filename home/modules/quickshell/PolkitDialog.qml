import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Polkit authentication agent — OSD-style panel above the bar.
// One instance for the whole session (instantiated once in shell.qml).
//
// Shows fingerprint prompt initially, then shows password field after delay
// or when user starts typing. This allows fingerprint auth to work alongside
// password auth since PAM runs fprintd first.
Item {
    id: root

    // Track if we're in the initial fingerprint-waiting phase
    property bool fingerprintPhase: false

    // Show password field after fingerprint phase ends
    readonly property bool showPasswordField: (agent.flow?.isResponseRequired ?? false) && !fingerprintPhase

    // Timer to give user time to use fingerprint before showing password
    Timer {
        id: fingerprintTimer
        interval: 3000  // 3 seconds to touch fingerprint
        onTriggered: {
            root.fingerprintPhase = false;
        }
    }

    // When agent becomes active, start fingerprint phase
    Connections {
        target: agent
        function onIsActiveChanged() {
            if (agent.isActive) {
                root.fingerprintPhase = true;
                fingerprintTimer.start();
            } else {
                root.fingerprintPhase = false;
                fingerprintTimer.stop();
            }
        }
    }

    // If user presses any key, skip to password mode immediately
    Connections {
        target: panel
        function onActiveFocusItemChanged() {
            // User interacted, switch to password mode
            if (panel.activeFocusItem && root.fingerprintPhase) {
                root.fingerprintPhase = false;
                fingerprintTimer.stop();
            }
        }
    }

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
        implicitHeight: (!root.fingerprintPhase && (agent.flow?.isResponseRequired ?? false)) ? 220 : 180

        Behavior on implicitHeight {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        color: "transparent"
        mask: Region {}

        // Grab keyboard focus when authentication is active.
        HyprlandFocusGrab {
            active: agent.isActive
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
                    // Show fingerprint icon during fingerprint phase, password icon otherwise
                    text: root.fingerprintPhase ? "󰈷" : "󰌋"
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
                        if (root.fingerprintPhase)
                            return "Touch fingerprint sensor\nor type password";
                        if (root.showPasswordField)
                            return agent.flow?.inputPrompt ?? "Enter password";
                        return agent.flow?.message ?? "Authenticating…";
                    }
                    color: (agent.flow?.supplementaryIsError ?? false) ? "#ff5555" : "#8be9fd"
                    font.pixelSize: 12
                    font.family: "SauceCodePro Nerd Font"
                    wrapMode: Text.Wrap
                }

                // ── Password field (visible when not in fingerprint phase) ───────────────────────

                Rectangle {
                    visible: !root.fingerprintPhase && (agent.flow?.isResponseRequired ?? false)
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

                        // Skip fingerprint phase when user starts typing
                        onTextChanged: {
                            if (text.length > 0 && root.fingerprintPhase) {
                                root.fingerprintPhase = false;
                                fingerprintTimer.stop();
                            }
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
                // Always focus password input to capture keystrokes
                passwordInput.forceActiveFocus();
            }
        }

        Connections {
            target: root
            function onFingerprintPhaseChanged() {
                passwordInput.text = "";
                // Focus password input when switching out of fingerprint phase
                if (!root.fingerprintPhase && agent.flow?.isResponseRequired)
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
