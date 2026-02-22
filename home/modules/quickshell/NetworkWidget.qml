import Quickshell.Io
import QtQuick
import QtQuick.Controls

// Network status. Polls nmcli every 10 s.
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22

    property string netText: ""
    property string netTooltip: ""

    // Get the first active (non-loopback) connection's type
    Process {
        id: nmcliConn
        command: ["sh", "-c",
            "nmcli --terse --fields TYPE,DEVICE,CONNECTION device status | grep -v '^loopback\\|^bridge' | head -1"]
        running: true

        property string buf: ""
        stdout: SplitParser {
            onRead: data => nmcliConn.buf += data
        }
        onExited: {
            const line = nmcliConn.buf.trim();
            nmcliConn.buf = "";
            if (line === "") {
                root.netText = "";
                root.netTooltip = "Disconnected";
                return;
            }
            const parts = line.split(":");
            const type = parts[0] ?? "";
            const device = parts[1] ?? "";
            const conn = parts[2] ?? "";

            if (type === "ethernet" || type === "bond") {
                root.netText = "";  // ethernet icon (nerd font)
                root.netTooltip = device + "\n" + conn;
            } else if (type === "wifi") {
                nmcliWifi.running = true;
            } else {
                root.netText = "";
                root.netTooltip = "Disconnected";
            }
        }
    }

    Process {
        id: nmcliWifi
        command: ["sh", "-c",
            "nmcli --terse --fields ACTIVE,SSID,SIGNAL device wifi list | grep '^yes'"]
        running: false

        property string buf: ""
        stdout: SplitParser {
            onRead: data => nmcliWifi.buf += data
        }
        onExited: {
            const line = nmcliWifi.buf.trim();
            nmcliWifi.buf = "";
            if (line === "") {
                root.netText = "";
                root.netTooltip = "Disconnected";
                return;
            }
            const parts = line.split(":");
            const ssid = parts[1] ?? "";
            const signal = parts[2] ?? "";
            root.netText = ssid + "  ";  // wifi icon (nerd font)
            root.netTooltip = ssid + " (" + signal + "%)";
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: nmcliConn.running = true
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.netText
        color: "#f8f8f2"
        font.pixelSize: 12

        ToolTip.visible: hoverArea.containsMouse
        ToolTip.text: root.netTooltip

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
        }
    }
}
