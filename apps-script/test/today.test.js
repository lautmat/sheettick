const test = require('node:test');
const assert = require('node:assert/strict');
const {
  WATCH_MAX_TASKS, parseDateCell, watchMoment, watchTitle, watchToday, formatUtc, watchDevice, planDone,
  rowsFromValues, tokenOk,
} = require('../Today.js');

const PARIS_WINTER = 3600; // the watch's UTC offset, in seconds
const NOW = Date.parse('2026-11-24T10:00:00Z'); // 11:00 in Paris
const TODAY = Math.floor((NOW + PARIS_WINTER * 1000) / 86400000);

const task = (fields) => ({
  id: fields.title, status: 0, deleted: false, all_day: false, tz: '', rrule: '', version: 1, sort_order: 0, ...fields,
});
const titles = (reply) => reply.tasks.map((t) => t.ti);

test('reads cells as the app does', () => {
  assert.deepEqual(parseDateCell('2026-11-24'), { wall: Date.UTC(2026, 10, 24), offset: null, dateOnly: true });
  assert.equal(parseDateCell('2026-11-24T09:30:00+01:00').offset, 60);
  assert.equal(parseDateCell('2026-11-24T09:30:00-0530').offset, -330);
  assert.equal(parseDateCell('2026-11-24T09:30:00Z').offset, 0);
  assert.equal(parseDateCell('2026-11-24 09:30').offset, null);
  for (const bad of ['', '  ', 'tomorrow', '2026-02-30', '2026-13-01', '2026-11-24T25:00:00Z', 46000, null, undefined]) {
    assert.equal(parseDateCell(bad), null, String(bad));
  }
  // A date serial (the cell lost its text format) is no date, as in the app.
  assert.equal(parseDateCell(new Date()), null);
});

test('a timed task with a zone is placed at the watch offset; a floating one reads as written', () => {
  const zoned = task({ due_at: '2026-11-24T23:30:00+00:00', tz: 'Europe/London' });
  const m = watchMoment(zoned, PARIS_WINTER);
  assert.equal(new Date(m.wall).toISOString(), '2026-11-25T00:30:00.000Z'); // 00:30 next day in Paris
  const floating = task({ due_at: '2026-11-24T23:30:00+00:00' });
  assert.equal(new Date(watchMoment(floating, PARIS_WINTER).wall).toISOString(), '2026-11-24T23:30:00.000Z');
});

test('an all-day row is its day, whatever time a cell carries', () => {
  const m = watchMoment(task({ due_at: '2026-11-24T18:00:00+01:00', all_day: true }), PARIS_WINTER);
  assert.deepEqual(m, { wall: Date.UTC(2026, 10, 24), timed: false });
  // A date with no time in a row that says timed is all-day too.
  assert.equal(watchMoment(task({ start_at: '2026-11-24T09:00:00+01:00', due_at: '2026-11-26' }), 0).timed, false);
});

test('the due counts, else the start', () => {
  const both = task({ start_at: '2026-11-20', due_at: '2026-11-28', all_day: true });
  assert.equal(watchMoment(both, 0).wall, Date.UTC(2026, 10, 28));
  const startOnly = task({ start_at: '2026-11-20', all_day: true });
  assert.equal(watchMoment(startOnly, 0).wall, Date.UTC(2026, 10, 20));
  const badDue = task({ start_at: '2026-11-20', due_at: 'soon', all_day: true });
  assert.equal(watchMoment(badDue, 0).wall, Date.UTC(2026, 10, 20));
  assert.equal(watchMoment(task({}), 0), null);
});

test('today holds what is due today or overdue, plus tomorrow for after midnight; nothing later', () => {
  const rows = [
    task({ title: 'later', due_at: '2026-11-26', all_day: true }),
    task({ title: 'tomorrow', due_at: '2026-11-25', all_day: true }),
    task({ title: 'today 14:00', due_at: '2026-11-24T14:00:00+01:00', tz: 'Europe/Paris' }),
    task({ title: 'today', due_at: '2026-11-24', all_day: true }),
    task({ title: 'overdue', due_at: '2026-11-22', all_day: true }),
    task({ title: 'no date' }),
  ];
  const reply = watchToday(rows, NOW, PARIS_WINTER);
  assert.equal(reply.ok, true);
  assert.equal(reply.e, TODAY);
  assert.equal(reply.at, NOW / 1000);
  assert.deepEqual(titles(reply), ['overdue', 'today', 'today 14:00', 'tomorrow']);
  assert.deepEqual(reply.tasks.map((t) => t.d), [-2, 0, 0, 1]);
  assert.deepEqual(reply.tasks.map((t) => t.t), [-1, -1, 14 * 60, -1]);
  assert.equal(reply.n0, 3);
  assert.equal(reply.n1, 4);
});

test('done, dropped, deleted and repeating tasks', () => {
  const rows = [
    task({ title: 'done', due_at: '2026-11-24', all_day: true, status: 2 }),
    task({ title: 'wont', due_at: '2026-11-24', all_day: true, status: -1 }),
    task({ title: 'gone', due_at: '2026-11-24', all_day: true, deleted: true }),
    task({ title: 'gone by hand', due_at: '2026-11-24', all_day: true, deleted: 'TRUE' }),
    task({ title: 'daily', due_at: '2026-11-24', all_day: true, rrule: 'RRULE:FREQ=DAILY', version: 7 }),
  ];
  const reply = watchToday(rows, NOW, PARIS_WINTER);
  assert.deepEqual(titles(reply), ['daily']);
  assert.equal(reply.tasks[0].r, 1);
  assert.equal(reply.tasks[0].v, 7);
});

test('same day keeps the manual order, and the list is cut but counted', () => {
  const rows = Array.from({ length: WATCH_MAX_TASKS + 3 }, (_, i) =>
    task({ title: 't' + i, due_at: '2026-11-24', all_day: true, sort_order: WATCH_MAX_TASKS + 3 - i }));
  const reply = watchToday(rows, NOW, PARIS_WINTER);
  assert.equal(reply.tasks.length, WATCH_MAX_TASKS);
  assert.equal(reply.n0, WATCH_MAX_TASKS + 3);
  assert.equal(reply.tasks[0].ti, 't' + (WATCH_MAX_TASKS + 2));
});

test('titles fit on one line', () => {
  assert.equal(watchTitle('  Call\nthe   bank '), 'Call the bank');
  assert.equal(watchTitle(''), '(untitled)');
  assert.equal(watchTitle(null), '(untitled)');
  assert.equal(watchTitle(42), '42');
  const long = watchTitle('x'.repeat(100));
  assert.equal(long.length, 40);
  assert.ok(long.endsWith('...'));
});

test('completing writes status, completion time and the sync columns', () => {
  const row = task({ title: 'pay', version: 4 });
  const plan = planDone(row, 4, Date.parse('2026-11-24T10:05:41.123Z'), 'gmn-1a2b');
  assert.deepEqual(plan, {
    ok: true,
    v: 5,
    changes: {
      status: 2, completed_at: '2026-11-24T10:05:41Z', updated_at: '2026-11-24T10:05:41Z', version: 5, device: 'gmn-1a2b',
    },
  });
});

test('completing refuses what changed, is not open, repeats or is gone; a retry is ok', () => {
  const now = NOW;
  assert.deepEqual(planDone(null, 1, now, 'gmn-0000'), { ok: false, err: 'missing' });
  assert.equal(planDone(task({ version: 5 }), 4, now, 'gmn-0000').err, 'changed');
  assert.equal(planDone(task({ status: -1, version: 4 }), 4, now, 'gmn-0000').err, 'not open');
  assert.equal(planDone(task({ rrule: 'RRULE:FREQ=DAILY', version: 4 }), 4, now, 'gmn-0000').err, 'repeats');
  assert.equal(planDone(task({ deleted: true, version: 4 }), 4, now, 'gmn-0000').err, 'deleted');
  assert.deepEqual(planDone(task({ status: 2, version: 5 }), 4, now, 'gmn-0000'), { ok: true, already: true, v: 5 });
});

test('rows by header, device ids and tokens', () => {
  const rows = rowsFromValues([['id', ' title ', ''], ['a', 'A', 'x'], ['b', 'B']]);
  assert.deepEqual(rows, [{ id: 'a', title: 'A' }, { id: 'b', title: 'B' }]);
  assert.deepEqual(rowsFromValues([]), []);
  assert.equal(watchDevice('1A2B'), 'gmn-1a2b');
  assert.equal(watchDevice('nope'), 'gmn-0000');
  assert.equal(watchDevice(undefined), 'gmn-0000');
  assert.equal(formatUtc(Date.parse('2026-11-24T10:00:00Z')), '2026-11-24T10:00:00Z');
  const secret = 'abcdefghijklmnopqrstuvwx';
  assert.equal(tokenOk(secret, secret), true);
  assert.equal(tokenOk('abcdefghijklmnopqrstuvwy', secret), false);
  assert.equal(tokenOk(undefined, secret), false);
  assert.equal(tokenOk('short', 'short'), false); // a token that short is never accepted
  assert.equal(tokenOk('', ''), false);
});

const { plainNotes, watchDetail, WATCH_NOTES_MAX, WATCH_CHECKLIST_MAX } = require('../Today.js');

test('notes lose their Markdown but keep their text', () => {
  const md = [
    '# Plan',
    '',
    'Call **Dr Lee** at _9am_, see [the site](https://example.com) and `ref 12`.',
    '> quoted',
    '* one',
    '+ two',
    '- [ ] open item',
    '- [x] done item',
    '```js',
    'code_here()',
    '```',
    'snake_case_name stays',
    '',
    '',
    '',
    'end',
  ].join('\r\n');
  assert.equal(plainNotes(md), [
    'Plan',
    '',
    'Call Dr Lee at 9am, see the site and ref 12.',
    'quoted',
    '- one',
    '- two',
    '[ ] open item',
    '[x] done item',
    '',
    'code_here()',
    '',
    'snake_case_name stays',
    '',
    'end',
  ].join('\n'));
  assert.equal(plainNotes(''), '');
  assert.equal(plainNotes(null), '');
  const long = plainNotes('word '.repeat(1000));
  assert.equal(long.length, WATCH_NOTES_MAX);
  assert.ok(long.endsWith('...'));
});

test('a task for the details screen: list name, notes, checklist in order', () => {
  const t = task({ title: 'Pay rent', list_id: 'L1', content: '**Before** Friday', priority: 5, version: 3 });
  const list = { id: 'L1', name: 'Home' };
  const items = [
    { id: 'c2', task_id: 'Pay rent', title: 'Transfer', status: 0, sort_order: 2 },
    { id: 'c1', task_id: 'Pay rent', title: 'Check amount', status: 2, sort_order: 1 },
    { id: 'c3', task_id: 'Pay rent', title: 'Gone', status: 0, sort_order: 3, deleted: true },
    { id: 'c4', task_id: 'other', title: 'Not mine', status: 0, sort_order: 0 },
  ];
  assert.deepEqual(watchDetail(t, list, items), {
    ok: true, id: 'Pay rent', ti: 'Pay rent', ls: 'Home', c: 'Before Friday',
    cl: [{ ti: 'Check amount', s: 1 }, { ti: 'Transfer', s: 0 }], ncl: 2, p: 5, r: 0, v: 3,
  });
  assert.equal(watchDetail(task({ title: 'x', rrule: 'RRULE:FREQ=DAILY' }), null, []).r, 1);
  assert.equal(watchDetail(task({ title: 'x' }), null, []).ls, '');
  assert.deepEqual(watchDetail(null, null, []), { ok: false, err: 'missing' });
  assert.deepEqual(watchDetail(task({ title: 'x', deleted: true }), null, []), { ok: false, err: 'missing' });
  const many = Array.from({ length: WATCH_CHECKLIST_MAX + 5 }, (_, i) => ({ task_id: 'x', title: 'i' + i, sort_order: i }));
  const d = watchDetail(task({ title: 'x' }), null, many);
  assert.equal(d.cl.length, WATCH_CHECKLIST_MAX);
  assert.equal(d.ncl, WATCH_CHECKLIST_MAX + 5);
  assert.equal(watchDetail(task({ title: 'y'.repeat(200) }), null, []).ti.length, 120);
});
