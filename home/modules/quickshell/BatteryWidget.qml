import Quickshell.Services.UPower
import QtQuick

// Battery status using UPower displayDevice.
// Format: <icon> <pct>%   (or just <icon> when fully charged)
// Icons are Nerd Font battery glyphs; charging uses the bolt variant.
BarPill {
    id: root

    required property var barWindow

    property var dev: UPower.displayDevice

    // String.fromCodePoint is required for codepoints > U+FFFF (5 hex digits).
    // QML's \uXXXX escape only consumes exactly 4 hex digits, so \uF0082
    // would be parsed as \uF008 + "2", not U+F0082.
    function batteryIcon(pct, charging) {
        if (charging) {
            if (pct >= 90) return String.fromCodePoint(0xF0085); // 󰂅 md-battery_charging_100
            if (pct >= 70) return String.fromCodePoint(0xF008B); // 󰂋 md-battery_charging_90
            if (pct >= 60) return String.fromCodePoint(0xF008A); // 󰂊 md-battery_charging_80
            if (pct >= 50) return String.fromCodePoint(0xF089E); // 󰢞 md-battery_charging_70
            if (pct >= 40) return String.fromCodePoint(0xF0089); // 󰂉 md-battery_charging_60
            if (pct >= 30) return String.fromCodePoint(0xF089D); // 󰢝 md-battery_charging_50
            if (pct >= 20) return String.fromCodePoint(0xF0088); // 󰂈 md-battery_charging_40
            if (pct >= 10) return String.fromCodePoint(0xF0087); // 󰂇 md-battery_charging_30
            return String.fromCodePoint(0xF0086);                // 󰂆 md-battery_charging_20
        }
        if (pct >= 90) return String.fromCodePoint(0xF0082);     // 󰂂 md-battery_90
        if (pct >= 70) return String.fromCodePoint(0xF0081);     // 󰂁 md-battery_80
        if (pct >= 50) return String.fromCodePoint(0xF0080);     // 󰂀 md-battery_70
        if (pct >= 30) return String.fromCodePoint(0xF007F);     // 󰁿 md-battery_60
        if (pct >= 20) return String.fromCodePoint(0xF007E);     // 󰁾 md-battery_50
        if (pct >= 10) return String.fromCodePoint(0xF007C);     // 󰁼 md-battery_30
        return String.fromCodePoint(0xF007B);                    // 󰁻 md-battery_20
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
