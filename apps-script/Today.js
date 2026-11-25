// Pure helpers for the watch endpoint (WebApp.js). No Apps Script services in here, so `node --test` can run them.
//
// "Today" is the app's Today list (app/lib/core/tasks/smart_lists.dart): open, undeleted tasks whose due day, or start
// day when there is no due, is today or already past. Dates are read as the app reads them (core/tasks/task_dates.dart),
// in the watch's zone, which the watch sends as its current UTC offset.

var WATCH_MAX_TASKS = 15;
var WATCH_TITLE_MAX = 40;
var DAY_MS = 24 * 3600 * 1000;

var DATE_ONLY_RE = /^(\d{4})-(\d{2})-(\d{2})$/;
var DATE_TIME_RE = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?\s*(Z|[+-]\d{2}(?::?\d{2})?)?$/;

/** The text of a cell, or '' for anything that is not text (a date serial typed by hand reads as no date, as in the app). */
function cellText(value) {
  return typeof value === 'string' ? value : '';
}

/** TRUE as Sheets stores it, or as text typed by hand. */
function isTrue(value) {
  return value === true || String(value).trim().toUpperCase() === 'TRUE';
}

/**
 * A `start_at` or `due_at` cell: {wall, offset, dateOnly}, where `wall` is the clock reading as epoch milliseconds
 * read as if UTC and `offset` the minutes east of UTC it was written with (null when it has none). Null for a blank
 * cell and for text that is not a real moment.
 */
function parseDateCell(value) {
  var text = cellText(value).trim();
  if (!text) return null;
  var m = DATE_ONLY_RE.exec(text);
  if (m) {
    var day = realWall_(m[1], m[2], m[3], '0', '0', '0');
    return day === null ? null : { wall: day, offset: null, dateOnly: true };
  }
  m = DATE_TIME_RE.exec(text);
  if (!m) return null;
  var wall = realWall_(m[1], m[2], m[3], m[4], m[5], m[6] || '0');
  if (wall === null) return null;
  return { wall: wall, offset: offsetMinutes_(m[7]), dateOnly: false };
}

// The seconds are checked but not kept, on purpose: the app holds a moment to the minute (_wallOrNull in
// core/tasks/task_dates.dart), and the watch must order tasks exactly as the app's Today list does.
function realWall_(y, mo, d, h, mi, s) {
  var year = +y, month = +mo, day = +d, hour = +h, minute = +mi, second = +s;
  if (hour > 23 || minute > 59 || second > 59) return null;
  var wall = Date.UTC(year, month - 1, day, hour, minute);
  var back = new Date(wall);
  if (back.getUTCFullYear() !== year || back.getUTCMonth() !== month - 1 || back.getUTCDate() !== day) return null;
  return wall;
}

function offsetMinutes_(text) {
  if (!text) return null;
  if (text === 'Z') return 0;
  var sign = text[0] === '-' ? -1 : 1;
  var digits = text.slice(1).replace(':', '');
  return sign * (+digits.slice(0, 2) * 60 + (digits.length >= 4 ? +digits.slice(2, 4) : 0));
}

/**
 * Where a task sits on the watch: {wall, timed} for its due, else its start, as a clock reading on the watch (epoch
 * milliseconds read as UTC), or null when it has no date. `tzoSec` is the watch's offset from UTC in seconds.
 * An all-day row (all_day, or either cell without a time) is its day. A timed value with a zone and an offset is an
 * instant, shown at the watch's offset; one with no zone is floating and reads as written. (The app also places a
 * zoned value written without an offset by its zone; the app never writes one, so here it reads as written.)
 */
function watchMoment(row, tzoSec) {
  var start = parseDateCell(row.start_at);
  var due = parseDateCell(row.due_at);
  var allDay = isTrue(row.all_day) || (start && start.dateOnly) || (due && due.dateOnly);
  var p = due || start;
  if (!p) return null;
  if (allDay) return { wall: Math.floor(p.wall / DAY_MS) * DAY_MS, timed: false };
  if (!cellText(row.tz).trim() || p.offset === null) return { wall: p.wall, timed: true };
  return { wall: p.wall - p.offset * 60000 + tzoSec * 1000, timed: true };
}

/** The title as the watch shows it: one line, at most `max` characters (WATCH_TITLE_MAX by default). */
function watchTitle(value, max) {
  var limit = max || WATCH_TITLE_MAX;
  var title = String(value === null || value === undefined ? '' : value).replace(/\s+/g, ' ').trim();
  if (!title) return '(untitled)';
  return title.length > limit ? title.slice(0, limit - 3).trimEnd() + '...' : title;
}

var WATCH_DETAIL_TITLE_MAX = 120;
var WATCH_NOTES_MAX = 1200;
var WATCH_CHECKLIST_MAX = 25;

/**
 * Markdown notes as plain text for the watch: links and images keep their text, headings, quotes, emphasis and code
 * marks go, bullets read `- ` and task items `[ ] ` / `[x] `. Cut at WATCH_NOTES_MAX characters.
 */
function plainNotes(value) {
  var s = cellText(value).replace(/\r\n?/g, '\n');
  s = s.replace(/^\s*```[^\n]*$/gm, '');
  s = s.replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1');
  s = s.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');
  s = s.replace(/^\s{0,3}#{1,6}\s+/gm, '');
  s = s.replace(/^\s{0,3}>\s?/gm, '');
  s = s.replace(/^(\s*)[-*+]\s+\[([ xX])\]\s+/gm, function (m, indent, mark) {
    return indent + (mark === ' ' ? '[ ] ' : '[x] ');
  });
  s = s.replace(/^(\s*)[*+]\s+/gm, '$1- ');
  s = s.replace(/(\*\*|__)(\S(?:.*?\S)?)\1/g, '$2');
  s = s.replace(/(^|[\s(])[*_](\S(?:[^*_\n]*?\S)?)[*_](?=[\s).,!?:;]|$)/gm, '$1$2');
  s = s.replace(/~~(.+?)~~/g, '$1');
  s = s.replace(/`([^`\n]+)`/g, '$1');
  s = s.replace(/[ \t]+$/gm, '').replace(/\n{3,}/g, '\n\n').trim();
  return s.length > WATCH_NOTES_MAX ? s.slice(0, WATCH_NOTES_MAX - 3).trimEnd() + '...' : s;
}

/**
 * One task for the watch's details screen: {ok, id, ti, ls, c, cl, ncl, p, r, v}. `ls` is its list's name, `c` its
 * notes as plain text, `cl` its checklist (each {ti, s}, `s` 1 when ticked) in order, cut at WATCH_CHECKLIST_MAX, and
 * `ncl` how many items it has in all. {ok: false, err: 'missing'} when the task is gone.
 */
function watchDetail(task, list, checklistRows) {
  if (!task || isTrue(task.deleted)) return { ok: false, err: 'missing' };
  var items = (checklistRows || [])
    .filter(function (r) { return r && String(r.task_id) === String(task.id) && !isTrue(r.deleted); })
    .sort(function (a, b) { return (Number(a.sort_order) || 0) - (Number(b.sort_order) || 0); });
  return {
    ok: true,
    id: String(task.id),
    ti: watchTitle(task.title, WATCH_DETAIL_TITLE_MAX),
    ls: list && !isTrue(list.deleted) ? watchTitle(list.name) : '',
    c: plainNotes(task.content),
    cl: items.slice(0, WATCH_CHECKLIST_MAX).map(function (r) {
      return { ti: watchTitle(r.title, 60), s: Number(r.status) === 2 ? 1 : 0 };
    }),
    ncl: items.length,
    p: Number(task.priority) || 0,
    r: cellText(task.rrule).trim() ? 1 : 0,
    v: Number(task.version) || 0,
  };
}

/**
 * The reply to the watch: today's tasks, and tomorrow's so the list stays right past midnight until the next fetch.
 * `rows` are task rows keyed by column name, `nowMs` the current time, `tzoSec` the watch's UTC offset in seconds.
 *
 * {ok, e, at, n0, n1, tasks}: `e` is the watch's day as days since 1970, `at` the time of the reply in epoch seconds,
 * `n0` how many tasks are due today or earlier and `n1` the same counting tomorrow (the list is cut at
 * WATCH_MAX_TASKS). Each task is {id, ti, d, t, p, r, v}: title, day relative to `e` (-2 two days overdue, 1 tomorrow),
 * minutes after midnight or -1 for all day, priority, 1 when it repeats, and the row's version.
 */
function watchToday(rows, nowMs, tzoSec) {
  var today = Math.floor((nowMs + tzoSec * 1000) / DAY_MS);
  var picked = [];
  rows.forEach(function (row) {
    if (!row || !row.id || isTrue(row.deleted) || Number(row.status) !== 0) return;
    var at = watchMoment(row, tzoSec);
    if (!at) return;
    var d = Math.floor(at.wall / DAY_MS) - today;
    if (d > 1) return;
    picked.push({ row: row, at: at, d: d });
  });
  picked.sort(function (a, b) {
    if (a.at.wall !== b.at.wall) return a.at.wall - b.at.wall;
    return (Number(a.row.sort_order) || 0) - (Number(b.row.sort_order) || 0);
  });
  var n0 = picked.filter(function (x) { return x.d <= 0; }).length;
  return {
    ok: true,
    e: today,
    at: Math.floor(nowMs / 1000),
    n0: n0,
    n1: picked.length,
    tasks: picked.slice(0, WATCH_MAX_TASKS).map(function (x) {
      return {
        id: String(x.row.id),
        ti: watchTitle(x.row.title),
        d: x.d,
        t: x.at.timed ? Math.floor((x.at.wall % DAY_MS) / 60000) : -1,
        p: Number(x.row.priority) || 0,
        r: cellText(x.row.rrule).trim() ? 1 : 0,
        v: Number(x.row.version) || 0,
      };
    }),
  };
}

/** UTC ISO 8601 with Z and no fractional seconds, the Sheet's timestamp format. */
function formatUtc(ms) {
  return new Date(ms).toISOString().replace(/\.\d+Z$/, 'Z');
}

/** The `device` value for a write from the watch: `gmn-` and four hex digits the watch sends. */
function watchDevice(param) {
  var id = String(param || '').toLowerCase();
  return /^[0-9a-f]{4}$/.test(id) ? 'gmn-' + id : 'gmn-0000';
}

/**
 * What completing `row` from the watch writes, given the version the watch saw. {ok: true, changes} with the cells to
 * set, {ok: true, already: true} when this exact completion was already written (a retry), else {ok: false, err}.
 * A repeating task is refused: carrying it on to its next date is the app's job (core/tasks/task_completion.dart).
 */
function planDone(row, seenVersion, nowMs, device) {
  if (!row) return { ok: false, err: 'missing' };
  if (isTrue(row.deleted)) return { ok: false, err: 'deleted' };
  var version = Number(row.version) || 0;
  var status = Number(row.status);
  if (status === 2 && version === seenVersion + 1) return { ok: true, already: true, v: version };
  if (version !== seenVersion) return { ok: false, err: 'changed' };
  if (status !== 0) return { ok: false, err: 'not open' };
  if (cellText(row.rrule).trim()) return { ok: false, err: 'repeats' };
  var now = formatUtc(nowMs);
  return {
    ok: true,
    v: version + 1,
    changes: { status: 2, completed_at: now, updated_at: now, version: version + 1, device: device },
  };
}

/** The rows of a tab as objects keyed by the header row (values[0]). */
function rowsFromValues(values) {
  if (!values || values.length === 0) return [];
  var header = values[0].map(function (h) { return String(h).trim(); });
  return values.slice(1).map(function (cells) {
    var row = {};
    header.forEach(function (name, i) { if (name) row[name] = cells[i]; });
    return row;
  });
}

/** Whether the token the watch sent is the one set up, compared in constant time. */
function tokenOk(given, expected) {
  if (typeof given !== 'string' || typeof expected !== 'string' || expected.length < 16) return false;
  if (given.length !== expected.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) diff |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}

if (typeof module !== 'undefined') {
  module.exports = {
    WATCH_MAX_TASKS, WATCH_TITLE_MAX, cellText, isTrue, parseDateCell, watchMoment, watchTitle, watchToday, formatUtc,
    watchDevice, planDone, rowsFromValues, tokenOk, plainNotes, watchDetail, WATCH_NOTES_MAX, WATCH_CHECKLIST_MAX,
  };
}
