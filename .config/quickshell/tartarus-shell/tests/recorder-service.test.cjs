const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

function fixture() {
    const notices = [], signals = [];
    const settings = {
        fps: 60,
        framerateMode: 'cfr',
        quality: 'very_high',
        codec: 'h264',
        encoder: 'gpu',
        cursor: true,
        outputDirectory: '~/Videos/Recordings',
        captureMode: 'monitor',
        monitorName: '',
        region: { screen: '', x: 0, y: 0, width: 0, height: 0 },
        desktopAudio: false,
        desktopAudioDevice: 'default_output',
        microphone: false,
        microphoneDevice: 'default_input',
        snapshot() { return { ...this }; }
    };
    const root = { available: true, active: false, starting: false, finishing: false,
        stopping: false, paused: false, errorText: '', outputPath: '' };
    const recorderProcess = { running: false, signal: value => signals.push(value) };
    const directoryProcess = { running: false, command: [] };
    const savedFileProcess = { running: false };
    const availabilityProcess = { running: false };
    const context = createContext({ root, recorderProcess, directoryProcess, savedFileProcess, availabilityProcess,
        RecorderSettings: settings,
        Quickshell: { screens: [
            { name: 'DP-2', width: 1920, height: 1080 },
            { name: 'HDMI-A-1', width: 1920, height: 1080 }
        ], env: () => "/tmp/recorder test's home" },
        Qt: { formatDateTime: () => '20261009-020000-123' },
        ToastService: { push: (...args) => notices.push(args) }
    });
    root.directoryProcess = directoryProcess;
    const source = readFileSync(join(__dirname, '../services/RecorderService.qml'), 'utf8');
    for (const match of source.matchAll(/^    function (\w+)\([^]*?^    }/gm)) {
        runInContext(match[0], context);
        root[match[1]] = context[match[1]];
    }
    return { root, recorderProcess, directoryProcess, savedFileProcess, notices, signals, availabilityProcess };
}

test('starts the selected monitor with separate path arguments and exec ownership', () => {
    const f=fixture(); f.root.start('HDMI-A-1');
    f.root.launchRecorder();
    const cmd=f.recorderProcess.command;
    assert.equal(f.recorderProcess.running, true);
    assert.equal(cmd.slice(0, 5).join("|"), 'gpu-screen-recorder|-w|HDMI-A-1|-f|60');
    assert.equal(cmd[cmd.length - 2], '-o');
    assert.equal(cmd[cmd.length - 1], "/tmp/recorder test's home/Videos/Recordings/recording-20261009-020000-123.mp4");
    assert.ok(!cmd.some(value => String(value).includes("test's home") && value !== cmd[cmd.length - 1]));
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

test('builds a region command with optional system and microphone audio', () => {
    const f=fixture();
    const command = f.root.buildCommand({
        fps: 30,
        framerateMode: 'vfr',
        quality: 'high',
        codec: 'hevc',
        encoder: 'gpu',
        cursor: false,
        captureMode: 'region',
        region: { screen: 'DP-2', x: 10, y: 20, width: 640, height: 480 },
        desktopAudio: true,
        desktopAudioDevice: 'default_output',
        microphone: true,
        microphoneDevice: 'default_input'
    }, 'DP-2', '/tmp/video.mp4');
    assert.equal(command.slice(0, 8).join("|"),
        'gpu-screen-recorder|-w|region|-region|640x480+10+20|-f|30|-fm');
    assert.ok(command.includes('-a'));
    assert.equal(command[command.indexOf('-a') + 1], 'default_output|default_input');
    assert.equal(command[command.indexOf('-cursor') + 1], 'no');
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
