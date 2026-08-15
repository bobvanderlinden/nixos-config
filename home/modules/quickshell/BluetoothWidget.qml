import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Bluetooth status and paired-device menu. State is read from bluetoothctl so
// it remains usable without a tray applet. Click a paired device to connect or
// disconnect it; the settings entry opens Blueman for pairing and discovery.
PopupWidget {
    id: root

    popupWidth: 280

    property bool powered: false
    property var devices: []

    function bluetoothIcon() {
        if (!powered) return "󰂲";
        if (devices.some(device => device.connected)) return "󰂱";
        return "󰂯";
    }

    function refresh() {
        controllerProcess.exec(controllerProcess.command);
        devicesProcess.exec(devicesProcess.command);
    }

    function runAction(arguments) {
        actionProcess.exec(["bluetoothctl", ...arguments]);
        refreshTimer.restart();
    }

    function parseDevices(output) {
        const parsedDevices = [];
        for (const line of output.trim().split("\n")) {
            if (!line) continue;
            const [address, connected, battery, ...nameParts] = line.split("\t");
            if (!address || !nameParts.length) continue;
            parsedDevices.push({
                address: address,
                connected: connected === "yes",
                battery: battery === "" ? -1 : Number(battery),
                name: nameParts.join("\t")
            });
        }
        root.devices = parsedDevices;
    }

    Process {
        id: controllerProcess
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.powered = /^\s*Powered:\s*yes\s*$/m.test(text)
        }
    }

    // Emit one tab-separated record for every paired device. Names are retained
    // verbatim, while the device address is the only value passed back to BlueZ.
    Process {
        id: devicesProcess
        command: ["sh", "-c", `
            bluetoothctl devices Paired | while IFS=' ' read -r _ address name; do
                info="$(bluetoothctl info "$address")"
                connected="$(printf '%s\\n' "$info" | awk '/^[[:space:]]*Connected:/ { print $2; exit }')"
                battery="$(printf '%s\\n' "$info" | sed -n 's/^[[:space:]]*Battery Percentage:.*(\\([0-9][0-9]*\\)%%).*/\\1/p')"
                printf '%s\\t%s\\t%s\\t%s\\n' "$address" "$connected" "$battery" "$name"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: root.parseDevices(text)
        }
    }

    Process {
        id: actionProcess
        onExited: refreshTimer.restart()
    }

    // BlueZ emits changes here for actions performed outside the bar too.
    Process {
        id: monitorProcess
        running: true
        command: ["bluetoothctl", "monitor"]
        stdout: SplitParser {
            onRead: refreshTimer.restart()
        }
        onExited: monitorRestartTimer.start()
    }

    Timer {
        id: monitorRestartTimer
        interval: 2000
        onTriggered: monitorProcess.running = true
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    pillContent: Component {
        Text {
            text: root.bluetoothIcon()
            color: !root.powered ? "#6272a4" : root.devices.some(device => device.connected) ? "#89b4fa" : "#f8f8f2"
            font.pixelSize: 13
            font.family: "SauceCodePro Nerd Font"
        }
    }

    popupContent: Component {
        ColumnLayout {
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Bluetooth"
                    color: "#6272a4"
                    font.pixelSize: 10
                    font.family: "SauceCodePro Nerd Font"
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 14
                    radius: height / 2
                    color: root.powered ? "#89b4fa" : "#44475a"

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.powered ? parent.width - width - 2 : 2
                        width: 10
                        height: 10
                        radius: width / 2
                        color: "#1e1e2e"

                        Behavior on x { NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runAction(["power", root.powered ? "off" : "on"])
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#44475a" }

            Repeater {
                model: root.devices

                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitWidth: 240
                    implicitHeight: 30
                    enabled: root.powered

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: modelData.connected ? "#313244" : deviceHover.containsMouse ? "#2a2a3c" : "transparent"
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        spacing: 6

                        Text {
                            text: "󰂯"
                            color: modelData.connected ? "#89b4fa" : "#cdd6f4"
                            font.pixelSize: 13
                            font.family: "SauceCodePro Nerd Font"
                        }

                        Text {
                            text: modelData.name
                            color: modelData.connected ? "#f8f8f2" : "#cdd6f4"
                            font.pixelSize: 12
                            font.family: "SauceCodePro Nerd Font"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: modelData.battery >= 0
                            text: modelData.battery + "%"
                            color: "#6272a4"
                            font.pixelSize: 10
                            font.family: "SauceCodePro Nerd Font"
                        }

                        Text {
                            text: modelData.connected ? "󰄴" : ""
                            color: "#89b4fa"
                            font.pixelSize: 11
                            font.family: "SauceCodePro Nerd Font"
                        }
                    }

                    MouseArea {
                        id: deviceHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.runAction([modelData.connected ? "disconnect" : "connect", modelData.address])
                    }
                }
            }

            Text {
                visible: root.powered && root.devices.length === 0
                text: "No paired devices"
                color: "#6272a4"
                font.pixelSize: 11
                font.family: "SauceCodePro Nerd Font"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                visible: !root.powered
                text: "Turn Bluetooth on to manage devices"
                color: "#6272a4"
                font.pixelSize: 11
                font.family: "SauceCodePro Nerd Font"
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#44475a" }

            Text {
                text: "Open Bluetooth settings"
                color: "#cdd6f4"
                font.pixelSize: 11
                font.family: "SauceCodePro Nerd Font"
                Layout.alignment: Qt.AlignRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsProcess.startDetached()
                }
            }
        }
    }

    Process {
        id: settingsProcess
        command: ["blueman-manager"]
    }

    BarTooltip {
        barWindow: root.barWindow
        widget: root
        text: {
            if (!root.powered) return "Bluetooth off";
            const connected = root.devices.filter(device => device.connected);
            if (connected.length === 0) return "Bluetooth on";
            return connected.map(device => device.name).join(", ");
        }
        shown: hoverHandler.hovered && !root.popupOpen
    }

    HoverHandler { id: hoverHandler }
}
