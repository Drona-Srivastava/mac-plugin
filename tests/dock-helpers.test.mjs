import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

// The production file is ordinary QML-importable JS, with no Node dependency.
const helpers = vm.createContext({});
vm.runInContext(readFileSync(new URL('../services/DockHelpers.js', import.meta.url), 'utf8'), helpers);
const plain = value => JSON.parse(JSON.stringify(value));
const entry = (id, options = {}) => ({ id, name: id, startupClass: '', categories: [], noDisplay: false, ...options });
const window = (appId, options = {}) => ({ appId, parent: null, ...options });

test('pin validation deduplicates, bounds and rejects unsafe IDs without discarding valid spaces', () => {
    assert.deepEqual(plain(helpers.cleanPins(['app', 'app', '', null, {}, '/tmp/app', '../app', '-arg', 'bad\nline', 'App with spaces'])),
        ['app', 'App with spaces']);
    assert.equal(helpers.cleanPins(Array.from({ length: 100 }, (_, index) => `app-${index}`)).length, 40);
    assert.deepEqual(plain(helpers.cleanPins('not-an-array')), []);
});

test('desktop IDs ending in .desktop are matched exactly before optional filename suffixes', () => {
    const telegram = entry('org.telegram.desktop');
    const entries = helpers.entryIndex([telegram, entry('editor')]);
    assert.equal(helpers.entryForId('org.telegram.desktop', entries), telegram);
    assert.equal(helpers.entryForId('org.telegram.desktop.desktop', entries), telegram);
    assert.equal(helpers.entryForId('editor.desktop', entries).id, 'editor');
    assert.deepEqual(plain(helpers.launchCommand(telegram.id)),
        ['uwsm-app', '--', 'gtk-launch', 'org.telegram.desktop.desktop']);
});

test('launches are argv arrays, not shell interpolation or hardcoded commands', () => {
    const id = 'An App "quoted"; $(touch nope)';
    assert.deepEqual(plain(helpers.launchCommand(id)), ['uwsm-app', '--', 'gtk-launch', `${id}.desktop`]);
    for (const invalid of ['-option', '/bin/sh', 'bad\0id', 'bad\nname', '']) {
        assert.deepEqual(plain(helpers.launchCommand(invalid)), []);
    }
});

test('application identity uses exact IDs and unambiguous StartupWMClass, never display-name guesses', () => {
    const editor = entry('org.example.Editor', { startupClass: 'EditorClass', name: 'Write' });
    const entries = helpers.entryIndex([editor]);
    assert.equal(helpers.entryForApp('ORG.EXAMPLE.EDITOR', entries), editor);
    assert.equal(helpers.entryForApp('editorclass', entries), editor);
    assert.equal(helpers.entryForApp('Write', entries), null);
    assert.equal(helpers.entryForApp('Editor', entries), null);
    const ambiguous = helpers.entryIndex([editor, entry('other', { startupClass: 'editorclass' })]);
    assert.equal(helpers.entryForApp('editorclass', ambiguous), null);
});

test('object prototype names are safe map keys', () => {
    const unusual = entry('__proto__', { startupClass: 'constructor' });
    const entries = helpers.entryIndex([unusual]);
    assert.equal(helpers.entryForApp('__proto__', entries), unusual);
    assert.equal(helpers.entryForApp('constructor', entries), unusual);
});

test('default pins are deterministic installed visible category matches only', () => {
    const apps = [entry('browser-z', { categories: ['WebBrowser'] }), entry('files', { categories: ['FileManager'] }),
        entry('browser-a', { categories: ['WebBrowser'] }), entry('term', { categories: ['TerminalEmulator'] }),
        entry('hidden', { categories: ['FileManager'], noDisplay: true })];
    assert.deepEqual(plain(helpers.defaultPins(apps)), ['files', 'browser-a', 'term']);
    assert.deepEqual(plain(helpers.defaultPins(apps.slice().reverse())), ['files', 'browser-a', 'term']);
    assert.deepEqual(plain(helpers.defaultPins([])), []);
    assert.deepEqual(plain(helpers.defaultPins([entry('hidden', { noDisplay: true })])), []);
    assert.deepEqual(plain(helpers.defaultPins([entry('installed')])), ['installed']);
});

test('pinned order is stable and running windows merge with the matching pin', () => {
    const apps = [entry('browser'), entry('editor', { startupClass: 'Code' }), entry('files')];
    const tops = [window('Code'), window('editor'), window('browser'), window('unknown')];
    const result = helpers.buildGroups(['files', 'editor', 'editor.desktop', 'missing'], apps, tops);
    assert.deepEqual(plain(result.map(group => group.key)), ['desktop:files', 'desktop:editor', 'desktop:browser', 'app:unknown']);
    assert.equal(result[1].windows.length, 2);
    assert.equal(result[1].windows[0], tops[0]);
    assert.equal(result[0].pinned, true);
    assert.equal(result[2].pinned, false);
    assert.equal(result[3].entry, null);
    assert.equal(result[3].desktopId, '');
    assert.equal(result.some(group => group.key === 'desktop:missing'), false);
});

test('dialogs inherit parent identity and anonymous windows remain separate', () => {
    const top = window('editor');
    const dialog = window('', { parent: top });
    const result = helpers.buildGroups([], [entry('editor')], [top, dialog, window(''), window('')]);
    assert.equal(result.length, 3);
    assert.equal(result.find(group => group.desktopId === 'editor').windows.length, 2);
    assert.equal(result.filter(group => group.key.startsWith('window:')).length, 2);
});

test('closed windows disappear completely; no history cache or orphan launcher remains', () => {
    assert.equal(helpers.buildGroups([], [], [window('transient-app')]).length, 1);
    assert.equal(helpers.buildGroups([], [], []).length, 0);
});

test('pin reordering is bounded and never mutates the caller array', () => {
    const pins = ['a', 'b', 'c'];
    assert.deepEqual(plain(helpers.movePin(pins, 'b', -1)), ['b', 'a', 'c']);
    assert.deepEqual(plain(helpers.movePin(pins, 'b', 1)), ['a', 'c', 'b']);
    assert.deepEqual(plain(helpers.movePin(pins, 'a', -1)), pins);
    assert.deepEqual(plain(helpers.movePin(pins, 'c', 1)), pins);
    assert.deepEqual(plain(helpers.movePin(pins, 'missing', 1)), pins);
    assert.deepEqual(pins, ['a', 'b', 'c']);
});
