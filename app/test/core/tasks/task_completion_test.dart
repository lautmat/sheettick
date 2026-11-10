import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_completion.dart';
import 'package:sheettick/core/tasks/task_status.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalWriter writer;
  const paris = 'Europe/Paris';
  // Noon in Paris (UTC+1) on Saturday 7 November 2026.
  final now = DateTime.utc(2026, 11, 7, 11);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
  });

  tearDown(() => db.close());

  Future<Task> add(Map<String, Object?> fields) async {
    final id = await writer.insert('tasks', {'title': 'Water the plants', ...fields});
    return (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<List<Task>> all() => (db.select(db.tasks)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  Future<Task> reload(Task t) => (db.select(db.tasks)..where((r) => r.id.equals(t.id))).getSingle();

  group('finishing a repeating task', () {
    test('completing it creates the next one, open, with the dates moved on', () async {
      final task = await add({
        'due_at': '2026-11-07',
        'all_day': true,
        'rrule': 'RRULE:FREQ=DAILY',
        'priority': 3,
        'tags': 'home,plants',
        'content': 'Use the green can',
        'reminders': '["TRIGGER:PT9H"]',
      });
      final newId = await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris);

      final done = await reload(task);
      expect(done.status, 2);
      expect(done.completedAt, isNotNull);
      expect(done.rrule, isNull, reason: 'the finished task stops repeating, so reopening it starts no second series');
      expect(done.dueAt, '2026-11-07');

      final fresh = (await all()).singleWhere((t) => t.id == newId);
      expect(fresh.id, isNot(task.id));
      expect(fresh.status, 0);
      expect(fresh.completedAt, isNull);
      expect(fresh.dueAt, '2026-11-08');
      expect(fresh.allDay, isTrue);
      expect(fresh.rrule, 'RRULE:FREQ=DAILY');
      expect(fresh.title, 'Water the plants');
      expect(fresh.priority, 3);
      expect(fresh.tags, 'home,plants');
      expect(fresh.content, 'Use the green can');
      expect(fresh.reminders, '["TRIGGER:PT9H"]');
      expect(fresh.version, 1);
      expect(fresh.dirty, isTrue);
    });

    test('it stays in the same list, section and place', () async {
      final list = await writer.insert('lists', {'name': 'Home'});
      final section = await writer.insert('sections', {'list_id': list, 'name': 'Garden'});
      final task = await add({
        'list_id': list,
        'section_id': section,
        'sort_order': 4.0,
        'due_at': '2026-11-07',
        'all_day': true,
        'rrule': 'RRULE:FREQ=DAILY',
      });
      final newId = await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris);
      final fresh = (await all()).singleWhere((t) => t.id == newId);
      expect(fresh.listId, list);
      expect(fresh.sectionId, section);
      expect(fresh.sortOrder, 4.0);
    });

    test('a timed task is written with the offset its zone has on the new day', () async {
      final task = await add({
        'start_at': '2026-11-07T08:00:00+01:00',
        'due_at': '2026-11-07T09:30:00+01:00',
        'tz': paris,
        'rrule': 'RRULE:FREQ=DAILY',
      });
      final newId = await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris);
      final fresh = (await all()).singleWhere((t) => t.id == newId);
      expect(fresh.startAt, '2026-11-08T08:00:00+01:00');
      expect(fresh.dueAt, '2026-11-08T09:30:00+01:00');
      expect(fresh.tz, paris);
      expect(fresh.allDay, isFalse);
    });

    test('a checklist is carried over, unticked and in order', () async {
      final task = await add({'due_at': '2026-11-07', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY'});
      final b = await writer.insert('checklist', {'task_id': task.id, 'title': 'Second', 'sort_order': 2.0, 'status': 2});
      await writer.insert('checklist', {'task_id': task.id, 'title': 'First', 'sort_order': 1.0, 'status': 2});
      final gone = await writer.insert('checklist', {'task_id': task.id, 'title': 'Removed', 'sort_order': 3.0});
      await writer.delete('checklist', gone);
      final newId = await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris);

      final items = await (db.select(db.checklist)..where((c) => c.taskId.equals(newId!))).get();
      items.sort((x, y) => x.sortOrder.compareTo(y.sortOrder));
      expect(items.map((i) => i.title), ['First', 'Second']);
      expect(items.every((i) => i.status == 0 && i.completedAt == null), isTrue);
      // The finished task keeps its own items as they were.
      final old = await (db.select(db.checklist)..where((c) => c.id.equals(b))).getSingle();
      expect(old.status, 2);
    });

    test('won\'t do skips this round and creates the next one too', () async {
      final task = await add({'due_at': '2026-11-07', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY'});
      final newId = await setTaskStatus(writer, task, TaskStatus.wontDo, now: now, zone: paris);
      expect((await reload(task)).status, -1);
      expect(newId, isNotNull);
    });

    test('repeating from completion counts from the day it was finished', () async {
      final task = await add({
        'due_at': '2026-11-02',
        'all_day': true,
        'rrule': 'RRULE:FREQ=DAILY;INTERVAL=3',
        'repeat_from': 'COMPLETION',
      });
      final newId = await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris);
      final fresh = (await all()).singleWhere((t) => t.id == newId);
      expect(fresh.dueAt, '2026-11-10');
      expect(fresh.repeatFrom, 'COMPLETION');
    });

    test('ex_dates are skipped and carried on', () async {
      final task = await add({
        'due_at': '2026-11-07',
        'all_day': true,
        'rrule': 'RRULE:FREQ=DAILY',
        'ex_dates': '["2026-11-08"]',
      });
      final newId = await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris);
      final fresh = (await all()).singleWhere((t) => t.id == newId);
      expect(fresh.dueAt, '2026-11-09');
      expect(fresh.exDates, '["2026-11-08"]');
    });

    test('the last of a COUNT series creates nothing, and the series ends', () async {
      final task = await add({'due_at': '2026-11-07', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY;COUNT=1'});
      final newId = await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris);
      expect(newId, isNull);
      expect(await all(), hasLength(1));
      expect((await reload(task)).rrule, 'RRULE:FREQ=DAILY;COUNT=1');
    });
  });

  group('everything else is just the status change', () {
    test('a task that does not repeat', () async {
      final task = await add({'due_at': '2026-11-07', 'all_day': true});
      expect(await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris), isNull);
      expect(await all(), hasLength(1));
      expect((await reload(task)).status, 2);
    });

    test('a repeating task with no date', () async {
      final task = await add({'rrule': 'RRULE:FREQ=DAILY'});
      expect(await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris), isNull);
      expect(await all(), hasLength(1));
    });

    test('reopening a finished task creates nothing', () async {
      final task = await add({'due_at': '2026-11-07', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY'});
      await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris);
      final done = await reload(task);
      expect(await setTaskStatus(writer, done, TaskStatus.open, now: now, zone: paris), isNull);
      expect(await all(), hasLength(2));
      expect((await reload(task)).status, 0);
    });

    test('completing an already completed task again creates nothing more', () async {
      final task = await add({'due_at': '2026-11-07', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY'});
      await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: paris);
      final done = await reload(task);
      expect(await setTaskStatus(writer, done, TaskStatus.completed, now: now, zone: paris), isNull);
      expect(await all(), hasLength(2));
    });
  });
}
