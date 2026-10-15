const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

const source = readFileSync(join(__dirname, '../launcher/LauncherModes.js'), 'utf8');
function load() {
    const context = createContext({});
    runInContext(source, context);
    return context;
}

test('store opens without a search term, including spaces and uppercase', () => {
    const { Mode, resolve } = load();
    for (const query of ['>store', '>store ', ' >STORE ', '>store Whisp', '>store\tVLC'])
        assert.equal(resolve(query), Mode.Store);
});

test('backslash routes to the local Rashin page', () => {
    const { Mode, resolve } = load();
    for (const query of ['\\', '\\ ', '\\ what monitor is active'])
        assert.equal(resolve(query), Mode.Rashin);
});

test('partial commands stay in actions; ordinary app searches do not open store', () => {
    const { Mode, resolve } = load();
    for (const query of ['>', '>sto', '>storefront', '>stores'])
        assert.equal(resolve(query), Mode.Actions);
    for (const query of ['', 'store', 'steam'])
        assert.equal(resolve(query), Mode.Applications);
});

test('existing launcher pages retain their routing', () => {
    const { Mode, resolve } = load();
    for (const [query, page] of [
        ['>docker activos', 'Docker'], ['>calc 1+1', 'Calculator'],
        ['>weather', 'Weather'], ['>install', 'Installer'], ['>installer', 'Installer'],
        ['>scheme nord', 'Schemes'], ['>wallpaper beach', 'Wallpaper']
    ]) assert.equal(resolve(query), Mode[page]);
});

test('all page ids are finite, unique and identical after a module reload', () => {
    const first = load(), second = load();
    const ids = Object.values(first.Mode);
    assert.ok(ids.every(Number.isInteger));
    assert.equal(new Set(ids).size, ids.length);
    assert.deepEqual(Object.values(second.Mode), ids);
    assert.equal(second.resolve('>store'), first.Mode.Store);
    assert.equal(second.resolve('\\ status'), first.Mode.Rashin);
});

test('controller and surface use the same reloadable mode definitions', () => {
    for (const file of ['LauncherController.qml', 'Launcher.qml']) {
        const qml = readFileSync(join(__dirname, '../launcher', file), 'utf8');
        assert.match(qml, /import "LauncherModes\.js" as Modes/);
        assert.match(qml, /Modes\.Mode\.Store/);
        assert.doesNotMatch(qml, /LauncherController\.Mode|enum Mode/);
    }
});
