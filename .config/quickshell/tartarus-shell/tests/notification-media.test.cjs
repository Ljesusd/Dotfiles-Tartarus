const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');
const model = createContext({});
runInContext(readFileSync(join(__dirname, '../services/NotificationMedia.js'), 'utf8'), model);

test('reminder icons are not previews while screenshots and chat avatars remain intact', () => {
    assert.equal(model.notificationPreview('image://icon/appointment-soon', 'test2 · 22:50', 'Tartarus'), '');
    assert.equal(model.notificationPreview('', 'test2 · 22:50', 'Tartarus'), '');
    assert.equal(model.notificationPreview('image://icon/app-icon', 'Saved: /tmp/screenshot.png', 'notify-send'), 'file:///tmp/screenshot.png');
    assert.equal(model.notificationPreview('image://icon//tmp/photo.png', '', 'notify-send'), 'file:///tmp/photo.png');
    assert.equal(model.notificationPreview('/tmp/avatar.png', 'Hola', 'Vesktop'), '');
    assert.equal(model.avatar('/tmp/avatar.png', 'Vesktop'), 'file:///tmp/avatar.png');
});

test('preserves supported URL schemes instead of prepending file to HTTP', () => {
    for (const url of ['https://example.com/picture.png', 'http://example.com/a.jpg',
        'file:///tmp/image.png', 'image://quickshell/notification/1', 'data:image/png;base64,abc'])
        assert.equal(model.source(url), url);
    assert.equal(model.source('/tmp/a b.png'), 'file:///tmp/a b.png');
    assert.equal(model.source('image://icon//tmp/photo.png'), 'file:///tmp/photo.png');
    for (const value of ['', null, undefined, {}, 'javascript:alert(1)', 'relative.png'])
        assert.equal(model.source(value), '');
});
test('body attachment is preferred to sender avatar and extracted without altering text', () => {
    const body = 'Hola <b>imagen</b><img src="https://example.com/photo.png?a=1&amp;b=2" alt="Adjunto">';
    assert.equal(model.preview('/tmp/avatar.png', body), 'https://example.com/photo.png?a=1&b=2');
    assert.equal(model.textBody(body), 'Hola <b>imagen</b>');
    assert.equal(model.preview('/tmp/photo.png', 'No inline image'), 'file:///tmp/photo.png');
});
test('single quotes, unquoted src and unsupported sources are handled', () => {
    assert.equal(model.bodyImage("<IMG SRC='/tmp/photo.png'>"), 'file:///tmp/photo.png');
    assert.equal(model.bodyImage('<img src=https://example.com/photo.png>'), 'https://example.com/photo.png');
    assert.equal(model.bodyImage('<img src="javascript:bad"><img src="/tmp/good.png">'), 'file:///tmp/good.png');
    assert.equal(model.bodyImage('<img alt="missing source">'), '');
});
test('history keeps stable image URLs but never stores process-owned images', () => {
    assert.equal(model.persistentImage('image://quickshell/notification/1', ''), '');
    assert.equal(model.persistentImage('image://quickshell/notification/1', '<img src="/tmp/photo.png">'), 'file:///tmp/photo.png');
    assert.equal(model.persistentImage('/tmp/photo.png', ''), 'file:///tmp/photo.png');
    assert.equal(model.persistentImage('image://icon//tmp/photo.png', ''), 'file:///tmp/photo.png');
    assert.equal(model.persistentImage('image://icon/app-icon', ''), '');
});
