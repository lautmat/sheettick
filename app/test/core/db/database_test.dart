import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/db/fts.dart';

import '../../support/schema_doc.dart';

const _now = '2026-10-19T13:05:00Z';

TasksCompanion _task(
  String id,
  String title, {
  String content = '',
  bool deleted = false,
}) => TasksCompanion.insert(
  id: id,
  createdAt: _now,
  updatedAt: _now,
  title: Value(title),
  content: Value(content),
  deleted: Value(deleted),
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('tables', () {
    test('a task round-trips with schema defaults and empty bookkeeping', () async {
      await db.into(db.tasks).insert(_task('t1', 'Buy milk'));
      final t = await (db.select(db.tasks)..where((r) => r.id.equals('t1'))).getSingle();
      expect(t.title, 'Buy milk');
      expect(t.kind, 'TEXT');
      expect(t.status, 0);
      expect(t.priority, 0);
      expect(t.repeatFrom, 'DUE');
      expect(t.version, 1);
      expect(t.deleted, isFalse);
      expect(t.allDay, isFalse);
      expect(t.listId, isNull);
      expect(t.dirty, isFalse);
      expect(t.sheetRow, isNull);
      expect(t.syncedHash, isNull);
      expect(t.baseSnapshot, isNull);
    });

    test('a list and meta rows round-trip', () async {
      await db.into(db.lists).insert(
        ListsCompanion.insert(
          id: 'l1',
          createdAt: _now,
          updatedAt: _now,
          name: const Value('Inbox'),
          isInbox: const Value(true),
        ),
      );
      await db.into(db.meta).insert(MetaCompanion.insert(key: 'schema_version', value: const Value('1')));
      final l = await db.select(db.lists).getSingle();
      expect(l.isInbox, isTrue);
      expect(l.view, 'list');
      expect(l.kind, 'TASK');
      final m = await db.select(db.meta).getSingle();
      expect((m.key, m.value), ('schema_version', '1'));
    });

    test('primary keys reject duplicate ids', () async {
      await db.into(db.tasks).insert(_task('t1', 'a'));
      expect(() => db.into(db.tasks).insert(_task('t1', 'b')), throwsA(anything));
    });
  });

  group('full-text search', () {
    test('matches title and content by prefix, ignoring case and accents', () async {
      await db.into(db.tasks).insert(_task('t1', 'Call the dentist', content: 'ask about the invoice'));
      await db.into(db.tasks).insert(_task('t2', 'Réunion équipe'));
      await db.into(db.tasks).insert(_task('t3', 'Unrelated'));

      expect((await db.searchTasks('DENT')).map((t) => t.id), ['t1']);
      expect((await db.searchTasks('invoi')).map((t) => t.id), ['t1']);
      expect((await db.searchTasks('reunion equipe')).map((t) => t.id), ['t2']);
      expect(await db.searchTasks('nothing-like-this'), isEmpty);
    });

    test('follows updates and deletes of the task row', () async {
      await db.into(db.tasks).insert(_task('t1', 'alpha'));
      await (db.update(db.tasks)..where((t) => t.id.equals('t1'))).write(
        const TasksCompanion(title: Value('bravo')),
      );
      expect(await db.searchTasks('alpha'), isEmpty);
      expect((await db.searchTasks('bravo')).map((t) => t.id), ['t1']);

      await (db.delete(db.tasks)..where((t) => t.id.equals('t1'))).go();
      expect(await db.searchTasks('bravo'), isEmpty);
    });

    test('excludes tombstoned tasks', () async {
      await db.into(db.tasks).insert(_task('t1', 'visible'));
      await db.into(db.tasks).insert(_task('t2', 'visible too', deleted: true));
      expect((await db.searchTasks('visible')).map((t) => t.id), ['t1']);
    });

    test('user text with FTS operators or quotes never throws', () async {
      await db.into(db.tasks).insert(_task('t1', 'say "hello" world'));
      for (final q in ['"', 'a OR', 'AND', 'x*', '(', 'title:foo', '--', ' ', '']) {
        await db.searchTasks(q);
      }
      expect((await db.searchTasks('"hello"')).map((t) => t.id), ['t1']);
    });

    test('toFtsQuery', () {
      expect(toFtsQuery('foo bar'), '"foo"* "bar"*');
      expect(toFtsQuery('say "hi"'), '"say"* """hi"""*');
      expect(toFtsQuery('  -- ( '), isNull);
      expect(toFtsQuery(''), isNull);
    });
  });

  group('docs/sheet-schema.md is canonical', () {
    // Read in setUpAll, not while the group is registered: a missing file then fails these tests with a clear
    // error instead of aborting the whole test run.
    late SchemaDoc doc;
    setUpAll(() => doc = SchemaDoc());

    List<String> dbColumns(String table) => db.allTables
        .firstWhere((t) => t.actualTableName == table)
        .$columns
        .map((c) => c.name)
        .toList();

    const localOnly = {'dirty', 'sheet_row', 'synced_hash', 'base_snapshot'};

    for (final table in ['tasks', 'lists']) {
      test('$table columns match the doc, plus sync columns and local bookkeeping', () {
        final fromDoc = {...doc.tabColumns(table), ...doc.syncColumns};
        final fromDb = dbColumns(table).toSet();
        expect(fromDb.difference(localOnly), fromDoc);
        expect(fromDb.intersection(localOnly), localOnly);
      });
    }

    test('meta columns match the doc', () {
      expect(dbColumns('meta').toSet(), doc.tabColumns('meta').toSet());
    });
  });
}
