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
BarPill {
    id: root

    required property var barWindow

    function wifiIcon(strength) {
        // strength is 0.0–1.0
        const pct = strength * 100;
        if (pct >= 80) return "󰤨";
        if (pct >= 60) return "󰤥";
        if (pct >= 40) return "󰤢";
        if (pct >= 20) return "󰤟";
        return "󰤯";
    }

    // Each DeviceBinding tracks one NetworkDevice reactively.
    // When its device is connected, it exposes text/tooltip for the label.
    Instantiator {
        id: deviceInstantiator
        model: Networking.devices

        delegate: QtObject {
            required property var modelData  // the NetworkDevice

            // For wifi devices, instantiate per-network bindings
            property var networkInst: Instantiator {
                model: modelData.type === DeviceType.Wifi ? modelData.networks : null

                delegate: QtObject {
                    required property var modelData  // the Network (actually WifiNetwork)
                }
            }

            // Find the connected wifi network reactively
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

    // Pick the first device binding that has a non-empty displayText
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
        barWindow: root.barWindow
        widget: root
        text: root.netTooltip
        shown: hoverHandler.hovered
    }

    Text {
        id: label
        text: root.netText
        color: root.disconnected ? "#6272a4" : "#f8f8f2"
        font.pixelSize: 12
        font.family: "SauceCodePro Nerd Font"
    }

    HoverHandler {
        id: hoverHandler
    }
}
