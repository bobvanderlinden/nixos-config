import Quickshell.Networking
import QtQuick

// Network status. Reactive via Quickshell.Networking (no polling).
// Format: <icon>  <label>
//   wifi:     󰤨 / 󰤥 / 󰤢 / 󰤟 / 󰤯  + SSID
//   ethernet: 󰈀  + device name
//   none:     󰤭
//
// Uses Instantiator to reactively bind to each NetworkDevice and Network
// object, so changes to dev.connected / net.connected trigger re-evaluation
// without relying on JS for-loops (which don't establish QML bindings).
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22

    required property var barWindow

    function wifiIcon(strength) {
        const pct = strength * 100;
        if (pct >= 80) return "󰤨";
        if (pct >= 60) return "󰤥";
        if (pct >= 40) return "󰤢";
        if (pct >= 20) return "󰤟";
        return "󰤯";
    }

    // Each DeviceBinding tracks one NetworkDevice reactively.
    Instantiator {
        id: deviceInstantiator
        model: Networking.devices

        delegate: QtObject {
            required property var modelData

            property var networkInst: Instantiator {
                model: modelData.type === DeviceType.Wifi ? modelData.networks : null

                delegate: QtObject {
                    required property var modelData
                }
            }

            property var connectedNet: {
                if (modelData.type !== DeviceType.Wifi) return null;
                for (let i = 0; i < networkInst.count; i++) {
                    const obj = networkInst.objectAt(i);
                    if (obj && obj.modelData && obj.modelData.connected) return obj.modelData;
                }
                return null;
            }

            property string displayText: {
                if (!modelData.connected) return "";
                if (modelData.type === DeviceType.Wifi) {
                    const net = connectedNet;
                    if (!net) return "";
                    return root.wifiIcon(net.signalStrength) + "  " + net.name;
                }
                if (modelData.type === DeviceType.Ethernet) {
                    return "󰈀  " + modelData.name;
                }
                return "";
            }

            property string displayTooltip: {
                if (!modelData.connected) return "";
                if (modelData.type === DeviceType.Wifi) {
                    const net = connectedNet;
                    if (!net) return "";
                    return net.name + " (" + Math.round(net.signalStrength * 100) + "%)";
                }
                if (modelData.type === DeviceType.Ethernet) {
                    return "Ethernet: " + modelData.name;
                }
                return "";
            }
        }
    }

    property string netText: {
        for (let i = 0; i < deviceInstantiator.count; i++) {
            const obj = deviceInstantiator.objectAt(i);
            if (obj && obj.displayText !== "") return obj.displayText;
        }
        return "󰤭";
    }

    property string netTooltip: {
        for (let i = 0; i < deviceInstantiator.count; i++) {
            const obj = deviceInstantiator.objectAt(i);
            if (obj && obj.displayTooltip !== "") return obj.displayTooltip;
        }
        return "Disconnected";
    }

    property bool disconnected: netText === "󰤭"

    BarTooltip {
        id: tooltip
        barWindow: root.barWindow
        text: root.netTooltip
        shown: hoverHandler.hovered
    }

    Rectangle {
        anchors.fill: parent
        color: "#252535"
        radius: 4

        Text {
            id: label
            anchors.centerIn: parent
            text: root.netText
            color: root.disconnected ? "#6272a4" : "#f8f8f2"
            font.pixelSize: 12
            font.family: "SauceCodePro Nerd Font"
        }

        HoverHandler {
            id: hoverHandler
        }
    }
}
