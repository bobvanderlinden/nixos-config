import assert from "node:assert/strict";
import { readFile, mkdtemp, copyFile, writeFile, mkdir, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import vm from "node:vm";

const directory = path.resolve("home/profiles/quickshell");
const names = ["Docker", "Systemd", "Session", "Todo", "Network", "Privacy"];
const sources = Object.fromEntries(await Promise.all(names.map(async name => [name, await readFile(path.join(directory, `Shared${name}Provider.qml`), "utf8")])));
function backend(name, properties) {
    const context = vm.createContext({ console: { warn() {} }, ...properties });
    // Read the actual provider methods, not a second implementation of parsing.
    const methods = sources[name].match(/^    function [^\n]+\{\n[\s\S]*?^    }/gm);
    vm.runInContext(methods.join("\n"), context);
    return context;
}
function snapshotChecks(context, method, valid, empty, malformed, data, hasSnapshot = "hasSnapshot", failed = "failed") {
    const call = (output, code = 0, status = 0) => context[method](output, code, status);
    call(valid, 1);
    assert.equal(context[hasSnapshot], false, "initial nonzero status is unavailable");
    call(malformed);
    assert.equal(context[hasSnapshot], false, "initial malformed output is unavailable");
    call(valid);
    assert.equal(context[failed], false);
    assert.equal(context[hasSnapshot], true);
    const previous = JSON.stringify(context[data]);
    for (const [output, code, status] of [[malformed, 0, 0], [empty, 1, 0], [empty, 0, 1]]) {
        call(output, code, status);
        assert.equal(context[failed], true);
        assert.equal(JSON.stringify(context[data]), previous, "failure preserves last successful state");
    }
    if (empty !== null) {
        call(empty);
        assert.equal(context[failed], false, "successful empty result is ready");
        const emptyState = JSON.stringify(context[data]);
        call(malformed);
        assert.equal(context[failed], true, "an empty last snapshot still becomes stale");
        assert.equal(JSON.stringify(context[data]), emptyState);
    }
    call(valid);
    assert.equal(context[failed], false, "recovery clears query failure");
}
const docker = '{"ID":"abc","Names":"test","Image":"image","Status":"Up"}';
const unit = '[{"unit":"test.service","active":"failed"}]';
snapshotChecks(backend("Docker", { hasSnapshot: false, containers: [] }), "acceptSnapshot", docker, "", '{"ID":"abc"}', "containers");
snapshotChecks(backend("Systemd", { hasSnapshot: false, failedCount: 0 }), "acceptSnapshot", unit, "[]", "[{}]", "failedCount");
snapshotChecks(backend("Session", { hasSnapshot: false, sessionTime: "--:--" }), "acceptSnapshot", "01:23", null, "12:99", "sessionTime");
const session = backend("Session", { hasSnapshot: false, sessionTime: "--:--" });
session.acceptSnapshot("", 0);
assert.equal(session.failed, true, "an empty session time is not a valid duration");
snapshotChecks(backend("Todo", { hasSnapshot: false, tasks: [] }), "acceptSnapshot", "1 (A) test task\n--\nTODO: 1 of 1 tasks shown\n", "--\nTODO: 0 of 0 tasks shown\n", "warning: cannot read tasks", "tasks");
const network = backend("Network", { nmHasSnapshot: false, nmVpnConnections: [], nmWiredConnections: [], nmWifiConnected: false, openvpnHasSnapshot: false, openvpn3Profiles: [], configList: [] });
snapshotChecks(network, "acceptNmSnapshot", "test\\:vpn:uuid:vpn:tun0", "", "garbage:row", "nmVpnConnections", "nmHasSnapshot", "nmFailed");
assert.equal(network.nmVpnConnections[0].name, "test:vpn");
const configs = '{"/config/test":{"name":"test-vpn"}}';
assert.equal(network.acceptConfigs(configs, 1), false);
assert.equal(network.acceptConfigs('{"/config/test":{}}', 0), false);
assert.equal(network.acceptConfigs(configs, 0), true);
snapshotChecks(network, "acceptSessions", "Path: /net/openvpn/v3/sessions/test\nConfig name: test-vpn\n", "No sessions available", "Warning: sessions unavailable", "openvpn3Profiles", "openvpnHasSnapshot", "openvpnFailed");
const lastProfiles = JSON.stringify(network.openvpn3Profiles);
assert.equal(network.acceptConfigs("{}", 0), true);
network.acceptSessions("malformed", 0);
assert.equal(JSON.stringify(network.openvpn3Profiles), lastProfiles, "configs cannot partially replace a VPN snapshot");
network.acceptSessions("No sessions available", 0);
assert.equal(network.openvpn3Profiles.length, 0);
assert.equal(network.openvpnFailed, false);
const privacy = backend("Privacy", { cameraHasSnapshot: false, camApps: [], cameraLimited: false });
snapshotChecks(privacy, "acceptCameraSnapshot", "camera-scan:complete\napp\n", "camera-scan:complete\n", "app\n", "camApps", "cameraHasSnapshot", "cameraFailed");
privacy.acceptCameraSnapshot("camera-scan:limited\n", 0);
assert.equal(privacy.cameraLimited, true, "expected inaccessible processes are reported as limited coverage");
assert.equal(privacy.camApps.length, 0);
privacy.acceptCameraSnapshot("camera-scan:complete\n", 1);
assert.equal(privacy.cameraLimited, true, "errors preserve coverage information too");
privacy.Pipewire = { ready: true };
privacy.observedMicApps = ["microphone-app"];
privacy.observedScreenApps = ["screen-app"];
privacy.updateCaptureSnapshots();
privacy.Pipewire.ready = false;
privacy.observedMicApps = [];
privacy.observedScreenApps = [];
privacy.updateCaptureSnapshots();
assert.equal(privacy.micApps[0], "microphone-app", "PipeWire outages preserve last known capture state");
assert.equal(privacy.scrApps[0], "screen-app");
privacy.Pipewire.ready = true;
privacy.updateCaptureSnapshots();
assert.equal(privacy.micApps.length, 0, "successful empty capture state replaces stale activity");

// Real QML subprocess handlers, all commands mocked. No host actions or scans.
const temporary = await mkdtemp(path.join(tmpdir(), "query-errors-implementation-"));
try {
    const binaries = path.join(temporary, "bin");
    await mkdir(binaries);
    for (const name of names) {
        // Suppress periodic timers in this isolated copy so each test phase has
        // exactly one explicit refresh. Startup snapshots still run normally.
        await writeFile(path.join(temporary, `Shared${name}Provider.qml`), sources[name].replace(/running: true/g, "running: false"));
    }
    for (const name of ["PrivacyWidget", "DockerWidget", "NetworkWidget", "TodoWidget", "SystemdFailedUnits", "SessionTimeWidget", "BarPill", "BarTooltip", "PopupWidget", "BarState"])
        await copyFile(path.join(directory, `${name}.qml`), path.join(temporary, `${name}.qml`));
    const script = `#!/bin/sh
mode=$(head --lines 1 "$QUERY_ERROR_DIRECTORY/mode")
name=\${0##*/}
case "$name $1" in
 'docker events'|'nmcli monitor') sleep 20; exit 0;;
 'docker stop'|'todo.sh add'|'nmcli connection'|'openvpn3 session-start') exit 9;;
esac
if [ "$mode" = nonzero ]; then exit 7; fi
if [ "$mode" = malformed ]; then printf 'garbage\\n'; exit 0; fi
case "$name $1" in
 'docker ps') [ "$mode" = empty ] || printf '%s\\n' '${docker}' ;;
 'systemctl --user') if [ "$mode" = empty ]; then printf '[]\\n'; else printf '%s\\n' '${unit}'; fi ;;
 'session-time ') printf '01:23\\n' ;;
 'todo.sh ls') [ "$mode" = empty ] || printf '1 (A) test task\\n' ;;
 'nmcli --terse') [ "$mode" = empty ] || printf 'test-vpn:uuid:vpn:tun0\\n' ;;
 'openvpn3 configs-list') if [ "$mode" = empty ]; then printf '{}\\n'; else printf '%s\\n' '${configs}'; fi ;;
 'openvpn3 sessions-list') if [ "$mode" = empty ]; then printf 'No sessions available\\n'; else printf 'Path: /net/openvpn/v3/sessions/test\\nConfig name: test-vpn\\n'; fi ;;
 'camera ') printf 'camera-scan:complete\\n'; [ "$mode" = empty ] || printf 'test-camera\\n' ;;
esac
exit 0
`;
    for (const name of ["docker", "systemctl", "session-time", "todo.sh", "nmcli", "openvpn3", "camera"])
        await writeFile(path.join(binaries, name), script, { mode: 0o755 });
    await writeFile(path.join(temporary, "shared-camera-users.sh"), 'exec camera\n');
    await writeFile(path.join(temporary, "mode"), "nonzero\n");
    await writeFile(path.join(binaries, "query-error-mode"), '#!/bin/sh\nprintf "%s\\n" "$1" > "$QUERY_ERROR_DIRECTORY/mode"\n', { mode: 0o755 });
    await writeFile(path.join(temporary, "shell.qml"), `import Quickshell
import Quickshell.Io
import QtQuick
ShellRoot {
    id: root
    property int phase: 0
    property var providers: [SharedDockerProvider, SharedSystemdProvider, SharedSessionProvider, SharedTodoProvider, SharedNetworkProvider, SharedPrivacyProvider]
    Component { PrivacyWidget { barWindow: null } }
    Component { DockerWidget { barWindow: null } }
    Component { NetworkWidget { barWindow: null } }
    Component { TodoWidget { barWindow: null } }
    Component { SystemdFailedUnits {} }
    Component { SessionTimeWidget {} }
    function check(condition, message) { if (!condition) { console.error("QUERY_ERROR_FAILED", phase, message); Qt.quit(); } }
    function refresh() {
        SharedDockerProvider.refresh(); SharedSystemdProvider.refresh(); SharedSessionProvider.refresh();
        SharedTodoProvider.refresh(); SharedNetworkProvider.refreshNm(); SharedNetworkProvider.refreshOpenvpn(); SharedPrivacyProvider.refresh();
    }
    Process {
        id: mode
        onExited: root.refresh()
    }
    Component.onCompleted: refresh()
    Timer {
        interval: 800; running: true; repeat: true
        onTriggered: {
            const expected = ["unavailable", "ready", "stale", "stale", "ready", "stale", "ready"][root.phase];
            const statuses = [SharedDockerProvider.status, SharedSystemdProvider.status, SharedTodoProvider.status, SharedNetworkProvider.nmStatus, SharedNetworkProvider.openvpnStatus, SharedPrivacyProvider.cameraStatus];
            for (const status of statuses) root.check(status === expected, "status " + status + " expected " + expected);
            if (root.phase === 2 || root.phase === 3) root.check(SharedDockerProvider.containers.length === 1 && SharedPrivacyProvider.camApps.length === 1, "last known activity");
            if (root.phase === 4 || root.phase === 5) root.check(SharedDockerProvider.containers.length === 0 && SharedTodoProvider.tasks.length === 0 && SharedNetworkProvider.openvpn3Profiles.length === 0, "successful empty/stale empty");
            if (root.phase === 6) {
                root.check(SharedDockerProvider.actionFailed && SharedTodoProvider.actionFailed && SharedNetworkProvider.nmActionFailed && SharedNetworkProvider.openvpnActionFailed, "action failures retained across successful queries");
                console.log("QUERY_ERROR_PASSED"); Qt.quit(); return;
            }
            root.phase++;
            mode.command = ["query-error-mode", ["nonzero", "valid", "malformed", "nonzero", "empty", "nonzero", "valid"][root.phase]];
            mode.running = true;
            if (root.phase === 2) {
                SharedDockerProvider.stopContainer("abc"); SharedTodoProvider.addTask("draft");
                SharedNetworkProvider.nmVpnConnect("uuid"); SharedNetworkProvider.openvpn3Connect("/config/test");
            }
        }
    }
}
`);
    const result = spawnSync("quickshell", ["--path", path.join(temporary, "shell.qml"), "--no-color"], {
        encoding: "utf8", timeout: 10000,
        env: { ...process.env, QT_QPA_PLATFORM: "offscreen", PATH: `${binaries}:${process.env.PATH}`, QUERY_ERROR_DIRECTORY: temporary },
    });
    const output = result.stdout + result.stderr;
    assert.equal(result.error, undefined, output);
    assert.match(output, /QUERY_ERROR_PASSED/, output);
    assert.doesNotMatch(output, /QUERY_ERROR_FAILED|Failed to load configuration|ReferenceError|TypeError|Binding loop/, output);
    // Scan an isolated fake sysfs/procfs tree. Test expected permission limits
    // separately from unexpected scan errors without reading host descriptors.
    const fakeSystem = path.join(temporary, "sys");
    const fakeProcesses = path.join(temporary, "proc");
    await mkdir(path.join(fakeSystem, "video0"), { recursive: true });
    await mkdir(path.join(fakeProcesses, "42", "fd"), { recursive: true });
    await writeFile(path.join(fakeSystem, "video0", "name"), "Test camera\n");
    await writeFile(path.join(fakeProcesses, "42", "comm"), "camera-app\n");
    const cameraScript = (await readFile(path.join(directory, "shared-camera-users.sh"), "utf8"))
        .replaceAll("/sys/class/video4linux", fakeSystem).replace(/\/proc(?=\/)/g, fakeProcesses);
    const cameraPath = path.join(temporary, "query-error-camera.sh");
    await writeFile(cameraPath, cameraScript);
    await writeFile(path.join(binaries, "find"), `#!/bin/sh
case "$CAMERA_TEST_MODE" in
 complete) printf '%s\\t/dev/video0\\n' '/proc/42/fd/1';;
 limited) echo 'find: Permission denied' >&2; exit 1;;
 broken) echo 'find: Input/output error' >&2; exit 1;;
esac
`, { mode: 0o755 });
    for (const [mode, expected, code] of [["complete", "camera-scan:complete\ncamera-app\n", 0], ["limited", "camera-scan:limited\n", 0], ["broken", "", 1]]) {
        const scan = spawnSync("sh", [cameraPath], { encoding: "utf8", timeout: 3000, env: { ...process.env, PATH: `${binaries}:${process.env.PATH}`, CAMERA_TEST_MODE: mode } });
        assert.equal(scan.status, code, scan.stderr);
        assert.equal(scan.stdout, expected);
        if (mode === "broken") assert.match(scan.stderr, /Input\/output error/);
    }
    console.log("Query error tests passed: parsing, unavailable/stale/empty/recovery, mocked QML subprocess/action failures, and camera scan errors.");
} finally {
    await rm(temporary, { recursive: true, force: true });
}
