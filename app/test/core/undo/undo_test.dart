import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_completion.dart';
import 'package:sheettick/core/tasks/task_status.dart';
import 'package:sheettick/core/undo/undo.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
  });

  tearDown(() => db.close());

  Future<Task> task(String id) => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
  RowRef ref(String id) => (tab: 'tasks', id: id);

  test('an edit is undone by putting the changed columns back, with a new version', () async {
    final id = await writer.insert('tasks', {'title': 'Old', 'content': 'notes', 'priority': 1});
    final entry = await recordUndo(writer, 'Task edited', [ref(id)], () async {
      await writer.update('tasks', id, {'title': 'New', 'priority': 5});
      return const [];
    });
    expect(entry!.label, 'Task edited');
    // Only what changed is remembered.
    expect(entry.restore.single.before, {'title': 'Old', 'priority': 1});
    expect((await task(id)).title, 'New');

    await applyUndo(writer, entry);
    final t = await task(id);
    expect(t.title, 'Old');
    expect(t.priority, 1);
    expect(t.content, 'notes');
    // created, edited, undone: each write bumps the version, so the undo syncs as a change.
    expect(t.version, 3);
  });

  test('a change that writes nothing records nothing', () async {
    final id = await writer.insert('tasks', {'title': 'Same'});
    expect(await recordUndo(writer, 'x', [ref(id)], () async => const []), isNull);
    expect(await recordUndo(writer, 'x', [ref(id)], () async {
      await writer.update('tasks', id, {'title': 'Same'});
      return const [];
    }), isNull);
  });

  test('undo leaves alone a column that changed after the recorded one', () async {
    final id = await writer.insert('tasks', {'title': 'Old', 'priority': 1});
    final entry = await recordUndo(writer, 'Task edited', [ref(id)], () async {
      await writer.update('tasks', id, {'title': 'New'});
      return const [];
    });
    await writer.update('tasks', id, {'priority': 5}); // another edit, not part of the entry
    await applyUndo(writer, entry!);
    final t = await task(id);
    expect(t.title, 'Old');
    expect(t.priority, 5);
  });

  test('a delete is undone: the row comes back', () async {
    final id = await writer.insert('tasks', {'title': 'Doomed'});
    final entry = await recordUndo(writer, 'Task moved to Trash', [ref(id)], () async {
      await writer.delete('tasks', id);
      return const [];
    });
    expect((await task(id)).deleted, isTrue);
    await applyUndo(writer, entry!);
    expect((await task(id)).deleted, isFalse);
  });

  test("complete and won't do are undone: status and completion time go back", () async {
    final id = await writer.insert('tasks', {'title': 'Do it'});
    final done = await recordUndo(writer, 'Task completed', [ref(id)], () async {
      await setTaskStatus(writer, await task(id), TaskStatus.completed, now: DateTime.utc(2026, 11, 11), zone: null);
      return const [];
    });
    expect((await task(id)).status, 2);
    await applyUndo(writer, done!);
    var t = await task(id);
    expect(t.status, 0);
    expect(t.completedAt, isNull);

    final dropped = await recordUndo(writer, "Marked Won't Do", [ref(id)], () async {
      await setTaskStatus(writer, await task(id), TaskStatus.wontDo, now: DateTime.utc(2026, 11, 11), zone: null);
      return const [];
    });
    expect((await task(id)).status, -1);
    await applyUndo(writer, dropped!);
    t = await task(id);
    expect(t.status, 0);
  });

  test('completing a repeating task is undone completely: the next round is tombstoned and the rule comes back', () async {
    final id = await writer.insert('tasks', {
      'title': 'Water plants',
      'due_at': '2026-11-11',
      'all_day': true,
      'rrule': 'RRULE:FREQ=DAILY',
    });
    final entry = await recordUndo(writer, 'Task completed', [ref(id)], () async {
      final next = await setTaskStatus(
        writer,
        await task(id),
        TaskStatus.completed,
        now: DateTime.utc(2026, 11, 11, 9),
        zone: 'Europe/Paris',
      );
      return [if (next != null) ref(next)];
    });
    expect(entry!.created, hasLength(1));
    expect(await db.select(db.tasks).get(), hasLength(2));
    expect((await task(id)).rrule, isNull);

    await applyUndo(writer, entry);
    final all = await db.select(db.tasks).get();
    final live = all.where((t) => !t.deleted).toList();
    expect(live.map((t) => t.id), [id]);
    final original = await task(id);
    expect(original.status, 0);
    expect(original.rrule, 'RRULE:FREQ=DAILY');
    expect(all.singleWhere((t) => t.deleted).title, 'Water plants');
  });

  test('a failing body leaves nothing recorded and nothing written', () async {
    final id = await writer.insert('tasks', {'title': 'Old'});
    await expectLater(
      recordUndo(writer, 'x', [ref(id)], () async {
        await writer.update('tasks', id, {'title': 'Half'});
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect((await task(id)).title, 'Old');
  });
}
