import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/sheets/bootstrap.dart';
import 'package:sheettick/core/sheets/sheet_schema.dart';
import 'package:sheettick/core/sheets/sheets_backend.dart';

import '../../support/fake_sheets_backend.dart';
import '../../support/hooked_backend.dart';
import '../../support/test_device.dart';

/// Fails every write, as if offline.
class _Offline extends FakeSheetsBackend {
  bool offline = false;
  @override
  Future<void> writeRanges(String id, Map<String, List<List<Object?>>> data, {bool userEntered = false}) {
    if (offline) throw StateError('offline');
    return super.writeRanges(id, data, userEntered: userEntered);
  }

  @override
  Future<AppendResult> appendRows(String id, String tab, List<List<Object?>> rows) {
    if (offline) throw StateError('offline');
    return super.appendRows(id, tab, rows);
  }
}

/// The 1-based row of the task [id] in the Sheet's tasks tab, or null.
int? sheetRowOf(FakeSheetsBackend b, String spreadsheetId, String tab, String id) {
  final rows = b.rawRows(spreadsheetId, tab);
  final idCol = tabSpec(tab).columnNames.indexOf('id');
  for (var i = 1; i < rows.length; i++) {
    if (rows[i].length > idCol && rows[i][idCol] == id) return i + 1;
  }
  return null;
}

/// Cell of a Sheet row by column name.
Object? cell(FakeSheetsBackend b, String spreadsheetId, String tab, int row, String column) {
  final r = b.rawRows(spreadsheetId, tab)[row - 1];
  final col = tabSpec(tab).columnNames.indexOf(column);
  return col < r.length ? r[col] : null;
}

void main() {
  late FakeSheetsBackend backend;
  late TestDevice a; // Windows
  late TestDevice b; // Android
  final devices = <TestDevice>[];

  Future<TestDevice> device(FakeSheetsBackend be, String id, {DateTime? start}) async {
    final d = await TestDevice.create(be, id: id, start: start);
    devices.add(d);
    return d;
  }

  setUp(() async {
    backend = FakeSheetsBackend();
    a = await device(backend, 'win-0001');
    b = await device(backend, 'and-0002');
  });

  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
  });

  group('round trip', () {
    test('a task created on one device reaches the other through the Sheet', () async {
      final id = await a.addTask('Buy milk', extra: {'priority': 3, 'tags': 'home,shop'});
      final pushed = await a.sync();
      expect(pushed.pushedAppends, 1); // the task; the Inbox list was already written by the bootstrap
      await b.sync();

      final t = await b.task(id);
      expect(t.fields['title'], 'Buy milk');
      expect(t.fields['priority'], 3);
      expect(t.fields['tags'], 'home,shop');
      expect(t.fields['list_id'], a.inboxId);
      expect(t.dirty, isFalse);
      expect(t.sheetRow, sheetRowOf(backend, a.spreadsheetId, 'tasks', id));
      expect((await b.list(a.inboxId))!.fields['is_inbox'], true);
    });

    test('an edit made on the other device comes back, and tombstones propagate', () async {
      final id = await a.addTask('Draft report');
      await a.sync();
      await b.sync();

      b.tick();
      await b.edit(id, {'status': 2, 'completed_at': '2026-10-19T10:00:00Z'});
      await b.sync();
      await a.sync();
      expect((await a.task(id)).fields['status'], 2);
      expect((await a.task(id)).fields['completed_at'], '2026-10-19T10:00:00Z');

      a.tick();
      await a.writer.delete('tasks', id);
      await a.sync();
      await b.sync();
      expect((await b.task(id)).fields['deleted'], true);
      // The row is still in the Sheet: rows are never removed.
      expect(sheetRowOf(backend, a.spreadsheetId, 'tasks', id), isNotNull);
    });

    test('every write bumps version, sets updated_at and device', () async {
      final id = await a.addTask('x');
      var t = await a.task(id);
      expect((t.fields['version'], t.fields['device'], t.fields['updated_at']), (1, 'win-0001', '2026-10-19T09:00:00Z'));
      a.tick(5);
      await a.edit(id, {'title': 'y'});
      t = await a.task(id);
      expect((t.fields['version'], t.fields['updated_at'], t.dirty), (2, '2026-10-19T09:05:00Z', true));
    });
  });

  group('required: conflicts', () {
    test('1. different fields edited offline on two devices: both changes survive', () async {
      final id = await a.addTask('Buy milk');
      await a.sync();
      await b.sync();

      // Both go offline and edit different fields of the same task.
      a.tick(10);
      await a.edit(id, {'title': 'Buy oat milk'});
      b.tick(20);
      await b.edit(id, {'priority': 5, 'content': 'the blue carton'});

      await a.sync(); // a reaches the Sheet first
      final merged = await b.sync(); // b meets a's change while holding its own
      expect(merged.merged, 1);
      await a.sync();

      for (final d in [a, b]) {
        final t = await d.task(id);
        expect(t.fields['title'], 'Buy oat milk', reason: d.id);
        expect(t.fields['priority'], 5, reason: d.id);
        expect(t.fields['content'], 'the blue carton', reason: d.id);
        expect(t.dirty, isFalse, reason: d.id);
      }
      final row = sheetRowOf(backend, a.spreadsheetId, 'tasks', id)!;
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'title'), 'Buy oat milk');
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'priority'), 5);
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'content'), 'the blue carton');
      // The merge is a new write: version = max(local, remote) + 1.
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'version'), 3);
    });

    test('2. the same field edited on both: the newer updated_at wins, whoever syncs first', () async {
      for (final newerSyncsFirst in [true, false]) {
        final id = await a.addTask('Call dentist ($newerSyncsFirst)');
        await a.sync();
        await b.sync();

        a.tick(10);
        await a.edit(id, {'title': 'from A (older)'});
        b.tick(30);
        await b.edit(id, {'title': 'from B (newer)'});

        if (newerSyncsFirst) {
          await b.sync();
          await a.sync();
        } else {
          await a.sync();
          await b.sync();
        }
        await a.sync();
        await b.sync();

        for (final d in [a, b]) {
          expect((await d.task(id)).fields['title'], 'from B (newer)', reason: '${d.id} newerSyncsFirst=$newerSyncsFirst');
        }
        final row = sheetRowOf(backend, a.spreadsheetId, 'tasks', id)!;
        expect(cell(backend, a.spreadsheetId, 'tasks', row, 'title'), 'from B (newer)');
      }
    });

    test('2b. identical timestamps still converge, on the same value everywhere', () async {
      final id = await a.addTask('base');
      await a.sync();
      await b.sync();

      a.now = b.now = DateTime.utc(2026, 10, 19, 12);
      await a.edit(id, {'title': 'A'});
      await b.edit(id, {'title': 'B'});
      await a.sync();
      await b.sync();
      await a.sync();

      final fromA = (await a.task(id)).fields['title'];
      final fromB = (await b.task(id)).fields['title'];
      expect(fromA, fromB);
      expect(fromA, 'A'); // ties go to the larger device id: "win-0001" > "and-0002"
    });

    test('3. a hand edit in the Sheet is detected and pulled, then propagated to the other device', () async {
      final id = await a.addTask('Water plants');
      await a.sync();
      await b.sync();
      final row = sheetRowOf(backend, a.spreadsheetId, 'tasks', id)!;

      // A human types into the cell; version, updated_at and device are untouched.
      backend.setCell(a.spreadsheetId, 'tasks', row, 'title', 'Water the plants (hand edit)');
      backend.setCell(a.spreadsheetId, 'tasks', row, 'due_at', '2026-10-25');

      a.tick(5);
      final r = await a.sync();
      expect(r.updated, 1);
      var t = await a.task(id);
      expect(t.fields['title'], 'Water the plants (hand edit)');
      expect(t.fields['due_at'], '2026-10-25');
      // Treated as version + 1 and written back, so the other devices see a newer row.
      expect(t.fields['version'], 2);
      expect(t.dirty, isFalse);
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'version'), 2);
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'device'), 'win-0001');

      await b.sync();
      t = await b.task(id);
      expect(t.fields['title'], 'Water the plants (hand edit)');
      expect(t.fields['version'], 2);
    });

    test('3b. a hand edit made while the task is also dirty locally is merged, not lost', () async {
      final id = await a.addTask('Plan trip');
      await a.sync();
      final row = sheetRowOf(backend, a.spreadsheetId, 'tasks', id)!;

      backend.setCell(a.spreadsheetId, 'tasks', row, 'content', 'book the train'); // by hand
      a.tick();
      await a.edit(id, {'priority': 5}); // locally, offline
      await a.sync();

      final t = await a.task(id);
      expect(t.fields['content'], 'book the train');
      expect(t.fields['priority'], 5);
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'content'), 'book the train');
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'priority'), 5);
    });

    test('4. row numbers shift (rows inserted above): re-index, and no write goes to a wrong row', () async {
      final t1 = await a.addTask('one');
      final t2 = await a.addTask('two');
      final t3 = await a.addTask('three');
      await a.sync();
      expect([for (final t in [t1, t2, t3]) sheetRowOf(backend, a.spreadsheetId, 'tasks', t)], [2, 3, 4]);

      // A compaction/sort moves everything down by two rows.
      backend.insertRows(a.spreadsheetId, 'tasks', 2, 2);
      expect([for (final t in [t1, t2, t3]) sheetRowOf(backend, a.spreadsheetId, 'tasks', t)], [4, 5, 6]);
      final before = backend.rawRows(a.spreadsheetId, 'tasks');

      a.tick();
      await a.edit(t2, {'title': 'two (edited)'});
      await a.sync();

      expect(sheetRowOf(backend, a.spreadsheetId, 'tasks', t2), 5);
      expect(cell(backend, a.spreadsheetId, 'tasks', 5, 'title'), 'two (edited)');
      expect(cell(backend, a.spreadsheetId, 'tasks', 4, 'title'), 'one');
      expect(cell(backend, a.spreadsheetId, 'tasks', 6, 'title'), 'three');
      // The old row positions (now blank) were never written.
      final after = backend.rawRows(a.spreadsheetId, 'tasks');
      expect(after[1], before[1]);
      expect(after[2], before[2]);
      expect((await a.task(t2)).sheetRow, 5);
      expect((await a.task(t1)).sheetRow, 4);
      expect((await a.task(t3)).sheetRow, 6);
    });

    test('4b. rows shift between the pull and the push of one cycle: the id check catches it', () async {
      final hooked = HookedBackend(backend);
      final c = await TestDevice.create(backend, id: 'win-0003', engineBackend: hooked);
      devices.add(c);
      final t1 = await c.addTask('one');
      final t2 = await c.addTask('two');
      await c.sync();
      expect(sheetRowOf(backend, c.spreadsheetId, 'tasks', t2), 3);

      c.tick();
      await c.edit(t2, {'title': 'two (edited)'});
      // Two rows are inserted above right after this cycle's pull has read the Sheet.
      hooked.afterNextRead = () => backend.insertRows(c.spreadsheetId, 'tasks', 2, 2);
      await c.sync();

      // The edit landed on the row that now holds task two, not on whatever sits at the old row number.
      expect(sheetRowOf(backend, c.spreadsheetId, 'tasks', t2), 5);
      expect(cell(backend, c.spreadsheetId, 'tasks', 5, 'title'), 'two (edited)');
      expect(cell(backend, c.spreadsheetId, 'tasks', 4, 'title'), 'one');
      expect(sheetRowOf(backend, c.spreadsheetId, 'tasks', t1), 4);
      expect(backend.rawRows(c.spreadsheetId, 'tasks')[2], isEmpty); // the old row 3 is still blank
    });
    test('4c. a changed compaction epoch drops the cached row numbers and re-indexes', () async {
      final t1 = await a.addTask('one');
      final t2 = await a.addTask('two');
      await a.sync();

      // Compaction removes the first row (say, an archived task) and bumps the epoch.
      backend.deleteRow(a.spreadsheetId, 'tasks', 2);
      backend.setCell(a.spreadsheetId, 'meta', 3, 'value', '1'); // compaction_epoch
      await a.sync();
      expect((await a.task(t2)).sheetRow, 2);
      expect((await a.task(t1)).sheetRow, isNull); // gone from the Sheet; kept locally

      a.tick();
      await a.edit(t2, {'title': 'two (edited)'});
      await a.sync();
      expect(cell(backend, a.spreadsheetId, 'tasks', 2, 'title'), 'two (edited)');
    });
  });

  group('cycle behaviour', () {
    test('an idle cycle only checks Drive', () async {
      await a.addTask('x');
      await a.sync();
      await a.sync(); // sees its own write once
      final reads = backend.calls['readRanges'];
      final writes = backend.calls['writeRanges'];
      final r = await a.sync();
      expect(r.skipped, isTrue);
      expect(backend.calls['readRanges'], reads);
      expect(backend.calls['writeRanges'], writes);
    });

    test('a cycle is batched: one read, one in-place write, one append per tab', () async {
      final ids = [for (var i = 0; i < 5; i++) await a.addTask('t$i')];
      await a.sync();
      await b.sync();
      backend.calls.clear();

      for (final id in ids.take(3)) {
        b.tick();
        await b.edit(id, {'priority': 1});
      }
      await b.addTask('new one');
      await b.addTask('new two');
      await b.sync();

      expect(backend.calls['getFile'], 1);
      expect(backend.calls['readRanges'], 2); // the pull, and the id check before writing in place
      expect(backend.calls['writeRanges'], 1);
      expect(backend.calls['appendRows'], 1);
    });

    test('values are written raw: text that looks like a formula or a date stays text', () async {
      final id = await a.addTask('=HYPERLINK("http://x")', extra: {'content': '2026-10-20', 'tags': '1/2'});
      await a.sync();
      final row = sheetRowOf(backend, a.spreadsheetId, 'tasks', id)!;
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'title'), '=HYPERLINK("http://x")');
      await b.sync();
      final t = await b.task(id);
      expect(t.fields['title'], '=HYPERLINK("http://x")');
      expect(t.fields['content'], '2026-10-20');
      expect(t.fields['tags'], '1/2');
    });

    test('a failed push keeps the rows dirty and the next cycle completes it', () async {
      final be = _Offline();
      final c = await device(be, 'win-0004');
      final id = await c.addTask('offline task');
      be.offline = true;
      await expectLater(c.sync(), throwsStateError);
      expect((await c.task(id)).dirty, isTrue);

      be.offline = false;
      await c.sync();
      expect((await c.task(id)).dirty, isFalse);
      expect(sheetRowOf(be, c.spreadsheetId, 'tasks', id), isNotNull);
    });

    test('an edit made while a push is in flight is not marked as pushed', () async {
      final id = await a.addTask('first');
      final cycle = a.sync();
      // The UI edits the row while the cycle is awaiting the Sheet.
      a.tick();
      await a.edit(id, {'title': 'second'});
      await cycle;
      final t = await a.task(id);
      expect(t.fields['title'], 'second');
      // Whatever the interleaving, the next cycle ends with the Sheet and the device in agreement.
      await a.sync();
      final row = sheetRowOf(backend, a.spreadsheetId, 'tasks', id)!;
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'title'), 'second');
      expect((await a.task(id)).dirty, isFalse);
    });

    test('concurrent sync() calls share one cycle', () async {
      await a.addTask('x');
      final r1 = a.sync();
      final r2 = a.sync();
      expect(identical(r1, r2), isTrue);
      await r1;
    });

    test('rows typed by hand: blank rows and rows without an id are ignored, missing sync columns are filled in', () async {
      await a.sync();
      final tasks = tabSpec('tasks').columnNames;
      final width = tasks.length;
      List<Object?> blank() => List.filled(width, null);
      final hand = blank()
        ..[tasks.indexOf('id')] = 'hand-1'
        ..[tasks.indexOf('title')] = 'typed in the sheet';
      final noId = blank()..[tasks.indexOf('title')] = 'no id here';
      backend.insertRows(a.spreadsheetId, 'tasks', 2, 1); // a blank row at the top
      await backend.appendRows(a.spreadsheetId, 'tasks', [noId, hand]);

      a.tick();
      await a.sync();

      expect(await a.store.getRow('tasks', 'hand-1'), isNotNull);
      final t = await a.task('hand-1');
      expect(t.fields['title'], 'typed in the sheet');
      expect(t.fields['version'], 1);
      expect(t.fields['created_at'], isNotNull);
      expect(t.fields['status'], 0); // defaults
      expect(t.dirty, isFalse); // the repaired sync columns were written back
      final row = sheetRowOf(backend, a.spreadsheetId, 'tasks', 'hand-1')!;
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'version'), 1);
      expect(cell(backend, a.spreadsheetId, 'tasks', row, 'created_at'), isNotNull);
      expect((await a.store.rowsById('tasks')).length, 1); // the row without an id is not a task
    });

    test('a duplicated id in the Sheet: the first row wins and nothing crashes', () async {
      final id = await a.addTask('original');
      await a.sync();
      final row = sheetRowOf(backend, a.spreadsheetId, 'tasks', id)!;
      final copy = List<Object?>.of(backend.rawRows(a.spreadsheetId, 'tasks')[row - 1]);
      copy[tabSpec('tasks').columnNames.indexOf('title')] = 'copy-pasted';
      await backend.appendRows(a.spreadsheetId, 'tasks', [copy]);

      await b.sync();
      expect((await b.task(id)).fields['title'], 'original');
    });

    test('a row deleted by hand stays on the device and is appended again when edited', () async {
      final id = await a.addTask('precious');
      await a.sync();
      backend.deleteRow(a.spreadsheetId, 'tasks', sheetRowOf(backend, a.spreadsheetId, 'tasks', id)!);

      await a.sync();
      var t = await a.task(id);
      expect(t.sheetRow, isNull);
      expect(t.fields['title'], 'precious');

      a.tick();
      await a.edit(id, {'title': 'precious (edited)'});
      await a.sync();
      expect(sheetRowOf(backend, a.spreadsheetId, 'tasks', id), isNotNull);
      t = await a.task(id);
      expect(t.dirty, isFalse);
    });

    test('a deleted spreadsheet is reported, rows stay dirty', () async {
      final id = await a.addTask('x');
      await backend.trashFile(a.spreadsheetId);
      await expectLater(a.sync(), throwsA(isA<SpreadsheetMissingException>()));
      expect((await a.task(id)).dirty, isTrue);
    });
  });
}
