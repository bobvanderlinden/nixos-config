import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Network status widget. Reactive via Quickshell.Networking (no polling).
// Bar label: wifi icon + optional VPN icon.
// Hover to open popup with:
//   - Wi-Fi network list (sorted by signal; connected first)
//   - NM VPN section
//   - OpenVPN3 section
PopupWidget {
    id: root

    popupWidth: 260

    function wifiIcon(strength) {
        const pct = strength * 100;
        if (pct >= 80) return "󰤨";
        if (pct >= 60) return "󰤥";
        if (pct >= 40) return "󰤢";
        if (pct >= 20) return "󰤟";
        return "󰤯";
    }

    // ── Networking state ──────────────────────────────────────────────────────

    property WifiDevice wifiDevice: {
        const devices = Networking.devices.values;
        for (const device of devices) {
            if (device.type === DeviceType.Wifi) return device;
        }
        return null;
    }

    property var connectedNetwork: {
        if (!wifiDevice) return null;
        for (const network of wifiDevice.networks.values) {
            if (network.connected) return network;
        }
        return null;
    }

    property bool wifiConnecting: wifiDevice
        ? wifiDevice.state === DeviceConnectionState.Connecting
          || wifiDevice.state === DeviceConnectionState.Disconnecting
        : false

    property string netText: {
        if (connectedNetwork) return wifiIcon(connectedNetwork.signalStrength);
        return "󰤭";
    }

    property bool disconnected: !wifiConnecting && netText === "󰤭"
    property bool vpnActive: nmVpnConnections.some(c => c.active) || openvpn3Profiles.some(p => p.active)

    // Stable snapshot of sorted networks — re-snapshotted when popup opens
    property var sortedNetworks: []

    function refreshSortedNetworks() {
        if (!wifiDevice) { sortedNetworks = []; return; }
        sortedNetworks = [...wifiDevice.networks.values].sort((a, b) => {
            if (a.connected !== b.connected) return b.connected - a.connected;
            return b.signalStrength - a.signalStrength;
        });
    }

    // Enable wifi scanner while popup is open; refresh snapshot on scan complete.
    onPopupOpenChanged: {
        if (wifiDevice) wifiDevice.scannerEnabled = popupOpen;
        if (popupOpen) refreshSortedNetworks();
    }

    Connections {
        target: root.wifiDevice
        function onScannerEnabledChanged() {
            if (!root.wifiDevice.scannerEnabled && root.popupOpen)
                root.refreshSortedNetworks();
        }
        ignoreUnknownSignals: true
    }

    // ── NM VPN ────────────────────────────────────────────────────────────────

    property var nmVpnConnections: []

    function parseNmVpnConnections(output) {
        const ESCAPE = "\x00";
        const connections = [];
        const lines = output.trim().split("\n");
        for (const line of lines) {
            if (!line) continue;
            const parts = line.replace(/\\:/g, ESCAPE).split(":");
            if (parts.length < 4) continue;
            const name   = parts[0].replace(new RegExp(ESCAPE, "g"), ":");
            const uuid   = parts[1].replace(new RegExp(ESCAPE, "g"), ":");
            const type   = parts[2].replace(new RegExp(ESCAPE, "g"), ":");
            const device = parts[3].replace(new RegExp(ESCAPE, "g"), ":");
            if (type !== "vpn" && type !== "wireguard") continue;
            connections.push({ uuid, name, active: device !== "--" && device !== "" });
        }
        return connections;
    }

    Process {
        id: nmListProcess
        command: ["nmcli", "--terse", "--fields", "NAME,UUID,TYPE,DEVICE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.nmVpnConnections = root.parseNmVpnConnections(text)
        }
    }

    Process {
        id: nmMonitorProcess
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: nmListProcess.exec(nmListProcess.command)
        }
        onExited: nmMonitorRestartTimer.start()
    }

    Timer {
        id: nmMonitorRestartTimer
        interval: 2000
        onTriggered: nmMonitorProcess.running = true
    }

    function nmVpnConnect(uuid) {
        nmVpnActionProcess.command = ["nmcli", "connection", "up", "uuid", uuid];
        nmVpnActionProcess.startDetached();
    }
    function nmVpnDisconnect(uuid) {
        nmVpnActionProcess.command = ["nmcli", "connection", "down", "uuid", uuid];
        nmVpnActionProcess.startDetached();
    }

    Process { id: nmVpnActionProcess }

    // ── OpenVPN3 ──────────────────────────────────────────────────────────────

    property var openvpn3Profiles: []
    property var _ov3ConfigList: []

    Process {
        id: ov3ConfigsProcess
        command: ["openvpn3", "configs-list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text);
                    root._ov3ConfigList = Object.entries(json).map(([path, config]) => ({
                        name: config.name, configPath: path
                    }));
                } catch (e) {
                    root._ov3ConfigList = [];
                }
                ov3SessionsProcess.exec(ov3SessionsProcess.command);
            }
        }
    }

    Process {
        id: ov3SessionsProcess
        command: ["openvpn3", "sessions-list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const activeNames = new Set();
                for (const line of text.split("\n")) {
                    const match = line.match(/^\s*Config name:\s*(.+)$/);
                    if (match) activeNames.add(match[1].trim());
                }
                root.openvpn3Profiles = root._ov3ConfigList.map(config => ({
                    name: config.name,
                    configPath: config.configPath,
                    active: activeNames.has(config.name)
                }));
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: ov3ConfigsProcess.exec(ov3ConfigsProcess.command)
    }

    function openvpn3Connect(configPath) {
        ov3ActionProcess.exec(["openvpn3", "session-start", "--config-path", configPath]);
    }
    function openvpn3Disconnect(name) {
        ov3ActionProcess.exec(["openvpn3", "session-manage", "--config", name, "--disconnect"]);
    }

    Process {
        id: ov3ActionProcess
        onExited: ov3ConfigsProcess.exec(ov3ConfigsProcess.command)
    }

    Component.onCompleted: {
        nmListProcess.exec(nmListProcess.command);
        ov3ConfigsProcess.exec(ov3ConfigsProcess.command);
    }

    // ── Pill content ──────────────────────────────────────────────────────────

    pillContent: Component {
    Row {
        spacing: 0

        Text {
            text: root.netText
            color: root.disconnected ? "#6272a4" : root.wifiConnecting ? "#89b4fa" : "#f8f8f2"
            font.pixelSize: 12
            font.family: "SauceCodePro Nerd Font"
        }

        Text {
            visible: root.wifiConnecting
            width: root.wifiConnecting ? implicitWidth : 0
            leftPadding: 4
            text: "󰑐"
            color: "#89b4fa"
            font.pixelSize: 12
            font.family: "SauceCodePro Nerd Font"

            RotationAnimator on rotation {
                running: root.wifiConnecting
                from: 0; to: 360; duration: 1000
                loops: Animation.Infinite
            }
        }

        Text {
            visible: root.vpnActive
            width: root.vpnActive ? implicitWidth : 0
            leftPadding: 4
            text: "󰦝"
            color: "#a6e3a1"
            font.pixelSize: 12
            font.family: "SauceCodePro Nerd Font"
        }
    }
    } // Component pillContent

    // ── Popup content ─────────────────────────────────────────────────────────

    popupContent: Component {
    ColumnLayout {
        spacing: 6

        // ── Wi-Fi header ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Wi-Fi"
                color: "#6272a4"
                font.pixelSize: 10
                font.family: "SauceCodePro Nerd Font"
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                visible: root.wifiDevice?.scannerEnabled ?? false
                text: "󰑐"
                color: "#6272a4"
                font.pixelSize: 11
                font.family: "SauceCodePro Nerd Font"

                RotationAnimator on rotation {
                    running: root.wifiDevice?.scannerEnabled ?? false
                    from: 0; to: 360; duration: 1200
                    loops: Animation.Infinite
                }
            }
        }

        // ── Wi-Fi network list ────────────────────────────────────────────────
        Repeater {
            model: root.sortedNetworks

            delegate: Item {
                id: networkRow
                required property var modelData
                Layout.fillWidth: true
                implicitWidth: 220
                implicitHeight: 28

                readonly property bool isClickable: modelData.connected || modelData.known
                readonly property bool isSecured: modelData.security !== WifiSecurityType.None
                readonly property bool isChanging: modelData.stateChanging

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: {
                        if (modelData.connected || parent.isChanging) return "#313244";
                        if (rowHover.containsMouse && parent.isClickable) return "#2a2a3c";
                        return "transparent";
                    }
                    Behavior on color { ColorAnimation { duration: 80 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                    spacing: 6

                    Text {
                        text: root.wifiIcon(modelData.signalStrength)
                        color: {
                            if (modelData.connected || parent.parent.isChanging) return "#89b4fa";
                            if (!parent.parent.isClickable) return "#44475a";
                            return "#cdd6f4";
                        }
                        font.pixelSize: 13
                        font.family: "SauceCodePro Nerd Font"
                    }

                    Text {
                        text: modelData.name || "Hidden Network"
                        color: {
                            if (modelData.connected || parent.parent.isChanging) return "#f8f8f2";
                            if (!parent.parent.isClickable) return "#555577";
                            return "#cdd6f4";
                        }
                        font.pixelSize: 12
                        font.family: "SauceCodePro Nerd Font"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: parent.parent.isSecured
                        text: "󰌾"
                        color: parent.parent.isClickable ? "#6272a4" : "#44475a"
                        font.pixelSize: 10
                        font.family: "SauceCodePro Nerd Font"
                    }

                    Text {
                        visible: modelData.connected || parent.parent.isChanging
                        text: parent.parent.isChanging ? "󰑐" : "󰄴"
                        color: "#89b4fa"
                        font.pixelSize: 11
                        font.family: "SauceCodePro Nerd Font"

                        RotationAnimator on rotation {
                            running: networkRow.isChanging
                            from: 0; to: 360; duration: 1000
                            loops: Animation.Infinite
                        }
                    }
                }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.isClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.isClickable
                    onClicked: {
                        if (modelData.connected) modelData.disconnect();
                        else modelData.connect();
                        BarState.activePopupWidget = null;
                    }
                }
            }
        }

        Text {
            visible: root.sortedNetworks.length === 0
            text: root.wifiDevice ? "No networks found" : "No Wi-Fi device"
            color: "#6272a4"
            font.pixelSize: 11
            font.family: "SauceCodePro Nerd Font"
            Layout.alignment: Qt.AlignHCenter
        }

        // ── NM VPN section ────────────────────────────────────────────────────
        ColumnLayout {
            visible: root.nmVpnConnections.length > 0
            Layout.fillWidth: true
            spacing: 6

            Rectangle { Layout.fillWidth: true; height: 1; color: "#44475a" }

            Text {
                text: "VPN"
                color: "#6272a4"
                font.pixelSize: 10
                font.family: "SauceCodePro Nerd Font"
                font.bold: true
            }

            Repeater {
                model: root.nmVpnConnections

                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitWidth: 220
                    implicitHeight: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: {
                            if (modelData.active) return "#313244";
                            if (nmVpnRowHover.containsMouse) return "#2a2a3c";
                            return "transparent";
                        }
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        spacing: 6

                        Text {
                            text: "󰦝"
                            color: modelData.active ? "#89b4fa" : "#cdd6f4"
                            font.pixelSize: 13
                            font.family: "SauceCodePro Nerd Font"
                        }

                        Text {
                            text: modelData.name
                            color: modelData.active ? "#f8f8f2" : "#cdd6f4"
                            font.pixelSize: 12
                            font.family: "SauceCodePro Nerd Font"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: modelData.active
                            text: "󰄴"
                            color: "#89b4fa"
                            font.pixelSize: 11
                            font.family: "SauceCodePro Nerd Font"
                        }
                    }

                    MouseArea {
                        id: nmVpnRowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.active) root.nmVpnDisconnect(modelData.uuid);
                            else root.nmVpnConnect(modelData.uuid);
                            BarState.activePopupWidget = null;
                        }
                    }
                }
            }
        }

        // ── OpenVPN3 section ──────────────────────────────────────────────────
        ColumnLayout {
            visible: root.openvpn3Profiles.length > 0
            Layout.fillWidth: true
            spacing: 6

            Rectangle { Layout.fillWidth: true; height: 1; color: "#44475a" }

            Text {
                text: "OpenVPN3"
                color: "#6272a4"
                font.pixelSize: 10
                font.family: "SauceCodePro Nerd Font"
                font.bold: true
            }

            Repeater {
                model: root.openvpn3Profiles

                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitWidth: 220
                    implicitHeight: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: {
                            if (modelData.active) return "#313244";
                            if (ov3RowHover.containsMouse) return "#2a2a3c";
                            return "transparent";
                        }
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        spacing: 6

                        Text {
                            text: "󰦝"
                            color: modelData.active ? "#89b4fa" : "#cdd6f4"
                            font.pixelSize: 13
                            font.family: "SauceCodePro Nerd Font"
                        }

                        Text {
                            text: modelData.name
                            color: modelData.active ? "#f8f8f2" : "#cdd6f4"
                            font.pixelSize: 12
                            font.family: "SauceCodePro Nerd Font"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: modelData.active
                            text: "󰄴"
                            color: "#89b4fa"
                            font.pixelSize: 11
                            font.family: "SauceCodePro Nerd Font"
                        }
                    }

                    MouseArea {
                        id: ov3RowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.active) root.openvpn3Disconnect(modelData.name);
                            else root.openvpn3Connect(modelData.configPath);
                            BarState.activePopupWidget = null;
                        }
                    }
                }
            }
        }
    }
    } // Component popupContent

    // ── Tooltip ───────────────────────────────────────────────────────────────

    BarTooltip {
        barWindow: root.barWindow
        widget: root
        text: {
            if (root.wifiConnecting && root.wifiDevice) {
                const state = root.wifiDevice.nmState;
                if (state === NMDeviceState.NeedAuth) return "Waiting for password…";
                if (state === NMDeviceState.Deactivating) return "Disconnecting…";
                return "Connecting…";
            }
            if (root.connectedNetwork)
                return root.connectedNetwork.name + " (" + Math.round(root.connectedNetwork.signalStrength * 100) + "%)";
            const activeNmVpn = root.nmVpnConnections.find(c => c.active);
            if (activeNmVpn) return "VPN: " + activeNmVpn.name;
            const activeOv3 = root.openvpn3Profiles.find(p => p.active);
            if (activeOv3) return "VPN: " + activeOv3.name;
            return "Disconnected";
        }
        shown: hoverHandler.hovered && !root.popupOpen
    }

    HoverHandler { id: hoverHandler }
}
