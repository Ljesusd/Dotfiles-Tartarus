const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');
const model = createContext({});
runInContext(readFileSync(join(__dirname, '../plugins/workspaces/WorkspaceModel.js'), 'utf8'), model);
const workspace = (id, name, windows = 1) => ({ id, monitor: { name }, toplevels: { values: Array(windows).fill({}) } });
const ids = (workspaces, name, active, empty = false) =>
    Array.from(model.idsForScreen(workspaces, name, active, name === 'HDMI-A-1' ? 6 : 1, 5, empty));

test('a surviving HDMI monitor includes migrated workspaces 1 and 2, plus its own 6', () => {
    assert.deepEqual(ids([workspace(6, 'HDMI-A-1'), workspace(1, 'HDMI-A-1'),
        workspace(2, 'HDMI-A-1'), workspace(-98, 'HDMI-A-1')], 'HDMI-A-1', 2), [1, 2, 6]);
});
test('ownership changes are reflected when the second monitor reconnects', () => {
    const workspaces = [workspace(1, 'DP-2'), workspace(2, 'DP-2'), workspace(6, 'HDMI-A-1')];
    assert.deepEqual(ids(workspaces, 'HDMI-A-1', 6), [6]);
    assert.deepEqual(ids(workspaces, 'DP-2', 1), [1, 2]);
    workspaces[0].monitor = { name: 'HDMI-A-1' };
    assert.deepEqual(ids(workspaces, 'HDMI-A-1', 1), [1, 6]);
});
test('empty active workspace outside the configured range is always included', () => {
    assert.deepEqual(ids([workspace(1, 'HDMI-A-1', 0), workspace(6, 'HDMI-A-1', 0)], 'HDMI-A-1', 1), [1]);
    assert.deepEqual(ids([], 'HDMI-A-1', 15), [15]);
});
test('unknown screen has no unrelated workspaces; special and empty workspaces are excluded', () => {
    assert.deepEqual(ids([workspace(6, 'HDMI-A-1')], '', -1), []);
    assert.deepEqual(ids([workspace(-99, 'HDMI-A-1'), workspace(6, 'HDMI-A-1', 0)], 'HDMI-A-1', -1), []);
});
test('optional empty slots never include a workspace owned by another monitor', () => {
    assert.deepEqual(ids([workspace(6, 'DP-2')], 'HDMI-A-1', 7, true), [7, 8, 9, 10]);
});
test('IPC-style string monitor names work and duplicate IDs are removed', () => {
    assert.deepEqual(ids([{ id: 6, monitor: 'HDMI-A-1', windows: 2 },
        { id: 6, monitor: 'HDMI-A-1', windows: 2 }], 'HDMI-A-1', 6), [6]);
});
