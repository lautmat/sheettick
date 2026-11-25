// The watch endpoint: a web app that the SheetTick Connect IQ app on a Garmin watch calls through the phone
// (garmin/README.md). Deployed with clasp (see README.md). Every reply is JSON with `ok`; Apps Script cannot set an
// HTTP status, so errors are {ok: false, err}.
//
//   ?k=<token>&a=today&tzo=<watch UTC offset in seconds>        today's tasks (see watchToday in Today.js)
//   ?k=<token>&a=done&id=<task id>&ver=<version seen>&dev=<4 hex> complete a task (see planDone in Today.js)
//   ?k=<token>&a=task&id=<task id>                                one task's notes and checklist (watchDetail)
//
// The token lives in WatchSecret.js, which is git-ignored and pushed by clasp (tools/watch_secrets.mjs writes it).
// Both actions are GET: Apps Script answers through a redirect, and a GET is what every client follows. `done` is
// safe to repeat: a retry of a completion that went through answers ok.

var TASKS_TAB = 'tasks';

function doGet(e) {
  var p = (e && e.parameter) || {};
  var expected = typeof WATCH_TOKEN === 'undefined' ? '' : WATCH_TOKEN;
  if (!tokenOk(p.k, expected)) return json_({ ok: false, err: 'auth' });
  try {
    if (p.a === 'done') return json_(completeFromWatch_(p));
    if (p.a === 'task') return json_(taskForWatch_(p));
    return json_(watchToday(readTasks_().rows, Date.now(), Number(p.tzo) || 0));
  } catch (err) {
    console.error(err && err.stack ? err.stack : err);
    return json_({ ok: false, err: 'server' });
  }
}

function completeFromWatch_(p) {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) return { ok: false, err: 'busy' };
  try {
    var tasks = readTasks_();
    var index = -1;
    for (var i = 0; i < tasks.rows.length; i++) {
      if (String(tasks.rows[i].id) === String(p.id)) { index = i; break; }
    }
    var plan = planDone(index < 0 ? null : tasks.rows[index], Number(p.ver), Date.now(), watchDevice(p.dev));
    if (!plan.ok || !plan.changes) return plan.ok ? { ok: true, v: plan.v } : plan;

    var columns = {};
    Object.keys(plan.changes).forEach(function (name) {
      var col = tasks.header.indexOf(name);
      if (col < 0) throw new Error('No column ' + name + ' in ' + TASKS_TAB);
      columns[name] = col + 1;
    });
    var sheetRow = index + 2; // row 1 is the header
    Object.keys(plan.changes).forEach(function (name) {
      var value = plan.changes[name];
      var cell = tasks.sheet.getRange(sheetRow, columns[name]);
      // Text stays text, as the app keeps it (a timestamp must not turn into a date serial).
      if (typeof value === 'string') cell.setNumberFormat('@');
      cell.setValue(value);
    });
    SpreadsheetApp.flush();
    console.log('Watch completed task ' + p.id + ' (version ' + plan.v + ')');
    return { ok: true, v: plan.v };
  } finally {
    lock.releaseLock();
  }
}

function taskForWatch_(p) {
  var find = function (rows, id) {
    for (var i = 0; i < rows.length; i++) if (String(rows[i].id) === String(id)) return rows[i];
    return null;
  };
  var task = find(readTasks_().rows, p.id);
  if (!task) return watchDetail(null, null, []);
  return watchDetail(task, find(readTab_('lists', true).rows, task.list_id), readTab_('checklist', true).rows);
}

function readTasks_() {
  return readTab_(TASKS_TAB, false);
}

/** A tab's rows keyed by header. A missing tab throws, or reads as empty when `optional`. */
function readTab_(name, optional) {
  var sheet = SpreadsheetApp.getActive().getSheetByName(name);
  if (!sheet) {
    if (optional) return { sheet: null, header: [], rows: [] };
    throw new Error('No ' + name + ' tab');
  }
  var values = sheet.getDataRange().getValues();
  return {
    sheet: sheet,
    header: (values[0] || []).map(function (h) { return String(h).trim(); }),
    rows: rowsFromValues(values),
  };
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
