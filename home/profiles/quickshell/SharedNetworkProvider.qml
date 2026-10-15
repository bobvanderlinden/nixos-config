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
    property bool nmHasSnapshot: false
    readonly property string nmStatus: !nmHasSnapshot ? "unavailable" : nmFailed ? "stale" : "ready"
    property bool nmRefreshPending: false
    property bool nmActionFailed: false
    property var openvpn3Profiles: []
    property var configList: []
    property bool openvpnFailed: false
    property bool openvpnHasSnapshot: false
    readonly property string openvpnStatus: !openvpnHasSnapshot ? "unavailable" : openvpnFailed ? "stale" : "ready"
    readonly property string queryMessage: [
        nmStatus === "ready" ? "" : nmStatus === "stale" ? "NetworkManager updates unavailable. Showing last known state." : "NetworkManager status unavailable.",
        openvpnStatus === "ready" ? "" : openvpnStatus === "stale" ? "OpenVPN query failed. Showing last known state." : "OpenVPN status unavailable.",
        nmActionFailed ? "NetworkManager action failed. Check the connection and retry." : "",
        openvpnActionFailed ? "OpenVPN action failed. Check the connection and retry." : ""
    ].filter(message => message).join("\n")
    property bool openvpnRefreshPending: false
    property bool openvpnActionFailed: false

    // Installed Quickshell.Networking types have no VPN profile API. Use one
    // shared nmcli snapshot, invalidated by NM's monitor, for VPN and wired state.
    function parseNmConnections(output) {
        const vpns = [];
        const wired = [];
        let wifiConnected = false;
        for (const line of output.trim().split("\n")) {
            if (!line) continue;
            const parts = [""];
            let escaped = false;
            for (const character of line) {
                if (escaped) { parts[parts.length - 1] += character; escaped = false; }
                else if (character === "\\") escaped = true;
                else if (character === ":") parts.push("");
                else parts[parts.length - 1] += character;
            }
            if (escaped || parts.length !== 4 || !parts[0] || !parts[1] || !parts[2]) throw new Error("Invalid nmcli connection row");
            const name = parts[0];
            const uuid = parts[1];
            const type = parts[2];
            const device = parts[3].trim();
            const active = device !== "--" && device !== "";
            if (type === "vpn" || type === "wireguard") vpns.push({ uuid, name, active });
            else if (type === "802-3-ethernet" && active) wired.push({ uuid, name, device, active });
            else if (type === "802-11-wireless" && active) wifiConnected = true;
        }
        nmVpnConnections = vpns;
        nmWiredConnections = wired;
        nmWifiConnected = wifiConnected;
    }
    function acceptNmSnapshot(output, exitCode, exitStatus = 0) {
        nmFailed = true;
        if (exitCode !== 0 || exitStatus !== 0) return;
        try {
            parseNmConnections(output);
            nmHasSnapshot = true;
            nmFailed = false;
        } catch (error) { console.warn("SharedNetworkProvider:", error); }
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
        onExited: (exitCode, exitStatus) => {
            root.acceptNmSnapshot(nmOutput.text, exitCode, exitStatus);
            if (root.nmFailed) nmRetryTimer.restart();
            else nmRetryTimer.stop();
            if (root.nmRefreshPending) Qt.callLater(root.refreshNm);
        }
    }
    Process {
        id: nmMonitorProcess
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: root.refreshNm() }
        onExited: { root.nmFailed = true; nmReconnectTimer.restart(); }
    }
    Timer { id: nmReconnectTimer; interval: 5000; onTriggered: root.reconnectNm() }
    Timer { id: nmRetryTimer; interval: 10000; onTriggered: root.refreshNm() }
    function nmVpnConnect(uuid) { return nmAction(["timeout", "30", "nmcli", "connection", "up", "uuid", uuid]); }
    function nmVpnDisconnect(uuid) { return nmAction(["timeout", "30", "nmcli", "connection", "down", "uuid", uuid]); }
    function nmAction(command) {
        if (nmActionProcess.running) return false;
        nmActionFailed = false;
        nmActionProcess.command = command;
        nmActionProcess.running = true;
        return true;
    }
    Process {
        id: nmActionProcess
        onExited: (exitCode, exitStatus) => { root.nmActionFailed = exitCode !== 0 || exitStatus !== 0; root.refreshNm(); }
    }

    // OpenVPN3 profiles/sessions have no native QML API here. Bound the two
    // shared queries and never start another cycle until both have completed.
    function acceptConfigs(output, exitCode, exitStatus = 0) {
        if (exitCode !== 0 || exitStatus !== 0) { openvpnFailed = true; return false; }
        try {
            const configs = JSON.parse(output);
            if (!configs || typeof configs !== "object" || Array.isArray(configs)) throw new Error("Expected config object");
            const nextConfigs = Object.entries(configs).map(([path, config]) => {
                if (!path.startsWith("/") || !config || typeof config.name !== "string" || !config.name.trim()) throw new Error("Invalid VPN config");
                return { name: config.name, configPath: path };
            });
            // Pending configs are committed to the displayed profiles only when
            // the matching sessions query has also succeeded.
            configList = nextConfigs;
            return true;
        } catch (error) { openvpnFailed = true; console.warn("SharedNetworkProvider:", error); return false; }
    }
    function acceptSessions(output, exitCode, exitStatus = 0) {
        openvpnFailed = true;
        if (exitCode !== 0 || exitStatus !== 0) return;
        try {
            const activeNames = new Set();
            const text = output.trim();
            if (!/^No sessions available\.?$/.test(text)) {
                if (!text || !/^\s*Path:\s*\/net\/openvpn\/v3\/sessions\/\S+/m.test(text)) throw new Error("Unrecognized VPN sessions output");
                const paths = text.match(/^\s*Path:\s*\S+/gm) || [];
                const names = text.match(/^\s*Config name:\s*\S.*$/gm) || [];
                if (paths.length !== names.length) throw new Error("Incomplete VPN sessions output");
                for (const line of names) activeNames.add(line.replace(/^\s*Config name:\s*/, "").trim());
            }
            openvpn3Profiles = configList.map(config => ({ name: config.name, configPath: config.configPath, active: activeNames.has(config.name) }));
            openvpnHasSnapshot = true;
            openvpnFailed = false;
        } catch (error) { console.warn("SharedNetworkProvider:", error); }
    }
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
        onExited: (exitCode, exitStatus) => {
            if (root.acceptConfigs(configsOutput.text, exitCode, exitStatus)) {
                if (!sessionsProcess.running) sessionsProcess.running = true;
            } else root.finishOpenvpnRefresh();
        }
    }
    Process {
        id: sessionsProcess
        command: ["timeout", "10", "openvpn3", "sessions-list"]
        stdout: StdioCollector { id: sessionsOutput }
        onExited: (exitCode, exitStatus) => {
            root.acceptSessions(sessionsOutput.text, exitCode, exitStatus);
            root.finishOpenvpnRefresh();
        }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refreshOpenvpn() }
    function openvpn3Connect(configPath) { return openvpnAction(["timeout", "30", "openvpn3", "session-start", "--config-path", configPath]); }
    function openvpn3Disconnect(name) { return openvpnAction(["timeout", "30", "openvpn3", "session-manage", "--config", name, "--disconnect"]); }
    function openvpnAction(command) {
        if (openvpnActionProcess.running) return false;
        openvpnActionFailed = false;
        openvpnActionProcess.command = command;
        openvpnActionProcess.running = true;
        return true;
    }
    Process {
        id: openvpnActionProcess
        onExited: (exitCode, exitStatus) => { root.openvpnActionFailed = exitCode !== 0 || exitStatus !== 0; root.refreshOpenvpn(); }
    }
    Component.onCompleted: { reconnectNm(); refreshOpenvpn(); }
}
