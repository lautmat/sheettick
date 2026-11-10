import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/reminders/reminder_planner.dart';
import 'package:sheettick/core/reminders/reminder_trigger.dart';
import 'package:sheettick/core/reminders/snooze.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final now = DateTime.utc(2026, 11, 7, 12);

  group('SnoozeStore', () {
    late String? saved;
    late SnoozeStore store;

    setUp(() {
      saved = null;
      store = SnoozeStore(read: () async => saved, write: (j) async => saved = j);
    });

    test('starts empty', () async {
      expect(await store.load(), isEmpty);
    });

    test('keeps a snooze by reminder key and reads it back', () async {
      await store.snooze('a|TRIGGER:PT0S', from: now, until: now.add(const Duration(minutes: 10)), now: now);
      final all = await store.load();
      expect(all['a|TRIGGER:PT0S'], Snooze(from: now, until: now.add(const Duration(minutes: 10))));
    });

    test('snoozing again replaces the earlier snooze and keeps the others', () async {
      await store.snooze('a', from: now, until: now.add(const Duration(minutes: 10)), now: now);
      await store.snooze('b', from: now, until: now.add(const Duration(hours: 1)), now: now);
      await store.snooze('a', from: now, until: now.add(const Duration(hours: 3)), now: now);
      final all = await store.load();
      expect(all.keys, {'a', 'b'});
      expect(all['a']!.until, now.add(const Duration(hours: 3)));
    });

    test('a snooze that ended more than a day ago is forgotten', () async {
      await store.snooze('old', from: now, until: now.add(const Duration(minutes: 5)), now: now);
      final later = now.add(const Duration(days: 2));
      await store.snooze('new', from: later, until: later.add(const Duration(minutes: 5)), now: later);
      expect((await store.load()).keys, {'new'});
    });

    test('unreadable stored text reads as no snoozes and never throws', () async {
      for (final text in ['', 'nope', '[]', '{"a":1}', '{"a":{"from":"x","until":2}}']) {
        saved = text;
        expect(await store.load(), isEmpty, reason: text);
      }
    });
  });

  group('ReminderPayload', () {
    test('round-trips what a notification needs to be snoozed with the app closed', () {
      final p = ReminderPayload(
        taskId: 't',
        key: 't|TRIGGER:PT0S',
        originalAt: now,
        title: 'Pay rent',
        body: 'Due 2026-11-07',
      );
      final back = ReminderPayload.decode(p.encode())!;
      expect(back.taskId, 't');
      expect(back.key, 't|TRIGGER:PT0S');
      expect(back.originalAt, now);
      expect(back.title, 'Pay rent');
      expect(back.body, 'Due 2026-11-07');
    });

    test('text that is not ours decodes to null', () {
      for (final text in [null, '', 'task-id-only', '[]', '{"t":1}']) {
        expect(ReminderPayload.decode(text), isNull, reason: '$text');
      }
    });
  });

  group('snoozeFromNotification', () {
    late String? saved;
    late SnoozeStore store;
    final payload = ReminderPayload(
      taskId: 't',
      key: 't|TRIGGER:PT0S',
      originalAt: now,
      title: 'x',
      body: 'y',
    ).encode();

    setUp(() {
      saved = null;
      store = SnoozeStore(read: () async => saved, write: (j) async => saved = j);
    });

    test('a snooze button records the snooze for its length', () async {
      final done = await snoozeFromNotification(actionId: 'snooze:1h', payload: payload, now: now, store: store);
      expect(done!.snooze.until, now.add(const Duration(hours: 1)));
      expect(done.reminder.key, 't|TRIGGER:PT0S');
      expect((await store.load())['t|TRIGGER:PT0S']!.until, now.add(const Duration(hours: 1)));
    });

    test('a tap on the notification itself, another button or a foreign payload records nothing', () async {
      expect(await snoozeFromNotification(actionId: null, payload: payload, now: now, store: store), isNull);
      expect(await snoozeFromNotification(actionId: 'other', payload: payload, now: now, store: store), isNull);
      expect(await snoozeFromNotification(actionId: 'snooze:10m', payload: 'id', now: now, store: store), isNull);
      expect(saved, isNull);
    });
  });

  group('planning with snoozes', () {
    late AppDatabase db;
    late LocalWriter writer;
    const paris = 'Europe/Paris';

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
    });

    tearDown(() => db.close());

    Future<String> add(Map<String, Object?> fields) =>
        writer.insert('tasks', {'title': 'Task', 'tz': paris, 'reminders': '["TRIGGER:PT0S"]', ...fields});

    Future<List<PlannedReminder>> plan(Map<String, Snooze> snoozes) async {
      final tasks = await db.select(db.tasks).get();
      return planReminders(tasks, after: now, deviceZone: paris, snoozes: snoozes);
    }

    test('a snoozed reminder moves to the end of the snooze, and remembers when it was due', () async {
      final id = await add({'due_at': '2026-11-07T11:30:00+01:00'}); // 10:30Z, already past at `now`
      final key = '$id|TRIGGER:PT0S';
      final due = DateTime.utc(2026, 11, 7, 10, 30);
      expect(await plan({}), isEmpty);
      final r = (await plan({key: Snooze(from: due, until: now.add(const Duration(minutes: 10)))})).single;
      expect(r.at, now.add(const Duration(minutes: 10)));
      expect(r.originalAt, due);
      expect(r.key, key);
      expect(r.notificationId, notificationIdOf(key));
    });

    test('a snooze made for another time of the task no longer applies', () async {
      final id = await add({'due_at': '2026-11-08T11:30:00+01:00'});
      final stale = Snooze(from: DateTime.utc(2026, 11, 7, 10, 30), until: now.add(const Duration(minutes: 10)));
      final r = (await plan({'$id|TRIGGER:PT0S': stale})).single;
      expect(r.at, DateTime.utc(2026, 11, 8, 10, 30));
    });

    test('the task itself is not changed by planning a snooze', () async {
      final id = await add({'due_at': '2026-11-07T11:30:00+01:00'});
      final snooze = Snooze(from: DateTime.utc(2026, 11, 7, 10, 30), until: now.add(const Duration(hours: 1)));
      await plan({'$id|TRIGGER:PT0S': snooze});
      final task = await db.select(db.tasks).getSingle();
      expect(task.dueAt, '2026-11-07T11:30:00+01:00');
      expect(task.version, 1);
    });

    test('the snooze target is the latest reminder already due, else the next to come', () async {
      await add({
        'due_at': '2026-11-07T11:30:00+01:00',
        'reminders': '["TRIGGER:-PT1H","TRIGGER:PT0S","TRIGGER:PT2H"]',
      });
      final task = await db.select(db.tasks).getSingle();
      // Due 10:30Z, so reminders at 9:30Z, 10:30Z and 12:30Z. At 12:00Z the 10:30Z one is the latest already due.
      expect(snoozeTarget(task, now: now, deviceZone: paris)!.trigger, const ReminderTrigger());
      // At 8:00Z none is due yet: the first to come.
      final early = DateTime.utc(2026, 11, 7, 8);
      expect(snoozeTarget(task, now: early, deviceZone: paris)!.trigger, const ReminderTrigger(seconds: -3600));
    });

    test('a task with nothing to snooze has no target', () async {
      await add({'due_at': '2026-11-07T11:30:00+01:00', 'status': 2});
      await add({'reminders': null});
      for (final task in await db.select(db.tasks).get()) {
        expect(snoozeTarget(task, now: now, deviceZone: paris), isNull);
      }
    });
  });
}
