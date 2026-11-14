import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_dates.dart';
import 'package:sheettick/core/tasks/task_postpone.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalWriter writer;
  const paris = 'Europe/Paris';
  // 12:00 in Paris (UTC+1) on Thursday 12 November 2026.
  final now = DateTime.utc(2026, 11, 12, 11);

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

  Future<Task> postpone(Task t, PostponeTarget target) async {
    await postponeTasks(writer, [t], target, now: now, zone: paris);
    return reload(t);
  }

  group('the days', () {
    test('today, tomorrow, and next week is the next Monday', () {
      final thursday = DateTime.utc(2026, 11, 12, 18, 30);
      expect(postponeDay(PostponeTarget.today, thursday), DateTime.utc(2026, 11, 12));
      expect(postponeDay(PostponeTarget.tomorrow, thursday), DateTime.utc(2026, 11, 13));
      expect(postponeDay(PostponeTarget.nextWeek, thursday), DateTime.utc(2026, 11, 16));
      expect(postponeDay(PostponeTarget.noDate, thursday), isNull);
    });

    test('on a Monday next week is a week away, on a Sunday it is tomorrow; month and year ends roll over', () {
      expect(postponeDay(PostponeTarget.nextWeek, DateTime.utc(2026, 11, 16)), DateTime.utc(2026, 11, 23));
      expect(postponeDay(PostponeTarget.nextWeek, DateTime.utc(2026, 11, 15)), DateTime.utc(2026, 11, 16));
      expect(postponeDay(PostponeTarget.nextWeek, DateTime.utc(2026, 12, 30)), DateTime.utc(2027, 1, 4));
      expect(postponeDay(PostponeTarget.tomorrow, DateTime.utc(2026, 12, 31)), DateTime.utc(2027, 1, 1));
    });
  });

  group('postponing', () {
    test('an all-day task moves to the day and keeps everything else', () async {
      final task = await add({
        'due_at': '2026-11-05',
        'all_day': true,
        'rrule': 'RRULE:FREQ=WEEKLY;BYDAY=TH',
        'repeat_from': 'COMPLETION',
        'reminders': '["TRIGGER:PT9H"]',
        'priority': 3,
        'tags': 'home',
      });
      final after = await postpone(task, PostponeTarget.tomorrow);
      expect(after.dueAt, '2026-11-13');
      expect(after.allDay, isTrue);
      expect(after.rrule, 'RRULE:FREQ=WEEKLY;BYDAY=TH');
      expect(after.repeatFrom, 'COMPLETION');
      expect(after.reminders, '["TRIGGER:PT9H"]');
      expect(after.priority, 3);
      expect(after.tags, 'home');
      expect(after.status, 0);
      expect(after.version, 2);
    });

    test('a timed task keeps its time of day and zone', () async {
      final task = await add({'due_at': '2026-11-03T09:30:00+01:00', 'tz': paris});
      final after = await postpone(task, PostponeTarget.nextWeek);
      expect(after.dueAt, '2026-11-16T09:30:00+01:00');
      expect(after.tz, paris);
      expect(after.allDay, isFalse);
    });

    test('the time of day survives a clock change: the wall-clock time stays, the offset follows', () async {
      // Summer time in Paris ends on Sunday 25 October 2026 (UTC+2 to UTC+1).
      final task = await add({'due_at': '2026-10-20T09:30:00+02:00', 'tz': paris});
      final after = await postpone(task, PostponeTarget.today);
      expect(after.dueAt, '2026-11-12T09:30:00+01:00');
    });

    test('start and due move together, keeping the distance between them', () async {
      final task = await add({'start_at': '2026-11-02T08:00:00+01:00', 'due_at': '2026-11-04T17:00:00+01:00', 'tz': paris});
      final after = await postpone(task, PostponeTarget.today);
      expect(after.dueAt, '2026-11-12T17:00:00+01:00');
      expect(after.startAt, '2026-11-10T08:00:00+01:00');
    });

    test('a task with only a start moves its start', () async {
      final task = await add({'start_at': '2026-11-02', 'all_day': true});
      final after = await postpone(task, PostponeTarget.tomorrow);
      expect(after.startAt, '2026-11-13');
      expect(after.dueAt, isNull);
    });

    test('a task moved earlier works too: a future task can be brought to today', () async {
      final task = await add({'due_at': '2027-02-01', 'all_day': true});
      expect((await postpone(task, PostponeTarget.today)).dueAt, '2026-11-12');
    });

    test('a task with no date gets that day, all day', () async {
      final task = await add({});
      final after = await postpone(task, PostponeTarget.tomorrow);
      expect(after.dueAt, '2026-11-13');
      expect(after.allDay, isTrue);
      expect(after.tz, isNull);
    });

    test('No date clears the dates but keeps the repeat rule and the reminders', () async {
      final task = await add({
        'start_at': '2026-11-02',
        'due_at': '2026-11-04',
        'all_day': true,
        'rrule': 'RRULE:FREQ=DAILY',
        'reminders': '["TRIGGER:PT9H"]',
      });
      final after = await postpone(task, PostponeTarget.noDate);
      expect(after.startAt, isNull);
      expect(after.dueAt, isNull);
      expect(after.allDay, isFalse);
      expect(after.rrule, 'RRULE:FREQ=DAILY');
      expect(after.reminders, '["TRIGGER:PT9H"]');
    });

    test('a task already there is left alone: no write, no new version', () async {
      final onDay = await add({'due_at': '2026-11-12', 'all_day': true});
      final undated = await add({});
      expect(await postpone(onDay, PostponeTarget.today).then((t) => t.version), 1);
      expect(await postpone(undated, PostponeTarget.noDate).then((t) => t.version), 1);
    });

    test('done and dropped tasks are not postponed', () async {
      for (final status in [2, -1]) {
        final task = await add({'due_at': '2026-11-05', 'all_day': true, 'status': status});
        expect(await postpone(task, PostponeTarget.today).then((t) => t.dueAt), '2026-11-05');
      }
    });

    test('several at once: all move in one transaction and the count is the ones that changed', () async {
      final a = await add({'due_at': '2026-11-05', 'all_day': true});
      final b = await add({'due_at': '2026-11-08T10:00:00+01:00', 'tz': paris});
      final c = await add({'due_at': '2026-11-12', 'all_day': true});
      final moved = await postponeTasks(writer, [a, b, c], PostponeTarget.today, now: now, zone: paris);
      expect(moved, 2);
      expect((await reload(a)).dueAt, '2026-11-12');
      expect((await reload(b)).dueAt, '2026-11-12T10:00:00+01:00');
      expect((await reload(c)).version, 1);
    });

    test('the day is read on the device zone: late evening in Paris is already tomorrow in Auckland', () async {
      final task = await add({'due_at': '2026-11-05', 'all_day': true});
      // 23:30 in Paris on the 12th is 11:30 on the 13th in Auckland.
      final late = DateTime.utc(2026, 11, 12, 22, 30);
      await postponeTasks(writer, [task], PostponeTarget.today, now: late, zone: 'Pacific/Auckland');
      expect((await reload(task)).dueAt, '2026-11-13');
    });
  });

  group('overdue', () {
    test('an open task whose due day or time has gone by', () async {
      final yesterday = await add({'due_at': '2026-11-11', 'all_day': true});
      final today = await add({'due_at': '2026-11-12', 'all_day': true});
      final earlier = await add({'due_at': '2026-11-12T09:00:00+01:00', 'tz': paris});
      final later = await add({'due_at': '2026-11-12T18:00:00+01:00', 'tz': paris});
      final undated = await add({});
      final startOnly = await add({'start_at': '2026-11-01', 'all_day': true});
      final done = await add({'due_at': '2026-11-01', 'all_day': true, 'status': 2});
      bool over(Task t) => isOverdueTask(t, now: now, zone: paris);
      expect(
        [yesterday, today, earlier, later, undated, startOnly, done].map(over),
        [true, false, true, false, false, false, false],
      );
    });

    test('postponeChanges says whether a menu item would do anything', () async {
      final task = await add({'due_at': '2026-11-12', 'all_day': true});
      bool changes(PostponeTarget t) => postponeChanges(task, t, now: now, zone: paris);
      expect(changes(PostponeTarget.today), isFalse);
      expect(changes(PostponeTarget.tomorrow), isTrue);
      expect(changes(PostponeTarget.noDate), isTrue);
      expect(postponeChanges(await add({}), PostponeTarget.noDate, now: now, zone: paris), isFalse);
    });
  });

  test('postponedDates is pure', () {
    final d = postponedDates(const TaskDates(), PostponeTarget.today, todayWall: DateTime.utc(2026, 11, 12, 9));
    expect(d.due, DateTime.utc(2026, 11, 12));
    expect(d.allDay, isTrue);
  });
}
