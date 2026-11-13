import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_skip.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalWriter writer;
  const paris = 'Europe/Paris';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
  });

  tearDown(() => db.close());

  Future<Task> add(Map<String, Object?> fields) async {
    final id = await writer.insert('tasks', {'title': 'Pay Visa card', ...fields});
    return (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<Task> reload(Task t) => (db.select(db.tasks)..where((r) => r.id.equals(t.id))).getSingle();

  test('skipping moves the same task to the next occurrence, still open, and records the skipped day', () async {
    final task = await add({'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=MONTHLY;BYMONTHDAY=1', 'priority': 3});
    expect(await skipOccurrence(writer, task, zone: paris), SkipOutcome.skipped);

    final after = await reload(task);
    expect(after.id, task.id);
    expect(after.status, 0);
    expect(after.completedAt, isNull);
    expect(after.dueAt, '2027-01-01');
    expect(after.allDay, isTrue);
    expect(after.rrule, 'RRULE:FREQ=MONTHLY;BYMONTHDAY=1');
    expect(jsonDecode(after.exDates!), ['2026-12-01']);
    expect(after.priority, 3);
    expect(after.version, 2, reason: 'one write through the local writer');
    expect(await db.select(db.tasks).get(), hasLength(1), reason: 'no new task is made');
  });

  test('it counts from the task date, not from today: an overdue task moves one step', () async {
    final task = await add({'due_at': '2020-01-01', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY'});
    await skipOccurrence(writer, task, zone: paris);
    expect((await reload(task)).dueAt, '2020-01-02');
  });

  test('repeat from completion does not change what skip means', () async {
    final task = await add({'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY;INTERVAL=3', 'repeat_from': 'COMPLETION'});
    await skipOccurrence(writer, task, zone: paris);
    expect((await reload(task)).dueAt, '2026-12-04');
  });

  test('skipping twice lists both days, in order', () async {
    final task = await add({'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY'});
    await skipOccurrence(writer, task, zone: paris);
    await skipOccurrence(writer, await reload(task), zone: paris);
    final after = await reload(task);
    expect(after.dueAt, '2026-12-03');
    expect(jsonDecode(after.exDates!), ['2026-12-01', '2026-12-02']);
  });

  test('days already in ex_dates are kept, and a listed day is not landed on', () async {
    final task = await add({
      'due_at': '2026-12-01',
      'all_day': true,
      'rrule': 'RRULE:FREQ=DAILY',
      'ex_dates': '["2026-12-02","2026-11-20"]',
    });
    await skipOccurrence(writer, task, zone: paris);
    final after = await reload(task);
    expect(after.dueAt, '2026-12-03');
    expect(jsonDecode(after.exDates!), ['2026-11-20', '2026-12-01', '2026-12-02']);
  });

  test('a timed task keeps its time of day, and a start keeps its distance from the due', () async {
    final task = await add({
      'start_at': '2026-12-01T08:00:00+01:00',
      'due_at': '2026-12-01T09:30:00+01:00',
      'tz': paris,
      'rrule': 'RRULE:FREQ=WEEKLY;BYDAY=TU',
    });
    await skipOccurrence(writer, task, zone: paris);
    final after = await reload(task);
    expect(after.startAt, '2026-12-08T08:00:00+01:00');
    expect(after.dueAt, '2026-12-08T09:30:00+01:00');
    expect(after.allDay, isFalse);
    expect(after.tz, paris);
  });

  test('COUNT counts the skipped one as used, and the last one cannot be skipped', () async {
    final task = await add({'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY;COUNT=2'});
    expect(await skipOccurrence(writer, task, zone: paris), SkipOutcome.skipped);
    final once = await reload(task);
    expect(once.rrule, 'RRULE:FREQ=DAILY;COUNT=1');
    expect(await skipOccurrence(writer, once, zone: paris), SkipOutcome.noMoreOccurrences);
    final same = await reload(task);
    expect(same.dueAt, once.dueAt);
    expect(same.version, once.version, reason: 'nothing written');
  });

  test('UNTIL ends the series: no occurrence after it', () async {
    final task = await add({'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY;UNTIL=20261201T235959Z'});
    expect(await skipOccurrence(writer, task, zone: paris), SkipOutcome.noMoreOccurrences);
    expect((await reload(task)).version, 1);
  });

  test('ticked checklist items are unticked for the new round, unticked ones are left alone', () async {
    final task = await add({'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY', 'kind': 'CHECKLIST'});
    final ticked = await writer.insert('checklist', {'task_id': task.id, 'title': 'a', 'status': 2, 'completed_at': '2026-11-30T10:00:00Z'});
    final open = await writer.insert('checklist', {'task_id': task.id, 'title': 'b', 'status': 0});
    await skipOccurrence(writer, task, zone: paris);
    final items = {for (final i in await (db.select(db.checklist)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get()) i.id: i};
    expect(items[ticked]!.status, 0);
    expect(items[ticked]!.completedAt, isNull);
    expect(items[ticked]!.version, 2);
    expect(items[open]!.version, 1);
  });

  test('nothing to skip: not repeating, no date, not open, unreadable rule', () async {
    for (final fields in <Map<String, Object?>>[
      {'due_at': '2026-12-01', 'all_day': true},
      {'rrule': 'RRULE:FREQ=DAILY'},
      {'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY', 'status': 2},
      {'due_at': '2026-12-01', 'all_day': true, 'rrule': 'nonsense'},
    ]) {
      final task = await add(fields);
      expect(canSkipOccurrence(task), isFalse, reason: '$fields');
      expect(await skipOccurrence(writer, task, zone: paris), SkipOutcome.cannotSkip, reason: '$fields');
      expect((await reload(task)).version, 1);
    }
  });
}
