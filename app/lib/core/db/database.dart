import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'fts.dart';
import 'tables.dart';

part 'database.g.dart';

/// Keys of the `device_state` table.
abstract final class DeviceStateKeys {
  static const deviceId = 'device_id';
  static const spreadsheetId = 'spreadsheet_id';
  static const lastDriveModifiedTime = 'last_drive_modified_time';
  static const lastCompactionEpoch = 'last_compaction_epoch';

  /// When this device last checked which reminders were due (Windows shows reminders while the app runs).
  static const lastReminderLook = 'last_reminder_look';

  /// Reminders moved to a later time on this device (JSON; see `core/reminders/snooze.dart`). Not synced.
  static const reminderSnoozes = 'reminder_snoozes';
}

/// Local SQLite database. The UI reads and writes only this; the sync engine reconciles it with the Sheet.
///
/// Note: [schemaVersion] is the local SQLite migration version and is unrelated to the Sheet's
/// `meta.schema_version` (see `docs/sheet-schema.md`).
@DriftDatabase(tables: [Tasks, Lists, Folders, Sections, Checklist, Tags, Meta, DeviceState])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The on-device database file.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'sheettick'));

  @override
  int get schemaVersion => 2;

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
    onUpgrade: (m, from, to) async {
      if (from == 1 && to == 2) {
        await m.createTable(folders);
        await m.createTable(sections);
        await m.createTable(checklist);
        await m.createTable(tags);
        // The next sync skips the Sheet while its modified time is unchanged. Forget it, so the first sync after
        // the upgrade pulls the four new tabs even if nobody has edited the Sheet since.
        await customStatement('DELETE FROM device_state WHERE key = ?', [DeviceStateKeys.lastDriveModifiedTime]);
        return;
      }
      throw UnsupportedError('No migration from schema $from to $to. Write one in AppDatabase.migration.');
    },
  );

  Future<String?> getDeviceState(String key) async {
    final row = await (select(deviceState)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setDeviceState(String key, String value) =>
      into(deviceState).insertOnConflictUpdate(DeviceStateCompanion.insert(key: key, value: value));

  /// This install's short ID (`win-1a2b`, `and-9f3c`), written in the `device` column of every row it
  /// writes. Generated once and kept.
  Future<String> ensureDeviceId(String prefix, {Random? random}) async {
    final existing = await getDeviceState(DeviceStateKeys.deviceId);
    if (existing != null) return existing;
    final rng = random ?? Random.secure();
    final id = '$prefix-${rng.nextInt(0x10000).toRadixString(16).padLeft(4, '0')}';
    await setDeviceState(DeviceStateKeys.deviceId, id);
    return id;
  }

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
