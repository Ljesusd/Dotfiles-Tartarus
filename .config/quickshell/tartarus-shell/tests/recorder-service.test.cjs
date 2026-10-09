const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

function fixture() {
    const notices = [], signals = [];
    const root = { available: true, active: false, finishing: false, stopping: false, errorText: '', outputPath: '' };
    const recorderProcess = { running: false, signal: value => signals.push(value) };
    const savedFileProcess = { running: false };
    const availabilityProcess = { running: false };
    const context = createContext({ root, recorderProcess, savedFileProcess, availabilityProcess,
        Quickshell: { screens: [{ name: 'DP-2' }, { name: 'HDMI-A-1' }], env: () => "/tmp/recorder test's home" },
        Qt: { formatDateTime: () => '20261009-020000-123' },
        ToastService: { push: (...args) => notices.push(args) }
    });
    const source = readFileSync(join(__dirname, '../services/RecorderService.qml'), 'utf8');
    for (const match of source.matchAll(/^    function (\w+)\([^]*?^    }/gm)) {
        runInContext(match[0], context);
        root[match[1]] = context[match[1]];
    }
    return { root, recorderProcess, savedFileProcess, notices, signals, availabilityProcess };
}

test('starts the selected monitor with separate path arguments and exec ownership', () => {
    const f=fixture(); f.root.start('HDMI-A-1');
    const cmd=f.recorderProcess.command;
    assert.equal(f.recorderProcess.running, true);
    assert.equal(cmd[5], 'HDMI-A-1');
    assert.equal(cmd[6], "/tmp/recorder test's home/Videos/Recordings/recording-20261009-020000-123.mp4");
    assert.match(cmd[2], /exec gpu-screen-recorder -w "\$2" -f 60/);
    assert.ok(!cmd[2].includes("test's home"));
});

test('missing recorder is visible as an error and triggers availability recheck', () => {
    const f=fixture(); f.root.available=false; f.root.start('DP-2');
    assert.equal(f.recorderProcess.running, false);
    assert.equal(f.notices[0][2], 'Grabador no disponible');
    assert.equal(f.availabilityProcess.running, true);
});

test('disconnected, empty and placeholder monitors never start capture', () => {
    for (const name of ['DP-99', '', 'FALLBACK']) {
        const f=fixture(); f.root.start(name);
        assert.equal(f.recorderProcess.running, false);
        assert.equal(f.notices.length, 1);
    }
});

test('active or finalizing recording cannot be replaced', () => {
    for (const state of ['active', 'finishing']) {
        const f=fixture(); f.root[state]=true; f.root.start('DP-2');
        assert.equal(f.recorderProcess.running, false);
    }
});

test('stop sends SIGINT only to the owned process and only once', () => {
    const f=fixture(); f.root.stop(); assert.deepEqual(f.signals, []);
    f.root.active=true; f.root.stop(); f.root.stop();
    assert.deepEqual(f.signals, [2]);
});

test('encoder failure shows diagnostics, never a successful save', () => {
    const f=fixture(); f.root.errorText='Encoder unavailable'; f.root.finishCapture(1);
    assert.equal(f.savedFileProcess.running, false);
    assert.equal(f.notices[0][3], 'Encoder unavailable');
});

test('successful exit checks the file before announcing save', () => {
    const f=fixture(); f.root.outputPath='/tmp/video.mp4'; f.root.finishCapture(0);
    assert.deepEqual(Array.from(f.savedFileProcess.command), ['test', '-s', '/tmp/video.mp4']);
    assert.equal(f.notices.length, 0);
    assert.equal(f.root.finishing, true);
    f.root.finishSave(0);
    assert.equal(f.notices[0][2], 'Grabación guardada');
    assert.equal(f.root.finishing, false);
});

test('missing or empty file is not reported as saved', () => {
    const f=fixture(); f.root.finishSave(1);
    assert.equal(f.notices[0][2], 'No se generó un vídeo');
});

test('Spanish and English queries resolve to the same record action', () => {
    const source=readFileSync(join(__dirname, '../services/LauncherActions.qml'), 'utf8');
    const expression=source.match(/readonly property var actions: ([\s\S]*?)\n\n    function/)[1];
    const root={}; const context=createContext({ root, DockerService: { installed: false } });
    root.actions=runInContext(expression, context);
    for (const match of source.matchAll(/^    function (\w+)\([^]*?^    }/gm)) {
        runInContext(match[0], context); root[match[1]]=context[match[1]];
    }
    for (const query of ['grabador','grabar','grabación','record','Record screen']) {
        assert.equal(root.filtered(query)[0].command, 'record');
    }
});
