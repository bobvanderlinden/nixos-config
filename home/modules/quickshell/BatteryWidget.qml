import Quickshell.Services.UPower
import QtQuick

// Battery status using UPower displayDevice.
// Format: [󱐋] <icon> <pct>%   (charging prefix + icon, or just icon when full)
// Hovering shows a tooltip via BarTooltip.
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22

    required property var barWindow

    property var dev: UPower.displayDevice

    function batteryIcon(pct, charging) {
        if (charging) {
            if (pct >= 90) return "";
            if (pct >= 70) return "";
            if (pct >= 50) return "";
            if (pct >= 25) return "";
            return "";
        }
        if (pct >= 90) return "";
        if (pct >= 70) return "";
        if (pct >= 50) return "";
        if (pct >= 25) return "";
        return "";
    }

    property string batteryText: {
        if (!dev || !dev.ready) return "";
        const pct = Math.round(dev.percentage * 100);
        const charging = dev.state === UPowerDeviceState.Charging;
        const full = dev.state === UPowerDeviceState.FullyCharged;
        const icon = batteryIcon(pct, charging);
        if (full) return icon;
        if (charging) return "󱐋 " + icon + " " + pct + "%";
        return icon + " " + pct + "%";
    }

    property string batteryTooltip: {
        if (!dev || !dev.ready) return "";
        const pct = Math.round(dev.percentage * 100);
        return pct + "% (" + UPowerDeviceState.toString(dev.state) + ")";
    }

    property bool lowBattery: dev && dev.ready
        && dev.state !== UPowerDeviceState.Charging
        && dev.state !== UPowerDeviceState.FullyCharged
        && dev.percentage < 0.2

    BarTooltip {
        id: tooltip
        barWindow: root.barWindow
        text: root.batteryTooltip
        shown: hoverHandler.hovered
    }

    Rectangle {
        anchors.fill: parent
        color: "#252535"
        radius: 4

        Text {
            id: label
            anchors.centerIn: parent
            text: root.batteryText
            color: root.lowBattery ? "#ff5555" : "#f8f8f2"
            font.pixelSize: 12
            font.family: "SauceCodePro Nerd Font"
        }

        HoverHandler {
            id: hoverHandler
        }
    }
}
