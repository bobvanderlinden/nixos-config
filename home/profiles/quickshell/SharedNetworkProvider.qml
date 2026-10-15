pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

Singleton {
    id: root
    readonly property WifiDevice wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null
    property var scannerOwners: []
    property var scanningDevice: null
    function setScannerOwner(owner, enabled) {
        const owners = scannerOwners.filter(candidate => candidate !== owner);
        if (enabled) owners.push(owner);
        scannerOwners = owners;
        updateScanner();
    }
    function updateScanner() {
        if (scanningDevice && scanningDevice !== wifiDevice) scanningDevice.scannerEnabled = false;
        scanningDevice = wifiDevice;
        if (scanningDevice) scanningDevice.scannerEnabled = scannerOwners.length > 0;
    }
    onWifiDeviceChanged: updateScanner()
    onScannerOwnersChanged: updateScanner()

    property var nmVpnConnections: []
    property var nmWiredConnections: []
    property bool nmWifiConnected: false
    property bool nmFailed: false
    property bool nmRefreshPending: false
    property bool nmActionFailed: false
    property var openvpn3Profiles: []
    property var configList: []
    property bool openvpnFailed: false
    property bool openvpnRefreshPending: false
    property bool openvpnActionFailed: false

    // Installed Quickshell.Networking types have no VPN profile API. Use one
    // shared nmcli snapshot, invalidated by NM's monitor, for VPN and wired state.
    function parseNmConnections(output) {
        const escape = "\x00";
        const vpns = [];
        const wired = [];
        let wifiConnected = false;
        for (const line of output.trim().split("\n")) {
            if (!line) continue;
            const parts = line.replace(/\\:/g, escape).split(":");
            if (parts.length < 4) throw new Error("Invalid nmcli connection row");
            const name = parts[0].split(escape).join(":");
            const uuid = parts[1].split(escape).join(":");
            const type = parts[2];
            const device = parts[3].split(escape).join(":").trim();
            const active = device !== "--" && device !== "";
            if (type === "vpn" || type === "wireguard") vpns.push({ uuid, name, active });
            else if (type === "802-3-ethernet" && active) wired.push({ uuid, name, device, active });
            else if (type === "802-11-wireless" && active) wifiConnected = true;
        }
        nmVpnConnections = vpns;
        nmWiredConnections = wired;
        nmWifiConnected = wifiConnected;
    }
    function refreshNm() {
        if (nmListProcess.running) nmRefreshPending = true;
        else { nmRefreshPending = false; nmListProcess.running = true; }
    }
    function reconnectNm() {
        if (!nmMonitorProcess.running) nmMonitorProcess.running = true;
        refreshNm();
    }
    Process {
        id: nmListProcess
        command: ["timeout", "10", "nmcli", "--terse", "--fields", "NAME,UUID,TYPE,DEVICE", "connection", "show"]
        stdout: StdioCollector { id: nmOutput }
        onExited: exitCode => {
            root.nmFailed = exitCode !== 0;
            if (exitCode === 0) {
                try { root.parseNmConnections(nmOutput.text); }
                catch (error) { root.nmFailed = true; console.warn("SharedNetworkProvider:", error); }
            }
            if (root.nmFailed) nmRetryTimer.restart();
            else nmRetryTimer.stop();
            if (root.nmRefreshPending) Qt.callLater(root.refreshNm);
        }
    }
    Process {
        id: nmMonitorProcess
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: root.refreshNm() }
        onExited: nmReconnectTimer.restart()
    }
    Timer { id: nmReconnectTimer; interval: 5000; onTriggered: root.reconnectNm() }
    Timer { id: nmRetryTimer; interval: 10000; onTriggered: root.refreshNm() }
    function nmVpnConnect(uuid) { return nmAction(["timeout", "30", "nmcli", "connection", "up", "uuid", uuid]); }
    function nmVpnDisconnect(uuid) { return nmAction(["timeout", "30", "nmcli", "connection", "down", "uuid", uuid]); }
    function nmAction(command) {
        if (nmActionProcess.running) return false;
        nmActionProcess.command = command;
        nmActionProcess.running = true;
        return true;
    }
    Process {
        id: nmActionProcess
        onExited: exitCode => { root.nmActionFailed = exitCode !== 0; root.refreshNm(); }
    }

    // OpenVPN3 profiles/sessions have no native QML API here. Bound the two
    // shared queries and never start another cycle until both have completed.
    function refreshOpenvpn() {
        if (configsProcess.running || sessionsProcess.running || openvpnActionProcess.running)
            openvpnRefreshPending = true;
        else { openvpnRefreshPending = false; configsProcess.running = true; }
    }
    function finishOpenvpnRefresh() {
        if (openvpnRefreshPending) Qt.callLater(root.refreshOpenvpn);
    }
    Process {
        id: configsProcess
        command: ["timeout", "10", "openvpn3", "configs-list", "--json"]
        stdout: StdioCollector { id: configsOutput }
        onExited: exitCode => {
            root.openvpnFailed = exitCode !== 0;
            if (exitCode === 0) {
                try {
                    const configs = JSON.parse(configsOutput.text);
                    if (!configs || typeof configs !== "object" || Array.isArray(configs)) throw new Error("Expected config object");
                    root.configList = Object.entries(configs).map(([path, config]) => ({ name: config.name, configPath: path }));
                    if (!sessionsProcess.running) sessionsProcess.running = true;
                } catch (error) {
                    root.openvpnFailed = true;
                    console.warn("SharedNetworkProvider:", error);
                    root.finishOpenvpnRefresh();
                }
            } else root.finishOpenvpnRefresh();
        }
    }
    Process {
        id: sessionsProcess
        command: ["timeout", "10", "openvpn3", "sessions-list"]
        stdout: StdioCollector { id: sessionsOutput }
        onExited: exitCode => {
            root.openvpnFailed = exitCode !== 0;
            if (exitCode === 0) {
                const activeNames = new Set();
                for (const line of sessionsOutput.text.split("\n")) {
                    const match = line.match(/^\s*Config name:\s*(.+)$/);
                    if (match) activeNames.add(match[1].trim());
                }
                root.openvpn3Profiles = root.configList.map(config => ({ name: config.name, configPath: config.configPath, active: activeNames.has(config.name) }));
            }
            root.finishOpenvpnRefresh();
        }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refreshOpenvpn() }
    function openvpn3Connect(configPath) { return openvpnAction(["timeout", "30", "openvpn3", "session-start", "--config-path", configPath]); }
    function openvpn3Disconnect(name) { return openvpnAction(["timeout", "30", "openvpn3", "session-manage", "--config", name, "--disconnect"]); }
    function openvpnAction(command) {
        if (openvpnActionProcess.running) return false;
        openvpnActionProcess.command = command;
        openvpnActionProcess.running = true;
        return true;
    }
    Process {
        id: openvpnActionProcess
        onExited: exitCode => { root.openvpnActionFailed = exitCode !== 0; root.refreshOpenvpn(); }
    }
    Component.onCompleted: { reconnectNm(); refreshOpenvpn(); }
}
