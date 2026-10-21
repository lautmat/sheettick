import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';

/// The version 1 tables, as an install made before folders, sections, checklist and tags looked like. Taken from
/// the app's own schema at version 1. The FTS table and its triggers are left out: the upgrade does not touch them.
const _v1Tables = [
  'CREATE TABLE "device_state" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"))',
  'CREATE TABLE "meta" ("key" TEXT NOT NULL, "value" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY ("key"))',
  'CREATE TABLE "lists" ("created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "version" INTEGER NOT NULL DEFAULT 1, '
      '"device" TEXT NOT NULL DEFAULT \'\', "deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("deleted" IN (0, 1)), '
      '"dirty" INTEGER NOT NULL DEFAULT 0 CHECK ("dirty" IN (0, 1)), "sheet_row" INTEGER NULL, "synced_hash" TEXT NULL, '
      '"base_snapshot" TEXT NULL, "id" TEXT NOT NULL, "name" TEXT NOT NULL DEFAULT \'\', "folder_id" TEXT NULL, '
      '"color" TEXT NULL, "kind" TEXT NOT NULL DEFAULT \'TASK\', "view" TEXT NOT NULL DEFAULT \'list\', "group_by" TEXT NULL, '
      '"order_by" TEXT NULL, "sort_order" REAL NOT NULL DEFAULT 0.0, "is_inbox" INTEGER NOT NULL DEFAULT 0 '
      'CHECK ("is_inbox" IN (0, 1)), "muted" INTEGER NOT NULL DEFAULT 0 CHECK ("muted" IN (0, 1)), '
      '"archived" INTEGER NOT NULL DEFAULT 0 CHECK ("archived" IN (0, 1)), PRIMARY KEY ("id"))',
];

void main() {
  test('a version 1 install gains the new tabs and keeps its rows', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final sql in _v1Tables) {
            raw.execute(sql);
          }
          raw.execute(
            "INSERT INTO lists (created_at, updated_at, id, name, is_inbox) "
            "VALUES ('2026-10-19T13:05:00Z', '2026-10-19T13:05:00Z', 'inbox-1', 'Inbox', 1)",
          );
          raw.execute("INSERT INTO device_state (key, value) VALUES ('spreadsheet_id', 'sheet-1')");
          raw.execute(
            "INSERT INTO device_state (key, value) VALUES ('last_drive_modified_time', '2026-10-20T10:00:00Z')",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(db.close);

    final tables = {
      for (final r in await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get())
        r.read<String>('name'),
    };
    expect(tables, containsAll(['folders', 'sections', 'checklist', 'tags']));

    final inbox = await db.customSelect("SELECT name FROM lists WHERE id = 'inbox-1'").getSingle();
    expect(inbox.read<String>('name'), 'Inbox');

    // The Drive check is forgotten, so the first sync pulls the new tabs; the spreadsheet id is kept.
    expect(await db.getDeviceState(DeviceStateKeys.lastDriveModifiedTime), isNull);
    expect(await db.getDeviceState(DeviceStateKeys.spreadsheetId), 'sheet-1');
  });
}
