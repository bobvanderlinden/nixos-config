import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile, copyFile, mkdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import vm from "node:vm";

const sourceDirectory = path.resolve("home/profiles/quickshell");
const providerNames = ["SharedDockerProvider", "SharedNetworkProvider", "SharedPrivacyProvider", "SharedTodoProvider", "SharedSystemdProvider", "SharedSessionProvider"];
for (const widget of ["PrivacyWidget", "DockerWidget", "NetworkWidget", "TodoWidget", "SystemdFailedUnits", "SessionTimeWidget"]) {
    const source = await readFile(path.join(sourceDirectory, `${widget}.qml`), "utf8");
    assert.doesNotMatch(source, /\bProcess\s*\{/);
}
for (const provider of providerNames) {
    assert.match(await readFile(path.join(sourceDirectory, `${provider}.qml`), "utf8"), /^pragma Singleton/);
}

// Exercise the actual scanner ownership methods against fake devices. No host
// scanner is enabled by this test.
const networkSource = await readFile(path.join(sourceDirectory, "SharedNetworkProvider.qml"), "utf8");
const scannerMethods = networkSource.slice(networkSource.indexOf("    function setScannerOwner"), networkSource.indexOf("    onWifiDeviceChanged"));
const scanner = vm.createContext({ scannerOwners: [], scanningDevice: null, wifiDevice: { scannerEnabled: false } });
vm.runInContext(scannerMethods, scanner);
const firstOwner = {};
const secondOwner = {};
scanner.setScannerOwner(firstOwner, true);
scanner.setScannerOwner(secondOwner, true);
scanner.setScannerOwner(firstOwner, true);
assert.equal(scanner.scannerOwners.length, 2);
scanner.setScannerOwner(firstOwner, false);
assert.equal(scanner.wifiDevice.scannerEnabled, true);
const oldDevice = scanner.wifiDevice;
scanner.wifiDevice = { scannerEnabled: false };
scanner.updateScanner();
assert.equal(oldDevice.scannerEnabled, false);
assert.equal(scanner.wifiDevice.scannerEnabled, true);
scanner.setScannerOwner(secondOwner, false);
assert.equal(scanner.wifiDevice.scannerEnabled, false);

const temporaryDirectory = await mkdtemp(path.join(tmpdir(), "shared-bar-providers-"));
try {
    const binaryDirectory = path.join(temporaryDirectory, "bin");
    await mkdir(binaryDirectory);
    for (const component of [...providerNames, "PrivacyWidget", "DockerWidget", "NetworkWidget", "TodoWidget", "SystemdFailedUnits", "SessionTimeWidget", "BarPill", "BarTooltip", "PopupWidget", "BarState"])
        await copyFile(path.join(sourceDirectory, `${component}.qml`), path.join(temporaryDirectory, `${component}.qml`));
    // Camera integration does not inspect the host's descriptors during tests.
    await writeFile(path.join(temporaryDirectory, "shared-camera-users.sh"), "printf 'camera scan\\n' >> \"$PROVIDER_TEST_LOG\"\nprintf 'camera-scan:complete\\ntest-camera\\n'\n");
    const logPath = path.join(temporaryDirectory, "commands.log");
    const mockScript = `#!/bin/sh
name=\${0##*/}
printf '%s %s\\n' "$name" "$*" >> "$PROVIDER_TEST_LOG"
case "$name $1" in
 'docker events'|'nmcli monitor')
    marker="$PROVIDER_TEST_DIRECTORY/$name-monitor"
    if [ ! -e "$marker" ]; then
        touch "$marker"
        sleep 0.1
        printf 'change\\nchange\\nchange\\n'
        sleep 0.05
        exit 1
    fi
    sleep 20
    ;;
 *)
    lock="$PROVIDER_TEST_DIRECTORY/$name-query"
    if ! mkdir "$lock" 2>/dev/null; then echo OVERLAP >> "$PROVIDER_TEST_LOG"; exit 2; fi
    sleep 0.15
    case "$name $1" in
      'docker ps') printf '%s\\n' '{"ID":"abc","Names":"test","Image":"image","Status":"Up"}' ;;
      'systemctl --user') printf '[]\\n' ;;
      'session-time ') printf '01:23\\n' ;;
      'todo.sh ls') printf '1 (A) test task\\n' ;;
      'nmcli --terse') printf 'test-vpn:uuid:vpn:tun0\\n' ;;
      'openvpn3 configs-list') printf '%s\\n' '{"/config/test":{"name":"test-vpn"}}' ;;
      'openvpn3 sessions-list') printf 'Path: /net/openvpn/v3/sessions/test\\nConfig name: test-vpn\\n' ;;
    esac
    rmdir "$lock"
    ;;
esac
`;
    for (const command of ["docker", "nmcli", "openvpn3", "todo.sh", "systemctl", "session-time"])
        await writeFile(path.join(binaryDirectory, command), mockScript, { mode: 0o755 });
    await writeFile(path.join(temporaryDirectory, "shell.qml"), `import Quickshell
import QtQuick
ShellRoot {
    id: root
    Item { id: firstView; property var backend: [SharedDockerProvider, SharedNetworkProvider, SharedPrivacyProvider, SharedTodoProvider, SharedSystemdProvider, SharedSessionProvider] }
    Item { id: secondView; property var backend: [SharedDockerProvider, SharedNetworkProvider, SharedPrivacyProvider, SharedTodoProvider, SharedSystemdProvider, SharedSessionProvider] }
    // Compile the real views too, without creating windows or enabling scans.
    Component { PrivacyWidget { barWindow: null } }
    Component { DockerWidget { barWindow: null } }
    Component { NetworkWidget { barWindow: null } }
    Component { TodoWidget { barWindow: null } }
    Component { SystemdFailedUnits {} }
    Component { SessionTimeWidget {} }
    function check(condition, message) { if (!condition) { console.error("PROVIDER_TEST_FAILED", message); Qt.quit(); } }
    Timer {
        interval: 1000; running: true
        onTriggered: {
            for (let providerIndex = 0; providerIndex < firstView.backend.length; providerIndex++)
                root.check(firstView.backend[providerIndex] === secondView.backend[providerIndex], "singleton identity " + providerIndex);
            root.check(SharedDockerProvider.containers.length === 1, "docker snapshot");
            root.check(SharedTodoProvider.tasks.length === 1, "todo snapshot");
            root.check(SharedSessionProvider.sessionTime === "01:23", "session snapshot");
            root.check(SharedNetworkProvider.nmVpnConnections[0].active, "NM snapshot");
            root.check(SharedNetworkProvider.openvpn3Profiles[0].active, "OpenVPN snapshot");
            root.check(SharedPrivacyProvider.camApps[0] === "test-camera", "camera snapshot");
            root.check(SharedDockerProvider.stopContainer("abc"), "docker action accepted");
            root.check(!SharedDockerProvider.stopContainer("abc"), "docker action overlap rejected");
            root.check(SharedTodoProvider.addTask("new task"), "todo action accepted");
            root.check(!SharedTodoProvider.completeTask(1), "todo action overlap rejected");
            root.check(SharedNetworkProvider.nmVpnConnect("uuid"), "NM action accepted");
            root.check(!SharedNetworkProvider.nmVpnDisconnect("uuid"), "NM action overlap rejected");
            root.check(SharedNetworkProvider.openvpn3Connect("/config/test"), "OpenVPN action accepted");
            root.check(!SharedNetworkProvider.openvpn3Disconnect("test-vpn"), "OpenVPN action overlap rejected");
        }
    }
    Timer {
        interval: 7000; running: true
        onTriggered: { console.log("PROVIDER_TEST_PASSED"); Qt.quit(); }
    }
}
`);
    const result = spawnSync("quickshell", ["--path", path.join(temporaryDirectory, "shell.qml"), "--no-color"], {
        env: { ...process.env, QT_QPA_PLATFORM: "offscreen", PATH: `${binaryDirectory}:${process.env.PATH}`, PROVIDER_TEST_DIRECTORY: temporaryDirectory, PROVIDER_TEST_LOG: logPath },
        encoding: "utf8", timeout: 12000,
    });
    const output = result.stdout + result.stderr;
    assert.equal(result.error, undefined, output);
    assert.match(output, /PROVIDER_TEST_PASSED/, output);
    assert.doesNotMatch(output, /PROVIDER_TEST_FAILED|Failed to load configuration|ReferenceError|TypeError|Binding loop/, output);
    const commands = (await readFile(logPath, "utf8")).trim().split("\n");
    assert(!commands.includes("OVERLAP"), commands.join("\n"));
    const count = prefix => commands.filter(command => command.startsWith(prefix)).length;
    assert.equal(count("session-time"), 1);
    assert.equal(count("systemctl"), 1);
    assert(count("camera scan") >= 3 && count("camera scan") <= 4, "One shared camera poller");
    assert.equal(count("openvpn3 configs-list"), 3, "One initial, action and periodic OpenVPN refresh");
    assert.equal(count("openvpn3 sessions-list"), 3);
    assert.equal(count("docker events"), 2, "Docker monitor must reconnect once");
    assert.equal(count("nmcli monitor"), 2, "NM monitor must reconnect once");
    assert(count("docker ps") >= 4, "Initial, pending event, action and reconnect snapshots");
    assert.equal(count("docker stop"), 1);
    assert.equal(count("todo.sh add"), 1);
    assert.equal(count("todo.sh ls"), 2, "Todo refreshes after completion");
    assert.equal(count("nmcli connection up"), 1);
    assert.equal(count("openvpn3 session-start"), 1);
    console.log("Shared bar provider tests passed (mocked subprocesses, isolated offscreen shell).");
} finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
}
