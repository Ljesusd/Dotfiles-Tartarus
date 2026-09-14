// Run: node .config/quickshell/tartarus-shell/tests/notification-lifecycle.test.cjs
// Exercises the actual service methods with isolated ListModel/D-Bus doubles.
// This is not a substitute for testing NotificationServer with real clients.
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

const source = readFileSync(join(__dirname, '../services/NotificationService.qml'), 'utf8');

class Model {
    rows = [];
    get count() { return this.rows.length; }
    get(i) { return this.rows[i]; }
    set(i, value) { this.rows[i] = { ...value }; }
    insert(i, value) { this.rows.splice(i, 0, { ...value }); }
    append(value) { this.insert(this.count, value); }
    remove(i) { this.rows.splice(i, 1); }
    clear() { this.rows = []; }
    move(from, to, count) { this.rows.splice(to, 0, ...this.rows.splice(from, count)); }
    ids() { return this.rows.map(row => String(row.notificationId)); }
}

function fixture() {
    const historyModel = new Model();
    const notificationModel = new Model();
    const Hyprland = { focusedMonitor: { name: 'DP-2' } };
    let saved = '[]';
    let time = 1000;
    const historyFile = { text: () => saved, setText: value => { saved = value; } };
    const root = {
        sessionId: 'isolated-test', historyLimit: 100, dnd: false,
        notificationObjects: {}, notificationActionObjects: {},
    };
    const context = createContext({
        root, historyModel, notificationModel, historyFile, Hyprland,
        notificationObjects: root.notificationObjects,
        notificationActionObjects: root.notificationActionObjects,
        Date: { now: () => ++time }, console,
    });
    for (const match of source.matchAll(/^    function (\w+)\([^]*?^    }/gm)) {
        runInContext(match[0], context);
        root[match[1]] = context[match[1]];
    }
    assert.equal(typeof root.add, 'function');
    assert.equal(typeof root.removeHistory, 'function');
    function notification(id, body = 'Initial', actions = []) {
        return {
            id, body, actions, appName: 'Test', summary: 'Same title', image: '',
            tracked: false, dismissCalls: 0,
            // A close can synchronously emit closed and remove its model row.
            dismiss() { this.dismissCalls++; root.remove(this.id); },
        };
    }
    return { root, historyModel, notificationModel, Hyprland, notification, historyFile };
}

test('replacement updates one entity and retains its original monitor', () => {
    const f = fixture();
    f.root.add(f.notification(1));
    f.root.add(f.notification(2));
    f.Hyprland.focusedMonitor = { name: 'HDMI-A-1' };
    const update = f.notification(1, 'Final');
    f.root.add(update);
    assert.equal(f.notificationModel.count, 2);
    assert.equal(f.historyModel.count, 2);
    assert.deepEqual(f.historyModel.ids(), ['1', '2']);
    assert.equal(f.historyModel.get(0).body, 'Final');
    const popup = f.notificationModel.rows.find(row => row.notificationId === 1);
    assert.equal(popup.body, 'Final');
    assert.equal(popup.screenName, 'DP-2');
    assert.equal(f.root.notificationObjects['1'], update);
});

test('same title and application with different IDs never merges', () => {
    const f = fixture();
    for (const id of [1, 2, 3]) f.root.add(f.notification(id));
    assert.deepEqual(f.historyModel.ids(), ['3', '2', '1']);
    assert.deepEqual(f.notificationModel.ids(), ['3', '2', '1']);
});

test('replacement invokes only the current action object', () => {
    const f = fixture();
    let oldCalls = 0, newCalls = 0;
    f.root.add(f.notification(1, 'Initial', [{ identifier: 'default', text: 'Open', invoke: () => oldCalls++ }]));
    f.root.add(f.notification(1, 'Final', [{ identifier: 'default', text: 'Open', invoke: () => newCalls++ }]));
    f.root.invokeAction(1, 'default');
    assert.equal(oldCalls, 0);
    assert.equal(newCalls, 1);
});

test('deleting a live history entity dismisses only its own popup', () => {
    const f = fixture();
    const items = [1, 2, 3].map(id => f.notification(id));
    items.forEach(item => f.root.add(item));
    f.root.removeHistory(1); // B, between C and A
    assert.deepEqual(f.historyModel.ids(), ['3', '1']);
    assert.deepEqual(f.notificationModel.ids(), ['3', '1']);
    assert.deepEqual(items.map(item => item.dismissCalls), [0, 1, 0]);
    assert.equal(f.root.notificationObjects['2'], undefined);
    assert.equal(f.root.notificationActionObjects['2'], undefined);
    assert.deepEqual(JSON.parse(f.historyFile.text()).map(row => row.notificationId), ['3', '1']);
});

test('deleting expired history does not close another active popup', () => {
    const f = fixture();
    f.root.add(f.notification(1));
    const other = f.notification(2);
    f.root.add(other);
    f.root.remove(1); // backend closed/expired A, retaining history
    f.root.removeHistory(1);
    assert.deepEqual(f.historyModel.ids(), ['2']);
    assert.deepEqual(f.notificationModel.ids(), ['2']);
    assert.equal(other.dismissCalls, 0);
});

test('restored history with a reused server ID cannot close a new notification', () => {
    const f = fixture();
    f.root.add(f.notification(1, 'Previous session'));
    f.root.remove(1);
    f.root.loadHistory();
    const current = f.notification(1, 'Current session');
    f.root.add(current);
    assert.equal(f.historyModel.count, 2);
    f.root.removeHistory(1);
    assert.equal(current.dismissCalls, 0);
    assert.equal(f.notificationModel.count, 1);
    assert.equal(f.historyModel.get(0).body, 'Current session');
});

test('invalid history indices and duplicate close callbacks are harmless', () => {
    const f = fixture();
    f.root.add(f.notification(1));
    f.root.removeHistory(-1);
    f.root.removeHistory(1);
    assert.equal(f.historyModel.count, 1);
    f.root.close(1);
    f.root.remove(1);
    f.root.close(1);
    assert.equal(f.notificationModel.count, 0);
    assert.equal(f.historyModel.count, 1);
});

test('DND records replacements without allowing a popup', () => {
    const f = fixture();
    f.root.dnd = true;
    f.root.add(f.notification(1));
    f.root.add(f.notification(1, 'Updated silently'));
    assert.equal(f.historyModel.count, 1);
    assert.equal(f.historyModel.get(0).body, 'Updated silently');
    assert.equal(f.root.popupVisible(1, 'DP-2', 3), false);
});
