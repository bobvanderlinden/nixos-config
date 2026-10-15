import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

// Bluetooth status and paired-device menu backed by BlueZ D-Bus properties.
// Click a paired device to connect or disconnect it. Blueman handles pairing.
PopupWidget {
    id: root

    popupWidth: 280

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property var devices: adapter ? adapter.devices.values.filter(device => device.paired) : []

    function bluetoothIcon() {
        if (!powered) return "󰂲";
        if (devices.some(device => device.connected)) return "󰂱";
        return "󰂯";
    }

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
                        onClicked: {
                            if (root.adapter) root.adapter.enabled = !root.powered;
                        }
                    }
                }

                Text {
                    text: "󰒓"
                    color: "#cdd6f4"
                    font.pixelSize: 14
                    font.family: "SauceCodePro Nerd Font"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsProcess.startDetached()
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
                            visible: modelData.batteryAvailable
                            text: Math.round(modelData.battery * 100) + "%"
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
                        onClicked: modelData.connected = !modelData.connected
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
