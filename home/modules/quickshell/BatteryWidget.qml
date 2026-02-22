import Quickshell.Services.UPower
import QtQuick

// Battery status using UPower displayDevice.
// Format: <icon> <pct>%   (or just <icon> when fully charged)
// Icons are Nerd Font battery glyphs; charging uses the bolt variant.
BarPill {
    id: root

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
        if (!dev || !dev.isLaptopBattery) return "";
        const pct = Math.round(dev.percentage * 100);
        const charging = dev.state === UPowerDeviceState.Charging;
        const icon = batteryIcon(pct, charging);
        return icon + " " + pct + "%";
    }

    property string batteryTooltip: {
        if (!dev || !dev.isLaptopBattery) return "";
        const pct = Math.round(dev.percentage * 100);
        return pct + "% (" + UPowerDeviceState.toString(dev.state) + ")";
    }

    property bool lowBattery: dev && dev.isLaptopBattery
        && dev.state !== UPowerDeviceState.Charging
        && dev.state !== UPowerDeviceState.FullyCharged
        && dev.percentage < 0.2

    BarTooltip {
        barWindow: root.barWindow
        widget: root
        text: root.batteryTooltip
        shown: hoverHandler.hovered
    }

    Text {
        id: label
        text: root.batteryText
        color: root.lowBattery ? "#ff5555" : "#f8f8f2"
        font.pixelSize: 12
        font.family: "SauceCodePro Nerd Font"
    }

    HoverHandler {
        id: hoverHandler
    }
}
