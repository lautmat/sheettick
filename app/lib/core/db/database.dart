import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'fts.dart';
import 'tables.dart';

part 'database.g.dart';

/// Local SQLite database. The UI reads and writes only this; the sync engine reconciles it with the Sheet.
///
/// Note: [schemaVersion] is the local SQLite migration version and is unrelated to the Sheet's
/// `meta.schema_version` (see `docs/sheet-schema.md`).
@DriftDatabase(tables: [Tasks, Lists, Meta, DeviceState])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The on-device database file.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'sheettick'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in ftsStatements) {
        await customStatement(sql);
      }
    },
    // The FTS table and its triggers are created by hand in onCreate, so drift's generated migrations do not
    // know about them. Fail loudly rather than let an upgraded install silently lack them: whoever raises
    // schemaVersion must write the step, and re-run the relevant [ftsStatements] if they did not exist yet.
    onUpgrade: (m, from, to) async => throw UnsupportedError(
      'No migration from schema $from to $to. Write one in AppDatabase.migration.',
    ),
  );

  /// Live tasks (not tombstoned) whose title or content matches [text], best match first.
  Future<List<Task>> searchTasks(String text, {int limit = 50}) async {
    final query = toFtsQuery(text);
    if (query == null) return const [];
    final rows = await customSelect(
      'SELECT t.* FROM tasks_fts JOIN tasks t ON t.id = tasks_fts.id '
      'WHERE tasks_fts MATCH ?1 AND t.deleted = 0 '
      'ORDER BY tasks_fts.rank LIMIT ?2',
      variables: [Variable.withString(query), Variable.withInt(limit)],
      readsFrom: {tasks},
    ).get();
    return rows.map((r) => tasks.map(r.data)).toList();
  }
}
