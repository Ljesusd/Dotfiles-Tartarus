const { readFileSync, mkdtempSync, mkdirSync, writeFileSync, symlinkSync, rmSync } = require('node:fs');
const { join, resolve } = require('node:path');
const { tmpdir } = require('node:os');
const { spawnSync } = require('node:child_process');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

const serviceSource = readFileSync(join(__dirname, '../services/RashinService.qml'), 'utf8');

function fixture() {
    const root = {
        enabled: true, busy: true, backendAvailable: true, daemonAvailable: true,
        controlScript: '/test/rashin-control.sh', daemonUrl: 'http://127.0.0.1:3610',
        endpoint: 'http://127.0.0.1:8081/v1', model: 'test-model', vaultPath: '/test/vault',
        pendingQuestion: 'queued prompt', turnVisible: true,
        permissionRequestId: 'permission', permissionTitle: 'permission', permissionOptions: [],
        startupProbeTimer: { running: true, stop() { this.running = false; }, start() { this.running = true; } },
        settingsFile: { setText(value) { root.saved = JSON.parse(value); } },
    };
    for (const name of ['askProcess', 'daemonAskProcess', 'probeProcess', 'daemonProbeProcess',
        'indexProcess', 'permissionProcess', 'openDashboardProcess', 'setupHermesProcess']) {
        root[name] = { running: true, command: [] };
    }
    root.serviceControlProcess = { running: false, command: [] };
    Object.defineProperty(root, 'serviceTransition', { get: () => root.serviceControlProcess.running });
    const context = createContext({ root });
    for (const match of serviceSource.matchAll(/^    function (\w+)\([^]*?^    }/gm)) {
        runInContext(match[0], context);
        root[match[1]] = context[match[1]];
    }
    return root;
}

test('off stops local clients, clears pending work and persists the desired state', () => {
    const root = fixture();
    root.setEnabled(false);
    assert.equal(root.saved.enabled, false);
    assert.equal(root.busy, false);
    assert.equal(root.backendAvailable, false);
    assert.equal(root.daemonAvailable, false);
    assert.equal(root.pendingQuestion, '');
    assert.equal(root.permissionRequestId, '');
    assert.equal(root.turnVisible, false);
    assert.equal(root.startupProbeTimer.running, false);
    for (const name of ['askProcess', 'daemonAskProcess', 'probeProcess', 'daemonProbeProcess',
        'indexProcess', 'permissionProcess', 'openDashboardProcess', 'setupHermesProcess']) {
        assert.equal(root[name].running, false, name);
    }
    assert.deepEqual(Array.from(root.serviceControlProcess.command), ['bash', root.controlScript, 'disable']);
});

test('disabled UI ignores stale probe, stream and index responses', () => {
    const root = fixture(); root.setEnabled(false);
    root.handleProbe('{"available":true}');
    root.handleDaemonProbe('{"running":true,"providerAvailable":true}');
    root.handleAskEvent('{"type":"connected"}');
    root.handleDaemonEvent('{"type":"connected"}');
    root.handleIndex('{"ok":true}');
    root.probe(); root.startDirectProbe();
    assert.equal(root.backendAvailable, false);
    assert.equal(root.daemonAvailable, false);
    assert.equal(root.probeProcess.running, false);
    assert.equal(root.daemonProbeProcess.running, false);
    assert.equal(root.busy, false);
});

test('opening the dashboard while disabled does not restart a service', () => {
    const root = fixture(); root.setEnabled(false);
    root.openDashboard();
    assert.equal(root.openDashboardProcess.running, false);
    assert.match(root.errorText, /Activa Rashin/);
    root.enabled = true; root.serviceControlProcess.running = false;
    root.openDashboard();
    assert.deepEqual(Array.from(root.openDashboardProcess.command), ['xdg-open', root.daemonUrl]);
});

test('an off request during startup is serialized after the in-flight command', () => {
    const root = fixture(); root.setEnabled(true);
    assert.equal(root.serviceControlProcess.command[2], 'enable');
    root.setEnabled(false);
    assert.equal(root.serviceControlProcess.command[2], 'enable');
    root.serviceControlProcess.running = false;
    root.finishServiceChange(0, '');
    assert.equal(root.serviceControlProcess.command[2], 'disable');
    root.serviceControlProcess.running = false;
    root.finishServiceChange(0, '');
    assert.equal(root.statusText, 'Desactivado · modelo detenido');
    assert.equal(root.startupProbeTimer.running, false);
});

test('startup probes/indexes only after successful activation', () => {
    const root = fixture();
    let probes = 0, indexes = 0;
    root.probe = () => probes++;
    root.index = () => indexes++;
    root.setEnabled(true);
    assert.equal(probes + indexes, 0);
    root.serviceControlProcess.running = false;
    root.finishServiceChange(0, '');
    assert.equal(probes, 1); assert.equal(indexes, 1);
    assert.equal(root.startupProbeTimer.running, true);
});

test('shutdown failures are visible rather than reported as success', () => {
    const root = fixture(); root.setEnabled(false);
    root.serviceControlProcess.running = false;
    root.finishServiceChange(1, 'Cannot stop unit');
    assert.match(root.errorText, /Cannot stop unit/);
    assert.equal(root.statusText, 'Error al cambiar los servicios');
});

test('switch passes the new signal value, not its old checked binding', () => {
    const source = readFileSync(join(__dirname, '../shell/RashinSettingsPage.qml'), 'utf8');
    assert.match(source, /onToggled: value => Services\.RashinService\.setEnabled\(value\)/);
});

test('helper only controls its two units, preserving linked definitions without autostart', t => {
    const temp = mkdtempSync(join(tmpdir(), 'rashin-power-test-'));
    t.after(() => rmSync(temp, { recursive: true, force: true }));
    const bin = join(temp, 'bin'), config = join(temp, 'config'), defs = join(temp, 'dotfiles units');
    mkdirSync(bin); mkdirSync(defs); mkdirSync(join(config, 'systemd/user'), { recursive: true });
    const units = ['tartarus-rashin.service', 'tartarus-rashin-llama.service'];
    for (const unit of units) {
        writeFileSync(join(defs, unit), '[Unit]\n');
        symlinkSync(join(defs, unit), join(config, 'systemd/user', unit));
    }
    const log = join(temp, 'calls');
    // No real services are started by this test.
    writeFileSync(join(bin, 'systemctl'), '#!/usr/bin/env node\n' +
        'require("node:fs").appendFileSync(process.env.RASHIN_TEST_LOG, JSON.stringify(process.argv.slice(2))+"\\n");\n' +
        'if(process.env.RASHIN_TEST_FAIL_DISABLE && process.argv[3]==="disable")process.exit(1);\n', { mode: 0o755 });
    const script = resolve(__dirname, '../scripts/rashin-control.sh');
    const env = { ...process.env, PATH: bin + ':' + process.env.PATH, XDG_CONFIG_HOME: config, RASHIN_TEST_LOG: log };
    const result = spawnSync('bash', [script, 'disable'], { env, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    const calls = readFileSync(log, 'utf8').trim().split('\n').map(JSON.parse);
    assert.deepEqual(calls, [
        ['--user', 'stop', ...units], ['--user', 'disable', ...units],
        ['--user', 'link', ...units.map(unit => join(defs, unit))],
    ]);
    const start = spawnSync('bash', [script, 'enable'], { env, encoding: 'utf8' });
    assert.equal(start.status, 0, start.stderr);
    assert.deepEqual(JSON.parse(readFileSync(log, 'utf8').trim().split('\n').at(-1)),
        ['--user', 'enable', '--now', ...units]);
    const invalid = spawnSync('bash', [script, 'anything'], { env, encoding: 'utf8' });
    assert.equal(invalid.status, 2);
    const failure = spawnSync('bash', [script, 'disable'], {
        env: { ...env, RASHIN_TEST_FAIL_DISABLE: '1' }, encoding: 'utf8',
    });
    assert.equal(failure.status, 1);
    assert.equal(JSON.parse(readFileSync(log, 'utf8').trim().split('\n').at(-1))[1], 'link');
});
