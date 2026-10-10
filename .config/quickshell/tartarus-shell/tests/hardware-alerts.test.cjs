const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

function fixture() {
    let refreshes = 0;
    const root = { consumers: {}, monitoringEnabled: false, alertCooldown: {},
        alertProc: { running: false, command: [] }, refresh: () => refreshes++ };
    const source = readFileSync(join(__dirname, '../services/HardwareService.qml'), 'utf8');
    const context = createContext({ root });
    for (const name of ['setConsumerActive', 'alert']) {
        const match = source.match(new RegExp(`^    function ${name}\\([^]*?^    }`, 'm'));
        assert.ok(match);
        runInContext(match[0], context);
        root[name] = context[name];
    }
    return { root, refreshes: () => refreshes };
}

test('desktop widgets poll on both monitors without triggering hardware notifications', () => {
    const { root, refreshes } = fixture();
    root.setConsumerActive('desktop-widget-DP-2', true, false);
    root.setConsumerActive('desktop-widget-HDMI-A-1', true, false);
    assert.equal(root.monitoringEnabled, true);
    assert.equal(refreshes(), 2);
    for (const key of ['disk', 'cpu', 'cpuTemp', 'gpuTemp']) root.alert(95, key, 'test');
    assert.equal(root.alertProc.running, false);
    assert.equal(Object.keys(root.alertCooldown).length, 0);
});

test('hardware panels retain alerts, closing the panel leaves widgets polling silently', () => {
    const { root } = fixture();
    root.setConsumerActive('desktop-widget-DP-2', true, false);
    root.setConsumerActive('control-center-hardware', true);
    root.alert(95, 'disk', 'test');
    assert.equal(root.alertProc.running, true);
    root.alertProc.running = false;
    root.setConsumerActive('control-center-hardware', false);
    root.alert(95, 'cpu', 'test');
    assert.equal(root.monitoringEnabled, true);
    assert.equal(root.alertProc.running, false);
    root.setConsumerActive('desktop-widget-DP-2', false);
    assert.equal(root.monitoringEnabled, false);
    root.alert(95, 'gpuTemp', 'test');
    assert.equal(root.alertProc.running, false);
});

test('desktop widget explicitly opts out of alerts', () => {
    const source = readFileSync(join(__dirname, '../shell/DesktopHardwareWidget.qml'), 'utf8');
    assert.match(source, /setConsumerActive\("desktop-widget-" \+ root.monitorName, root.active, false\)/);
});
