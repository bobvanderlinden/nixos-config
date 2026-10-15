// Run with: dbus-run-session -- node tests/notification-ownership.test.mjs
// Uses a private notification daemon, never the desktop's session bus.
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { mkdtempSync, copyFileSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

assert.ok(process.env.DBUS_SESSION_BUS_ADDRESS, 'Run under dbus-run-session');
// Refuse to start a daemon on an already-owned notification service.
const existingServices = execFileSync('busctl', ['--user', '--no-pager', 'list'], { encoding: 'utf8' });
assert.ok(!existingServices.includes('org.freedesktop.Notifications'), 'Notification service already exists; use a private bus');
const directory = mkdtempSync(join(tmpdir(), 'notification-ownership-'));
copyFileSync('home/profiles/quickshell/NotificationService.qml', join(directory, 'NotificationService.qml'));
writeFileSync(join(directory, 'shell.qml'), `
import Quickshell
import Quickshell.Io
import QtQuick
ShellRoot {
    id: root
    property var service: NotificationService
    property var held: null
    IpcHandler {
        target: "test"
        function count(): string { return String(NotificationService.notifications.length); }
        function hold(): void {
            root.held = NotificationService.notifications[0];
            root.held.retainView();
            root.held.retainView();
        }
        function dismissTwice(): void { root.held.dismiss(); root.held.dismiss(); }
        function expireTwice(): void { root.held.expire(); root.held.expire(); }
        function activateTwice(): void { root.held.activate(); root.held.activate(); }
        function summary(): string { return root.held.summary; }
        function debug(): string { return JSON.stringify({ count: NotificationService.notifications.length, held: !!root.held, views: root.held?.viewCount, closed: root.held?.closed, notification: !!root.held?.notification, retained: root.held?.lifetimeLock.retained }); }
        function release(): void { root.held.releaseView(); root.held.releaseView(); root.held = null; }
    }
}
`);
let logs = '';
const child = spawn('quickshell', ['--path', directory, '--no-color'], {
    env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', WAYLAND_DISPLAY: '', DISPLAY: '' },
    stdio: ['ignore', 'pipe', 'pipe'],
});
child.stdout.on('data', output => { logs += output; });
child.stderr.on('data', output => { logs += output; });
const environment = { ...process.env, QT_QPA_PLATFORM: 'offscreen', WAYLAND_DISPLAY: '', DISPLAY: '' };
function call(method) {
    return execFileSync('quickshell', ['ipc', '--path', directory, 'call', 'test', method], {
        env: environment, encoding: 'utf8', timeout: 3000, stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
}
function notify({ timeout = 0, replaces = 0, summary = 'original', actions = [], resident = false } = {}) {
    const hints = resident ? ['1', 'resident', 'b', 'true'] : ['0'];
    const output = execFileSync('busctl', ['--user', '--', 'call', 'org.freedesktop.Notifications',
        '/org/freedesktop/Notifications', 'org.freedesktop.Notifications', 'Notify',
        'susssasa{sv}i', 'test', String(replaces), '', summary, 'body', String(actions.length), ...actions,
        ...hints, String(timeout)], { encoding: 'utf8', timeout: 3000 });
    return Number(output.trim().split(' ')[1]);
}
async function waitCount(expected, milliseconds = 1500) {
    const deadline = Date.now() + milliseconds;
    while (Date.now() < deadline) {
        if (call('count') === String(expected)) return;
        await delay(25);
    }
    assert.equal(call('count'), String(expected));
}
try {
    let startupError;
    for (let attempt = 0; attempt < 60; attempt++) {
        try { call('count'); startupError = null; break; }
        catch (error) { startupError = error; await delay(50); }
    }
    if (startupError) throw startupError;

    notify();
    await waitCount(1);
    call('hold');
    await delay(250);
    assert.equal(call('count'), '1', 'zero timeout stays persistent');
    call('dismissTwice');
    assert.equal(call('count'), '0');
    assert.equal(call('summary'), 'original', 'data survives removal with two view references');
    call('release');

    notify({ timeout: 700 });
    await waitCount(1);
    call('hold');
    await waitCount(0);
    call('dismissTwice');
    call('expireTwice');
    assert.equal(call('summary'), 'original', call('debug'));
    call('release');

    notify({ actions: ['default', 'Open'] });
    await waitCount(1);
    call('hold');
    call('activateTwice');
    assert.equal(call('count'), '0', 'action-induced closure is observed synchronously');
    call('dismissTwice');
    call('release');

    notify({ actions: ['default', 'Open'], resident: true });
    await waitCount(1);
    call('hold');
    call('activateTwice');
    assert.equal(call('count'), '1', 'resident action does not dismiss');
    call('dismissTwice');
    call('release');

    const original = notify({ timeout: 1500 });
    await waitCount(1);
    call('hold');
    await delay(800);
    assert.equal(notify({ replaces: original, timeout: 1500, summary: 'replacement' }), original);
    assert.equal(call('count'), '1', 'replacement reuses wrapper');
    assert.equal(call('summary'), 'replacement');
    await delay(800);
    assert.equal(call('count'), '1', 'replacement resets expiry');
    await waitCount(0);
    call('release');

    const external = notify();
    await waitCount(1);
    call('hold');
    execFileSync('busctl', ['--user', 'call', 'org.freedesktop.Notifications',
        '/org/freedesktop/Notifications', 'org.freedesktop.Notifications', 'CloseNotification',
        'u', String(external)], { timeout: 3000 });
    await waitCount(0);
    call('dismissTwice');
    call('activateTwice');
    assert.equal(call('summary'), 'original', 'external closure also retains exit data');
    call('release');

    notify({ timeout: -1 });
    await waitCount(1);
    await delay(300);
    assert.equal(call('count'), '1', 'negative timeout uses default rather than immediate expiry');
    await waitCount(0, 5500);

    // Also guard the monitor views against acquiring lifetime authority again.
    const popup = readFileSync('home/profiles/quickshell/NotificationPopup.qml', 'utf8');
    const workspace = readFileSync('home/profiles/quickshell/WorkspaceNotificationPopup.qml', 'utf8');
    const shell = readFileSync('home/profiles/quickshell/shell.qml', 'utf8');
    assert.ok(!shell.includes('NotificationServer {'));
    assert.match(readFileSync('home/profiles/quickshell/NotificationService.qml', 'utf8'), /keepOnReload: false/);
    assert.ok(!popup.includes('onTriggered: if (notification) notification.dismiss()'));
    assert.ok(!workspace.includes('Timer {'));
    console.log('Notification ownership tests passed');
} catch (error) {
    console.error(logs);
    throw error;
} finally {
    child.kill('SIGTERM');
    await new Promise(resolve => child.exitCode !== null ? resolve() : child.once('exit', resolve));
    rmSync(directory, { recursive: true, force: true });
    if (/TypeError|ReferenceError|Cannot (close|invoke) destroyed/.test(logs)) console.error(logs);
}
assert.ok(!/Cannot (close|invoke) destroyed notification|TypeError|ReferenceError|Error loading configuration/.test(logs), logs);
