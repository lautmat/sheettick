import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/reminders/reminder_planner.dart';
import 'package:sheettick/core/reminders/reminder_trigger.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
  });

  tearDown(() => db.close());

  const paris = 'Europe/Paris';
  const tokyo = 'Asia/Tokyo';
  final longAgo = DateTime.utc(2020);

  Future<String> add(Map<String, Object?> fields) => writer.insert('tasks', {'title': 'Task', ...fields});

  Future<List<PlannedReminder>> plan({
    DateTime? after,
    DateTime? until,
    String? zone = paris,
    int limit = 200,
  }) async {
    final tasks = await db.select(db.tasks).get();
    return planReminders(tasks, after: after ?? longAgo, until: until, deviceZone: zone, limit: limit);
  }

  const fifteenBefore = '["TRIGGER:-PT15M"]';

  test('a timed due with a reminder fires that long before it, as an exact instant', () async {
    await add({'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': fifteenBefore});
    final r = (await plan()).single;
    expect(r.at, DateTime.utc(2026, 11, 7, 7, 45));
    expect(r.body, 'Due 2026-11-07 09:00');
  });

  test('the same value on another device zone is the same instant', () async {
    await add({'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': fifteenBefore});
    expect((await plan(zone: tokyo)).single.at, DateTime.utc(2026, 11, 7, 7, 45));
  });

  test('a floating time fires at that clock time wherever the device is', () async {
    await add({'due_at': '2026-11-07T09:00:00+01:00', 'reminders': '["TRIGGER:PT0S"]'});
    expect((await plan(zone: tokyo)).single.at, DateTime.utc(2026, 11, 7, 0));
    expect((await plan(zone: paris)).single.at, DateTime.utc(2026, 11, 7, 8));
  });

  test('the reminder is relative to the start when there is one, and says so', () async {
    await add({
      'start_at': '2026-11-07T08:00:00+01:00',
      'due_at': '2026-11-07T18:00:00+01:00',
      'tz': paris,
      'reminders': fifteenBefore,
    });
    final r = (await plan()).single;
    expect(r.at, DateTime.utc(2026, 11, 7, 6, 45));
    expect(r.body, 'Starts 2026-11-07 08:00');
  });

  test('an all-day task counts from midnight, so the trigger holds the time of day', () async {
    await add({
      'due_at': '2026-11-07',
      'all_day': true,
      'reminders': '["TRIGGER:PT9H","TRIGGER:-PT15H","TRIGGER:-P1DT15H"]',
    });
    final r = await plan();
    expect(r.map((x) => x.at), [
      DateTime.utc(2026, 11, 5, 8), // 2 days before, 9:00 Paris (UTC+1)
      DateTime.utc(2026, 11, 6, 8),
      DateTime.utc(2026, 11, 7, 8),
    ]);
    expect(r.first.body, 'Due 2026-11-07');
  });

  test('whole days count on the calendar: one day before keeps its clock time across a daylight-saving change', () async {
    // Paris went from UTC+2 to UTC+1 on 2026-10-25.
    await add({'due_at': '2026-10-25T09:00:00+01:00', 'tz': paris, 'reminders': '["TRIGGER:-P1D"]'});
    expect((await plan()).single.at, DateTime.utc(2026, 10, 24, 7)); // 9:00 in Paris, UTC+2
  });

  test('a minutes-long reminder is exact time, even across a daylight-saving change', () async {
    await add({'due_at': '2026-10-25T03:30:00+01:00', 'tz': paris, 'reminders': '["TRIGGER:-PT4H"]'});
    // 03:30 +01:00 is 02:30 UTC; four hours before is 22:30 UTC the evening before.
    expect((await plan()).single.at, DateTime.utc(2026, 10, 24, 22, 30));
  });

  test('completed, won\'t do and deleted tasks have no reminders', () async {
    await add({'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': fifteenBefore, 'status': 2});
    await add({'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': fifteenBefore, 'status': -1});
    final gone = await add({'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': fifteenBefore});
    await writer.delete('tasks', gone);
    expect(await plan(), isEmpty);
  });

  test('a task with reminders but no date, or no reminders, has nothing to plan', () async {
    await add({'reminders': fifteenBefore});
    await add({'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris});
    await add({'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': 'nonsense'});
    expect(await plan(), isEmpty);
  });

  test('only reminders after `after` and up to `until` are planned', () async {
    await add({'title': 'a', 'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': '["TRIGGER:PT0S"]'});
    await add({'title': 'b', 'due_at': '2026-11-08T09:00:00+01:00', 'tz': paris, 'reminders': '["TRIGGER:PT0S"]'});
    await add({'title': 'c', 'due_at': '2026-11-09T09:00:00+01:00', 'tz': paris, 'reminders': '["TRIGGER:PT0S"]'});
    final r = await plan(after: DateTime.utc(2026, 11, 7, 8), until: DateTime.utc(2026, 11, 8, 8));
    // `after` is exclusive: a reminder exactly then has already been handled.
    expect(r.map((x) => x.title), ['b']);
  });

  test('earliest first, cut at the limit', () async {
    for (final day in [9, 7, 8]) {
      await add({'title': 'd$day', 'due_at': '2026-11-0${day}T09:00:00+01:00', 'tz': paris, 'reminders': '["TRIGGER:PT0S"]'});
    }
    expect((await plan()).map((x) => x.title), ['d7', 'd8', 'd9']);
    expect((await plan(limit: 2)).map((x) => x.title), ['d7', 'd8']);
  });

  test('a blank title still gets a readable notification', () async {
    await add({'title': '  ', 'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': fifteenBefore});
    expect((await plan()).single.title, 'Untitled task');
  });

  group('identity', () {
    test('the key and id follow the task and trigger, not the time', () async {
      final id = await add({'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': fifteenBefore});
      final before = (await plan()).single;
      await writer.update('tasks', id, {'due_at': '2026-11-08T09:00:00+01:00'});
      final after = (await plan()).single;
      expect(after.key, before.key);
      expect(after.notificationId, before.notificationId);
      expect(after.signature, isNot(before.signature));
    });

    test('different triggers on one task have different ids, all positive 31-bit', () async {
      await add({'due_at': '2026-11-07T09:00:00+01:00', 'tz': paris, 'reminders': '["TRIGGER:PT0S","TRIGGER:-PT5M","TRIGGER:-P1D"]'});
      final ids = (await plan()).map((x) => x.notificationId).toList();
      expect(ids.toSet(), hasLength(3));
      for (final id in ids) {
        expect(id, inInclusiveRange(0, 0x7fffffff));
      }
    });

    test('the id is fixed for a given key, so it survives restarts', () {
      final r = PlannedReminder(
        taskId: 'abc',
        trigger: const ReminderTrigger(seconds: -900),
        at: DateTime.utc(2026),
        title: 't',
        body: 'b',
      );
      expect(r.key, 'abc|TRIGGER:-PT15M');
      // FNV-1a over the key: pinned, because a changed id would orphan every alarm already set on a phone.
      expect(r.notificationId, 324978183);
    });
  });
}
