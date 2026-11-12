const test = require('node:test');
const assert = require('node:assert/strict');
const { BACKUP_PREFIX, backupName, expiredBackups } = require('../Retention.js');

const day = 24 * 3600 * 1000;
const snap = (n) => ({ id: 'id' + n, name: BACKUP_PREFIX + 'day ' + n, created: n * day });

test('names are UTC and sort in time order', () => {
  assert.equal(backupName(new Date('2026-11-12T03:00:41Z')), 'SheetTick backup 2026-11-12 03:00Z');
  assert.ok(backupName(new Date('2026-11-12T03:00:00Z')) < backupName(new Date('2026-11-13T03:00:00Z')));
});

test('keeps the newest 30 and returns the rest', () => {
  const files = Array.from({ length: 33 }, (_, i) => snap(i)); // 0 is the oldest
  const out = expiredBackups(files, 30);
  assert.deepEqual(out.map((f) => f.id).sort(), ['id0', 'id1', 'id2']);
});

test('nothing expires at or under the limit', () => {
  assert.deepEqual(expiredBackups(Array.from({ length: 30 }, (_, i) => snap(i)), 30), []);
  assert.deepEqual(expiredBackups([], 30), []);
});

test('order of the input does not matter', () => {
  const files = [snap(5), snap(1), snap(9), snap(3)];
  assert.deepEqual(expiredBackups(files, 2).map((f) => f.id).sort(), ['id1', 'id3']);
});

test('a file that is not a snapshot is never returned, and does not count toward the 30', () => {
  const stray = { id: 'stray', name: 'notes.txt', created: 0 };
  const files = [stray, snap(1), snap(2), snap(3)];
  assert.deepEqual(expiredBackups(files, 2).map((f) => f.id), ['id1']);
  assert.ok(!expiredBackups(files, 0).some((f) => f.id === 'stray'));
});

test('equal creation times fall back to the name, newest name kept', () => {
  const a = { id: 'a', name: BACKUP_PREFIX + '2026-11-12 03:00Z', created: 1 };
  const b = { id: 'b', name: BACKUP_PREFIX + '2026-11-13 03:00Z', created: 1 };
  assert.deepEqual(expiredBackups([a, b], 1).map((f) => f.id), ['a']);
});
