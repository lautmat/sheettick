import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sheets/bootstrap.dart';
import 'package:sheettick/core/sheets/sheets_backend.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/sync/record.dart';
import 'package:sheettick/core/sync/sync_engine.dart';

/// One simulated install of the app: its own SQLite database, its own clock, its own device id, talking to a
/// (possibly shared) [SheetsBackend]. Tests move [now] to control `updated_at`.
class TestDevice {
  TestDevice._(this.id, this.db, this.store, this.backend, this.spreadsheetId, this.inboxId, this.now);

  final String id;
  final AppDatabase db;
  final DriftLocalStore store;
  final SheetsBackend backend;
  final String spreadsheetId;
  final String inboxId;

  /// This device's clock.
  DateTime now;

  late final SyncEngine engine = SyncEngine(backend: backend, store: store, deviceId: id, clock: () => now);
  late final LocalWriter writer = LocalWriter(store, deviceId: id, clock: () => now);

  static Future<TestDevice> create(
    SheetsBackend backend, {
    String id = 'win-0001',
    DateTime? start,
    SheetsBackend? engineBackend,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final clock = start ?? DateTime.utc(2026, 10, 19, 9);
    final boot = await SheetBootstrap(
      backend: backend,
      db: db,
      deviceId: id,
      appVersion: '0.1.0',
      clock: () => clock,
    ).run();
    return TestDevice._(id, db, DriftLocalStore(db), engineBackend ?? backend, boot.spreadsheetId, boot.inboxListId, clock);
  }

  Future<void> close() => db.close();

  Future<SyncResult> sync() => engine.sync();

  /// Moves this device's clock forward by [minutes].
  void tick([int minutes = 1]) => now = now.add(Duration(minutes: minutes));

  /// Adds a task to the Inbox and returns its id.
  Future<String> addTask(String title, {Fields extra = const {}}) =>
      writer.insert('tasks', {'list_id': inboxId, 'title': title, ...extra});

  Future<void> edit(String id, Fields changes) => writer.update('tasks', id, changes);

  Future<LocalRow> task(String id) async => (await store.getRow('tasks', id))!;

  Future<LocalRow?> list(String id) => store.getRow('lists', id);
}
