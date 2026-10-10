const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

function fixture() {
    let ticks = 0;
    const player = { uniqueId: 5, position: 20, length: 120, canSeek: true,
        positionSupported: true, lengthSupported: true, isPlaying: true,
        positionChanged: () => ticks++ };
    const root = { activePlayer: player, players: [player], preferredPlayer: null };
    const context = createContext({ root, players: root.players });
    const source = readFileSync(join(__dirname, '../services/MediaService.qml'), 'utf8');
    for (const match of source.matchAll(/^    function (\w+)\([^]*?^    }/gm)) {
        runInContext(match[0], context);
        root[match[1]] = context[match[1]];
    }
    return { root, player, ticks: () => ticks };
}

test('media time formatting handles hours and unknown values', () => {
    const { root } = fixture();
    for (const [value, formatted] of [[0, '0:00'], [65, '1:05'], [3661, '1:01:01'], [NaN, '—:—'], [-1, '—:—']])
        assert.equal(root.formatTime(value), formatted);
});
test('seek is bounded and rejects non-finite values', () => {
    const { root, player } = fixture();
    root.seekTo(200, player, 5); assert.equal(player.position, 120);
    root.seekTo(-5, player, 5); assert.equal(player.position, 0);
    root.seekTo(NaN, player, 5); assert.equal(player.position, 0);
});
test('seek cannot target a departed player or a track changed during drag', () => {
    const { root, player } = fixture();
    root.seekTo(90, player, 4); assert.equal(player.position, 20);
    root.seekTo(90, {}, 5); assert.equal(player.position, 20);
    root.players = []; root.seekTo(90, player, 5); assert.equal(player.position, 20);
    root.activePlayer = null; assert.doesNotThrow(() => root.seekTo(90, player, 5));
});
test('unsupported seek, length and position never write to the player', () => {
    for (const key of ['canSeek', 'positionSupported', 'lengthSupported']) {
        const { root, player } = fixture();
        player[key] = false; root.seekTo(60, player, 5);
        assert.equal(player.position, 20);
    }
    const { root, player } = fixture();
    player.length = 0; root.seekTo(60, player, 5); assert.equal(player.position, 20);
});
test('only a live playing player receives position ticks', () => {
    const { root, player, ticks } = fixture();
    root.refreshPosition(); assert.equal(ticks(), 1);
    player.isPlaying = false; root.refreshPosition(); assert.equal(ticks(), 1);
    player.isPlaying = true; root.players = []; root.refreshPosition(); assert.equal(ticks(), 1);
    root.activePlayer = null; assert.doesNotThrow(() => root.refreshPosition());
});
test('selector ignores objects outside the current player list', () => {
    const { root, player } = fixture();
    root.selectPlayer({}); assert.equal(root.preferredPlayer, null);
    root.selectPlayer(player); assert.equal(root.preferredPlayer, player);
});

test('any MPRIS player can provide the widget, including Sung', () => {
    const sung = { identity: 'Sung', desktopEntry: 'sung', trackTitle: 'Sung track', isPlaying: false };
    const browser = { identity: 'Firefox', desktopEntry: 'firefox', trackTitle: 'Browser track', isPlaying: true };
    const { root } = fixture();
    root.players = [browser, sung];
    assert.equal(root.pickPlayer(null), sung);
    assert.equal(root.pickPlayer(sung), sung);
});

test('a browser remains the fallback when Sung has no track', () => {
    const browser = { identity: 'Firefox', desktopEntry: 'firefox', trackTitle: 'Browser track', isPlaying: true };
    const { root } = fixture();
    root.players = [browser, { identity: 'Sung', desktopEntry: 'sung', trackTitle: '' }];
    assert.equal(root.pickPlayer(null), browser);
});
