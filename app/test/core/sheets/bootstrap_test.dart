import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sheets/bootstrap.dart';
import 'package:sheettick/core/sheets/sheet_schema.dart';
import 'package:sheettick/core/sheets/sheets_backend.dart';

import '../../support/fake_sheets_backend.dart';

/// A second device that does not yet see the first device's file (list results are stale once).
class _StaleFirstList extends FakeSheetsBackend {
  bool _served = false;
  @override
  Future<List<SpreadsheetFile>> findSpreadsheets() async {
    if (!_served) {
      _served = true;
      return const [];
    }
    return super.findSpreadsheets();
  }
}

/// Fails the first value write, as if the app was killed or offline halfway through bootstrap.
class _FailsOnce extends FakeSheetsBackend {
  bool armed = true;
  @override
  Future<void> writeRanges(String id, Map<String, List<List<Object?>>> data, {bool userEntered = false}) {
    if (armed) {
      armed = false;
      throw StateError('connection lost');
    }
    return super.writeRanges(id, data, userEntered: userEntered);
  }
}

void main() {
  // Every simulated device gets its own in-memory database; drift's "multiple databases" warning is about
  // sharing one executor, which does not happen here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final dbs = <AppDatabase>[];
  AppDatabase newDevice() {
    final db = AppDatabase(NativeDatabase.memory());
    dbs.add(db);
    return db;
  }

  tearDown(() async {
    for (final db in dbs) {
      await db.close();
    }
    dbs.clear();
  });

  var uuidCounter = 0;
  SheetBootstrap bootstrap(SheetsBackend backend, AppDatabase db, {String device = 'win-0001'}) => SheetBootstrap(
    backend: backend,
    db: db,
    deviceId: device,
    appVersion: '0.1.0',
    clock: () => DateTime.utc(2026, 10, 19, 13, 5),
    newId: () => 'uuid-${++uuidCounter}',
  );

  List<Object?> row(FakeSheetsBackend b, String id, String tab, int n) => b.rawRows(id, tab)[n - 1];

  group('fresh account', () {
    late FakeSheetsBackend backend;
    late BootstrapResult result;

    setUp(() async {
      backend = FakeSheetsBackend();
      result = await bootstrap(backend, newDevice()).run();
    });

    test('creates one tagged spreadsheet named SheetTick and remembers its id', () async {
      expect(result.created, isTrue);
      final files = await backend.findSpreadsheets();
      expect(files.map((f) => f.id), [result.spreadsheetId]);
      expect(files.single.name, 'SheetTick');
      expect(backend.calls['createSpreadsheet'], 1);
    });

    test('has every tab of the schema plus View, and drops the default tab', () {
      expect(backend.tabTitles(result.spreadsheetId), [...kTabs.map((t) => t.name), kViewTabName]);
    });

    test('writes the exact header row of every tab', () {
      for (final tab in kTabs) {
        expect(row(backend, result.spreadsheetId, tab.name, 1), tab.columnNames, reason: tab.name);
      }
    });

    test('writes the View formula', () {
      expect(row(backend, result.spreadsheetId, kViewTabName, 1), [viewFormula()]);
    });

    test('writes meta.schema_version = 1 and the other meta keys', () {
      final rows = backend.rawRows(result.spreadsheetId, 'meta');
      expect(rows, [
        ['key', 'value'],
        ['schema_version', '1'],
        ['compaction_epoch', '0'],
        ['created_by_app_version', '0.1.0'],
        ['settings_json', '{}'],
      ]);
    });

    test('creates the Inbox list, written by this device', () {
      final header = tabSpec('lists').columnNames;
      final inbox = row(backend, result.spreadsheetId, 'lists', 2);
      Object? cell(String name) => inbox[header.indexOf(name)];
      expect(result.inboxListId, cell('id'));
      expect(cell('name'), 'Inbox');
      expect(cell('is_inbox'), true);
      expect(cell('deleted'), false);
      expect(cell('version'), 1);
      expect(cell('device'), 'win-0001');
      expect(cell('created_at'), '2026-10-19T13:05:00Z');
      expect(cell('updated_at'), '2026-10-19T13:05:00Z');
      expect(backend.rawRows(result.spreadsheetId, 'lists'), hasLength(2));
    });

    test('uses a handful of batched requests, not one per tab', () {
      expect(backend.calls['changeTabs'], 1);
      expect(backend.calls['writeRanges'], 2); // headers + View formula
      expect(backend.calls['readRanges'], 1);
      expect(backend.calls['appendRows'], 2); // meta + inbox
    });
  });

  test('a second device finds the same spreadsheet and the same Inbox, and adds nothing', () async {
    final backend = FakeSheetsBackend();
    final first = await bootstrap(backend, newDevice()).run();
    final before = {for (final t in kTabs) t.name: backend.rawRows(first.spreadsheetId, t.name)};

    final second = await bootstrap(backend, newDevice(), device: 'and-0002').run();

    expect(second.created, isFalse);
    expect(second.spreadsheetId, first.spreadsheetId);
    expect(second.inboxListId, first.inboxListId);
    expect((await backend.findSpreadsheets()), hasLength(1));
    for (final t in kTabs) {
      expect(backend.rawRows(first.spreadsheetId, t.name), before[t.name], reason: t.name);
    }
  });

  test('running again on the same device is a no-op', () async {
    final backend = FakeSheetsBackend();
    final db = newDevice();
    final first = await bootstrap(backend, db).run();
    final lists = backend.rawRows(first.spreadsheetId, 'lists');
    final createCalls = backend.calls['createSpreadsheet'];

    final again = await bootstrap(backend, db).run();

    expect(again.spreadsheetId, first.spreadsheetId);
    expect(again.inboxListId, first.inboxListId);
    expect(backend.calls['createSpreadsheet'], createCalls);
    expect(backend.rawRows(first.spreadsheetId, 'lists'), lists);
    expect(backend.rawRows(first.spreadsheetId, 'meta'), hasLength(5));
  });

  test('a spreadsheet named SheetTick that the app did not create is ignored', () async {
    final backend = FakeSheetsBackend();
    final foreign = backend.addForeignSpreadsheet('SheetTick');

    final result = await bootstrap(backend, newDevice()).run();

    expect(result.created, isTrue);
    expect(result.spreadsheetId, isNot(foreign));
  });

  test('two devices signing in at the same moment end up on one file; the loser trashes its own', () async {
    final backend = _StaleFirstList();
    final fileA = await backend.createSpreadsheet('SheetTick'); // device A got there first

    final b = await bootstrap(backend, newDevice(), device: 'and-0002').run();

    expect(b.spreadsheetId, fileA.id);
    expect(b.created, isFalse);
    expect(backend.calls['trashFile'], 1);
    expect((await backend.findSpreadsheets()).map((f) => f.id), [fileA.id]);
    expect(backend.rawRows(fileA.id, 'lists'), hasLength(2));
  });

  test('a crash halfway is resumed without duplicating rows', () async {
    final backend = _FailsOnce();
    final db = newDevice();

    await expectLater(bootstrap(backend, db).run(), throwsStateError);
    final result = await bootstrap(backend, db).run();

    expect(await backend.findSpreadsheets(), hasLength(1));
    expect(backend.tabTitles(result.spreadsheetId), [...kTabs.map((t) => t.name), kViewTabName]);
    for (final tab in kTabs) {
      expect(row(backend, result.spreadsheetId, tab.name, 1), tab.columnNames, reason: tab.name);
    }
    expect(row(backend, result.spreadsheetId, kViewTabName, 1), [viewFormula()]);
    expect(backend.rawRows(result.spreadsheetId, 'meta'), hasLength(5));
    expect(backend.rawRows(result.spreadsheetId, 'lists'), hasLength(2));
  });

  test('the fake refuses setCell on a tab without a header, with a message that says so', () async {
    final backend = FakeSheetsBackend();
    final file = await backend.createSpreadsheet('SheetTick');
    await backend.changeTabs(file.id, add: const [TabSpec('empty', [], hasSyncColumns: false)]);
    expect(
      () => backend.setCell(file.id, 'empty', 1, 'title', 'x'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('has no rows'))),
    );
  });

  test('a user-added tab is kept once the spreadsheet is structured', () async {
    final backend = FakeSheetsBackend();
    final first = await bootstrap(backend, newDevice()).run();
    await backend.changeTabs(first.spreadsheetId, add: const [TabSpec('Notes', [], hasSyncColumns: false)]);

    await bootstrap(backend, newDevice(), device: 'and-0002').run();

    expect(backend.tabTitles(first.spreadsheetId), contains('Notes'));
  });

  group('refusals', () {
    test('a sheet with a newer schema_version is refused', () async {
      final backend = FakeSheetsBackend();
      final first = await bootstrap(backend, newDevice()).run();
      backend.setCell(first.spreadsheetId, 'meta', 2, 'value', '2');

      await expectLater(
        bootstrap(backend, newDevice(), device: 'and-0002').run(),
        throwsA(isA<SchemaTooNewException>().having((e) => e.found, 'found', 2)),
      );
    });

    test('a numeric schema_version typed by hand is understood too', () async {
      final backend = FakeSheetsBackend();
      final first = await bootstrap(backend, newDevice()).run();
      backend.setCell(first.spreadsheetId, 'meta', 2, 'value', 1);

      await bootstrap(backend, newDevice(), device: 'and-0002').run();
    });

    test('a header row missing a required column is refused, not silently patched', () async {
      final backend = FakeSheetsBackend();
      final first = await bootstrap(backend, newDevice()).run();
      backend.setCell(first.spreadsheetId, 'tasks', 1, 'title', 'headline');

      await expectLater(
        bootstrap(backend, newDevice(), device: 'and-0002').run(),
        throwsA(
          isA<SchemaMismatchException>()
              .having((e) => e.tab, 'tab', 'tasks')
              .having((e) => e.missingColumns, 'missing', ['title']),
        ),
      );
    });

    test('a spreadsheet that was deleted is reported, never silently replaced', () async {
      final backend = FakeSheetsBackend();
      final db = newDevice();
      final first = await bootstrap(backend, db).run();
      await backend.trashFile(first.spreadsheetId);

      await expectLater(bootstrap(backend, db).run(), throwsA(isA<SpreadsheetMissingException>()));
      expect(backend.calls['createSpreadsheet'], 1);
    });
  });

  test('an existing Inbox is found by header name even when columns were reordered by hand', () async {
    final backend = FakeSheetsBackend();
    final first = await bootstrap(backend, newDevice()).run();
    // Swap the `name` and `is_inbox` columns (header cell and value) by position.
    final header = tabSpec('lists').columnNames;
    final nameCol = header.indexOf('name');
    final inboxCol = header.indexOf('is_inbox');
    void swap(int r) {
      final cells = backend.rawRows(first.spreadsheetId, 'lists')[r - 1];
      final a = cells[nameCol], b = cells[inboxCol];
      backend.setCellAt(first.spreadsheetId, 'lists', r, nameCol, b);
      backend.setCellAt(first.spreadsheetId, 'lists', r, inboxCol, a);
    }

    swap(1);
    swap(2);
    expect(row(backend, first.spreadsheetId, 'lists', 1)[nameCol], 'is_inbox');

    final second = await bootstrap(backend, newDevice(), device: 'and-0002').run();

    expect(second.inboxListId, first.inboxListId);
    expect(backend.rawRows(first.spreadsheetId, 'lists'), hasLength(2));
  });
}
