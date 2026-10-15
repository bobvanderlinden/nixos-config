import Quickshell
import Quickshell.Networking
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Network status widget. Native Wi-Fi state and shared NM/OpenVPN queries.
// Bar label: wired/wifi icon + optional VPN icon.
// Hover to open popup with:
//   - Wired connection (if active)
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

    readonly property WifiDevice wifiDevice: SharedNetworkProvider.wifiDevice

    property var connectedNetwork: {
        if (!wifiDevice) return null;
        for (const network of wifiDevice.networks.values) {
            if (network.connected) return network;
        }
        return null;
    }

    property bool wifiConnecting: wifiDevice
        ? wifiDevice.state === ConnectionState.Connecting
          || wifiDevice.state === ConnectionState.Disconnecting
        : false

    property string netText: {
        if (wiredConnected) return "󰈀";
        if (connectedNetwork) return wifiIcon(connectedNetwork.signalStrength);
        if (nmWifiConnected) return "󰤨";
        return "󰤭";
    }

    property bool disconnected: !wiredConnected && !wifiConnecting && netText === "󰤭"
    property bool vpnActive: nmVpnConnections.some(c => c.active) || openvpn3Profiles.some(p => p.active)

    // Keep sorting local to the view; refresh on open and network changes.
    property var sortedNetworks: []

    function refreshSortedNetworks() {
        if (!wifiDevice) { sortedNetworks = []; return; }
        sortedNetworks = [...wifiDevice.networks.values].sort((a, b) => {
            if (a.connected !== b.connected) return b.connected - a.connected;
            return b.signalStrength - a.signalStrength;
        });
    }

    // Each view owns a scanner lease. Closing one cannot stop another view.
    onPopupOpenChanged: {
        SharedNetworkProvider.setScannerOwner(root, popupOpen);
        if (popupOpen) refreshSortedNetworks();
    }
    onWifiDeviceChanged: { if (popupOpen) refreshSortedNetworks(); }
    onConnectedNetworkChanged: { if (popupOpen) refreshSortedNetworks(); }
    Component.onDestruction: SharedNetworkProvider.setScannerOwner(root, false)

    Connections {
        target: root.wifiDevice ? root.wifiDevice.networks : null
        function onValuesChanged() { if (root.popupOpen) root.refreshSortedNetworks(); }
    }
    Connections {
        target: root.wifiDevice
        function onScannerEnabledChanged() {
            if (root.popupOpen) root.refreshSortedNetworks();
        }
        ignoreUnknownSignals: true
    }

    // ── NM VPN ────────────────────────────────────────────────────────────────

    readonly property var nmVpnConnections: SharedNetworkProvider.nmVpnConnections
    readonly property var nmWiredConnections: SharedNetworkProvider.nmWiredConnections
    readonly property bool nmWifiConnected: SharedNetworkProvider.nmWifiConnected
    readonly property bool wiredConnected: nmWiredConnections.length > 0
    readonly property var openvpn3Profiles: SharedNetworkProvider.openvpn3Profiles

    function nmVpnConnect(uuid) { SharedNetworkProvider.nmVpnConnect(uuid); }
    function nmVpnDisconnect(uuid) { SharedNetworkProvider.nmVpnDisconnect(uuid); }
    function openvpn3Connect(configPath) { SharedNetworkProvider.openvpn3Connect(configPath); }
    function openvpn3Disconnect(name) { SharedNetworkProvider.openvpn3Disconnect(name); }

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

        // ── Wired section ─────────────────────────────────────────────────────
        ColumnLayout {
            visible: root.nmWiredConnections.length > 0
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "Wired"
                color: "#6272a4"
                font.pixelSize: 10
                font.family: "SauceCodePro Nerd Font"
                font.bold: true
            }

            Repeater {
                model: root.nmWiredConnections
                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitWidth: 220
                    implicitHeight: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: "#313244"
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        spacing: 6

                        Text {
                            text: "󰈀"
                            color: "#89b4fa"
                            font.pixelSize: 13
                            font.family: "SauceCodePro Nerd Font"
                        }

                        Text {
                            text: modelData.name
                            color: "#f8f8f2"
                            font.pixelSize: 12
                            font.family: "SauceCodePro Nerd Font"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "󰄴"
                            color: "#89b4fa"
                            font.pixelSize: 11
                            font.family: "SauceCodePro Nerd Font"
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#44475a" }
        }

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
            if (root.wiredConnected)
                return root.nmWiredConnections[0].name + " (" + root.nmWiredConnections[0].device + ")";
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
