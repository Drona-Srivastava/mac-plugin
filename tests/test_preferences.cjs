const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '../manifest.json'), 'utf8'));
assert.equal(manifest.kinds.join(','), 'bar,service');
assert.equal(manifest.entryPoints.service, 'Service.qml');
const code = fs.readFileSync(path.join(__dirname, '../services/Preferences.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(code, ctx);
const plain = x => JSON.parse(JSON.stringify(x));
assert.equal(ctx.normalize(null).dockSize, 48);
assert.equal(ctx.normalize(null).desktopWidgetsEnabled, true);
assert.equal(ctx.normalize(null).weatherEnabled, true);
assert.equal(ctx.normalize(null).use24HourClock, true);
assert.equal(ctx.normalize(null).weatherUnit, 'metric');
assert.equal(ctx.normalize({weatherUnit: 'imperial'}).weatherUnit, 'imperial');
assert.equal(ctx.normalize({weatherUnit: 'invalid'}).weatherUnit, 'metric');
assert.equal(ctx.normalize({desktopWidgetsEnabled: 'false'}).desktopWidgetsEnabled, true);
assert.equal(ctx.normalize({musicEnabled: false}).musicEnabled, false);
assert.equal(ctx.normalize({dockSize: 1000}).dockSize, 72);
assert.equal(ctx.normalize({dockSize: -5}).dockSize, 32);
assert.equal(ctx.normalize({dockSize: NaN}).dockSize, 48);
assert.equal(ctx.normalize({dockEnabled: 'false'}).dockEnabled, true);
assert.deepEqual(plain(ctx.normalize({dockPins: ['a', 'a', 7, '', 'b']}).dockPins), ['a', 'b']);
const original = {
  id: 'drona.mac', position: 'left', transparent: true, centerAnchor: 'omarchy.clock',
  layout: {left: [{id:'omarchy.menu'}, {id:'omarchy.workspaces'}],
    center:[{id:'omarchy.clock', format:'HH:mm'}, {id:'third.party', custom:42}], right:[{id:'omarchy.audio'}]},
  unrelated: 'preserve me'
};
const snapshot = JSON.stringify(original);
const result = plain(ctx.presentation(original, true, '/app.qml', '/settings.qml'));
assert.equal(JSON.stringify(original), snapshot, 'presentation must not mutate the saved layout');
assert.equal(result.layout.right.at(-1).id, 'omarchy.clock');
assert.equal(result.layout.right.at(-1).format, 'HH:mm');
assert.equal(result.layout.center[0].custom, 42);
assert.equal(result.layout.left[0].id, 'omarchy.menu');
assert.equal(result.layout.left[1].id, 'drona.mac.active-app');
assert.equal(result.unrelated, 'preserve me');
assert.equal(result.position, 'top');
const existing = plain(ctx.presentation(original, false, '/app.qml', '/settings.qml'));
assert.deepEqual(existing.layout.center, original.layout.center);
assert.deepEqual(existing.layout.left, original.layout.left);
assert.equal(existing.layout.right.length, original.layout.right.length + 1);
console.log('Preferences and non-destructive bar presentation: all tests passed');
