import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_badges.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
  });

  tearDown(() => db.close());

  Future<Task> task(Map<String, Object?> fields) async {
    final id = await writer.insert('tasks', {'title': 'T', ...fields});
    return (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
  }

  test('checklist progress counts the ticked and the live items of each task', () async {
    await writer.insert('checklist', {'task_id': 'a', 'title': '1', 'status': 2});
    await writer.insert('checklist', {'task_id': 'a', 'title': '2', 'status': 0});
    await writer.insert('checklist', {'task_id': 'b', 'title': '3', 'status': 2});
    final gone = await writer.insert('checklist', {'task_id': 'a', 'title': 'gone', 'status': 2});
    await writer.delete('checklist', gone);
    await writer.insert('checklist', {'title': 'typed in the Sheet with no task'});

    expect(checklistProgress(await db.select(db.checklist).get()), {
      'a': (done: 1, total: 2),
      'b': (done: 1, total: 1),
    });
  });

  test('subtask counts take open and completed children, not deleted or dropped ones', () async {
    final rows = [
      await task({'parent_id': 'p'}),
      await task({'parent_id': 'p', 'status': 2}),
      await task({'parent_id': 'p', 'status': -1}),
      await task({'parent_id': 'q'}),
      await task({}),
    ];
    final dropped = await task({'parent_id': 'p'});
    await writer.delete('tasks', dropped.id);

    expect(subtaskCounts(await db.select(db.tasks).get()), {'p': 2, 'q': 1});
    expect(rows, hasLength(5));
  });

  test('a reminder, a repeat and a note count only when there is something in them', () async {
    final all = await task({'reminders': '["TRIGGER:PT9H"]', 'rrule': 'RRULE:FREQ=DAILY', 'content': 'Bring the form'});
    expect([hasReminder(all), isRepeating(all), hasNote(all)], [true, true, true]);

    final none = await task({});
    expect([hasReminder(none), isRepeating(none), hasNote(none)], [false, false, false]);

    final empty = await task({'reminders': '[]', 'rrule': ' ', 'content': ' \n '});
    expect([hasReminder(empty), isRepeating(empty), hasNote(empty)], [false, false, false]);

    expect(hasReminder(await task({'reminders': 'not json'})), isFalse);
  });
}
