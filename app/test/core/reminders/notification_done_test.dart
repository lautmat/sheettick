import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/reminders/notification_done.dart';
import 'package:sheettick/core/reminders/snooze.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_status.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalWriter writer;
  const paris = 'Europe/Paris';
  final now = DateTime.utc(2026, 11, 7, 11);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'and-test');
  });

  tearDown(() => db.close());

  Future<String> add(Map<String, Object?> fields) =>
      writer.insert('tasks', {'title': 'Book dermato', 'due_at': '2026-11-07', 'all_day': true, ...fields});

  String payloadFor(String id) =>
      ReminderPayload(taskId: id, key: '$id|TRIGGER:PT9H', originalAt: now, title: 'Book dermato', body: 'Today')
          .encode();

  Future<String?> press(String? actionId, String? payload) => completeFromNotification(
    actionId: actionId,
    payload: payload,
    db: db,
    writer: writer,
    now: now,
    zone: paris,
  );

  Future<List<Task>> all() => (db.select(db.tasks)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  test('Done completes the task, bumping its version, as the app does', () async {
    final id = await add({});
    expect(await press(kDoneActionId, payloadFor(id)), id);
    final task = (await all()).single;
    expect(task.status, TaskStatus.completed.value);
    expect(task.completedAt, isNotNull);
    expect(task.version, 2);
    expect(task.device, 'and-test');
  });

  test('Done on a repeating task finishes this round and creates the next one', () async {
    final id = await add({'rrule': 'RRULE:FREQ=DAILY'});
    expect(await press(kDoneActionId, payloadFor(id)), id);
    final tasks = await all();
    expect(tasks, hasLength(2));
    expect(tasks[0].status, TaskStatus.completed.value);
    expect(tasks[0].rrule, isNull);
    expect(tasks[1].status, TaskStatus.open.value);
    expect(tasks[1].dueAt, '2026-11-08');
    expect(tasks[1].rrule, 'RRULE:FREQ=DAILY');
  });

  test('a task already finished elsewhere, or deleted, is left alone', () async {
    final done = await add({'status': TaskStatus.completed.value});
    final gone = await add({});
    await writer.update('tasks', gone, {'deleted': true});
    expect(await press(kDoneActionId, payloadFor(done)), isNull);
    expect(await press(kDoneActionId, payloadFor(gone)), isNull);
    expect((await all()).map((t) => t.version), [1, 2]);
  });

  test('a snooze button, an unknown payload or a missing task does nothing', () async {
    final id = await add({});
    expect(await press(SnoozeAction.tenMinutes.id, payloadFor(id)), isNull);
    expect(await press(null, payloadFor(id)), isNull);
    expect(await press(kDoneActionId, 'not json'), isNull);
    expect(await press(kDoneActionId, payloadFor('no-such-task')), isNull);
    expect((await all()).single.status, TaskStatus.open.value);
  });
}
