const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

function fixture() {
    const root = { wallpapers: [{ name: 'First', path: '/first.png' }], listProcess: { running: false } };
    const context=createContext({ root });
    const source=readFileSync(join(__dirname, '../services/Wallpapers.qml'), 'utf8');
    for (const name of ['updateList', 'refresh']) {
        const match=source.match(new RegExp('^    function '+name+'\\([^]*?^    }', 'm'));
        runInContext(match[0], context); root[name]=context[name];
    }
    return root;
}

test('unchanged wallpapers retain the exact model identity on refresh', () => {
    const root=fixture(), before=root.wallpapers;
    root.updateList(JSON.parse(JSON.stringify(before)));
    assert.equal(root.wallpapers, before);
});

test('added, removed and renamed wallpapers update the model, including an empty directory', () => {
    const root=fixture();
    for (const next of [[{name:'New',path:'/new.png'}], []]) {
        root.updateList(next);
        assert.equal(root.wallpapers, next);
    }
});

test('invalid response does not destroy the cached list', () => {
    const root=fixture(), before=root.wallpapers;
    root.updateList(null); root.updateList({error:'failed'});
    assert.equal(root.wallpapers, before);
});

test('refresh coalesces requests without restarting an in-flight scan', () => {
    const root=fixture(), writes=[];
    let running=false;
    root.listProcess={get running() {return running}, set running(v) {writes.push(v);running=v}};
    root.refresh(); root.refresh(); root.refresh();
    assert.deepEqual(writes, [true]);
});
