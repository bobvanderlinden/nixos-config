import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls

// Battery status using UPower displayDevice.
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22

    property var dev: UPower.displayDevice

    // Battery icons (Nerd Font)
    function batteryIcon(pct) {
        if (pct >= 90) return "";
        if (pct >= 70) return "";
        if (pct >= 50) return "";
        if (pct >= 25) return "";
        return "";
    }

    property string batteryText: {
        if (!dev || !dev.ready) return "";
        const pct = Math.round(dev.percentage * 100);
        if (dev.state === UPowerDeviceState.FullyCharged)
            return "Charged " + batteryIcon(pct);
        if (dev.state === UPowerDeviceState.Charging)
            return "⚡ " + pct + "% " + batteryIcon(pct);
        return pct + "% " + batteryIcon(pct);
    }

    property string batteryTooltip: {
        if (!dev || !dev.ready) return "";
        const pct = Math.round(dev.percentage * 100);
        return pct + "% (" + UPowerDeviceState.toString(dev.state) + ")";
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.batteryText
        color: "#f8f8f2"
        font.pixelSize: 12

        ToolTip.visible: hoverArea.containsMouse
        ToolTip.text: root.batteryTooltip
        ToolTip.delay: 500

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
        }
    }
}
