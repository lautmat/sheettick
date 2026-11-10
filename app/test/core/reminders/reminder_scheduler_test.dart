import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/reminders/alarm_reminder_scheduler.dart';
import 'package:sheettick/core/reminders/reminder_planner.dart';
import 'package:sheettick/core/reminders/reminder_scheduler.dart';
import 'package:sheettick/core/reminders/reminder_trigger.dart';

PlannedReminder reminder(String task, DateTime at, {String title = 'Task', ReminderTrigger? trigger}) => PlannedReminder(
  taskId: task,
  trigger: trigger ?? const ReminderTrigger(),
  at: at,
  title: title,
  body: 'Due soon',
);

class FakeAlarms implements AlarmPort {
  final pending = <int, DateTime>{};
  final scheduled = <int>[];
  final cancelled = <int>[];
  bool exact = true;
  bool allowed = true;
  bool failNext = false;

  @override
  Future<bool> requestPermission() async => allowed;

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required bool exact,
  }) async {
    if (failNext) {
      failNext = false;
      throw StateError('platform said no');
    }
    pending[id] = at;
    scheduled.add(id);
    lastExact = exact;
  }

  bool? lastExact;

  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
    cancelled.add(id);
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 7, 8);

  group('AlarmReminderScheduler', () {
    late FakeAlarms alarms;
    late AlarmReminderScheduler scheduler;

    setUp(() {
      alarms = FakeAlarms();
      scheduler = AlarmReminderScheduler(alarms);
    });

    test('sets an alarm for each upcoming reminder', () async {
      final a = reminder('a', now.add(const Duration(hours: 1)));
      final b = reminder('b', now.add(const Duration(hours: 2)));
      await scheduler.replaceAll([a, b], now);
      expect(alarms.pending.keys, {a.notificationId, b.notificationId});
      expect(alarms.pending[a.notificationId], a.at);
    });

    test('a reminder already past is not set', () async {
      await scheduler.replaceAll([reminder('a', now.subtract(const Duration(minutes: 1)))], now);
      expect(alarms.pending, isEmpty);
    });

    test('an unchanged plan sets nothing again', () async {
      final plan = [reminder('a', now.add(const Duration(hours: 1)))];
      await scheduler.replaceAll(plan, now);
      alarms.scheduled.clear();
      await scheduler.replaceAll(plan, now);
      expect(alarms.scheduled, isEmpty);
      expect(alarms.cancelled, isEmpty);
    });

    test('a moved reminder is set again at the new time, and only that one', () async {
      final a = reminder('a', now.add(const Duration(hours: 1)));
      final b = reminder('b', now.add(const Duration(hours: 2)));
      await scheduler.replaceAll([a, b], now);
      alarms.scheduled.clear();
      final moved = reminder('a', now.add(const Duration(hours: 5)));
      await scheduler.replaceAll([moved, b], now);
      expect(alarms.scheduled, [a.notificationId]);
      expect(alarms.pending[a.notificationId], moved.at);
    });

    test('a reminder that left the plan (task done, deleted or its date cleared) is cancelled', () async {
      final a = reminder('a', now.add(const Duration(hours: 1)));
      final b = reminder('b', now.add(const Duration(hours: 2)));
      await scheduler.replaceAll([a, b], now);
      await scheduler.replaceAll([b], now);
      expect(alarms.cancelled, [a.notificationId]);
      expect(alarms.pending.keys, {b.notificationId});
    });

    test('alarms left from an earlier run that the plan does not want are cancelled', () async {
      alarms.pending[12345] = now.add(const Duration(hours: 1));
      await scheduler.replaceAll([], now);
      expect(alarms.pending, isEmpty);
    });

    test('alarms left from an earlier run that the plan wants are set again, so they match the plan', () async {
      final a = reminder('a', now.add(const Duration(hours: 1)));
      alarms.pending[a.notificationId] = now.add(const Duration(hours: 9));
      await scheduler.replaceAll([a], now);
      expect(alarms.pending[a.notificationId], a.at);
    });

    test('alarms are exact when the system allows it, inexact when it does not', () async {
      final plan = [reminder('a', now.add(const Duration(hours: 1)))];
      await scheduler.replaceAll(plan, now);
      expect(alarms.lastExact, isTrue);
      alarms.exact = false;
      await scheduler.replaceAll([reminder('b', now.add(const Duration(hours: 1)))], now);
      expect(alarms.lastExact, isFalse);
    });

    test('plans that arrive together are applied one after another, the last one winning', () async {
      final a = reminder('a', now.add(const Duration(hours: 1)));
      final b = reminder('b', now.add(const Duration(hours: 2)));
      await Future.wait([scheduler.replaceAll([a], now), scheduler.replaceAll([b], now)]);
      expect(alarms.pending.keys, {b.notificationId});
    });

    test('a platform failure is reported to the caller but does not stop the next plan', () async {
      final a = reminder('a', now.add(const Duration(hours: 1)));
      alarms.failNext = true;
      await expectLater(scheduler.replaceAll([a], now), throwsStateError);
      await scheduler.replaceAll([a], now);
      expect(alarms.pending.keys, {a.notificationId});
    });

    test('permission comes from the platform', () async {
      expect(await scheduler.requestPermission(), isTrue);
      alarms.allowed = false;
      expect(await scheduler.requestPermission(), isFalse);
    });
  });

  group('PollingReminderScheduler', () {
    late DateTime clock;
    late DateTime? lastLook;
    late List<String> shown;
    late PollingReminderScheduler scheduler;

    setUp(() {
      clock = now;
      lastLook = null;
      shown = [];
      scheduler = PollingReminderScheduler(
        show: (r) async => shown.add(r.taskId),
        clock: () => clock,
        loadLastLook: () async => lastLook,
        saveLastLook: (t) async => lastLook = t,
        interval: const Duration(hours: 1),
      );
    });

    tearDown(() => scheduler.dispose());

    test('shows a reminder once, when its time has come', () async {
      final a = reminder('a', now.add(const Duration(minutes: 10)));
      await scheduler.replaceAll([a], clock);
      expect(shown, isEmpty);
      clock = now.add(const Duration(minutes: 10, seconds: 5));
      await scheduler.look();
      expect(shown, ['a']);
      clock = now.add(const Duration(minutes: 20));
      await scheduler.look();
      expect(shown, ['a']);
    });

    test('the first run on a device does not replay the past', () async {
      await scheduler.replaceAll([reminder('old', now.subtract(const Duration(hours: 2)))], clock);
      expect(shown, isEmpty);
      expect(lastLook, now);
    });

    test('a reminder missed while the app was closed is shown on the next run', () async {
      lastLook = now.subtract(const Duration(hours: 3));
      await scheduler.replaceAll([reminder('missed', now.subtract(const Duration(hours: 1)))], clock);
      expect(shown, ['missed']);
    });

    test('a reminder that was already handled before the last look is not shown again', () async {
      lastLook = now.subtract(const Duration(minutes: 30));
      await scheduler.replaceAll([reminder('done', now.subtract(const Duration(hours: 1)))], clock);
      expect(shown, isEmpty);
    });

    test('what was missed longer ago than the catch-up window is dropped', () async {
      lastLook = now.subtract(const Duration(days: 5));
      await scheduler.replaceAll([
        reminder('stale', now.subtract(const Duration(days: 2))),
        reminder('recent', now.subtract(const Duration(hours: 2))),
      ], clock);
      expect(shown, ['recent']);
    });

    test('a plan that no longer holds a reminder does not show it', () async {
      await scheduler.replaceAll([reminder('a', now.add(const Duration(minutes: 10)))], clock);
      await scheduler.replaceAll([], clock);
      clock = now.add(const Duration(minutes: 11));
      await scheduler.look();
      expect(shown, isEmpty);
    });

    test('a clock that moved back does not show a reminder in the future', () async {
      lastLook = now.add(const Duration(hours: 1));
      await scheduler.replaceAll([reminder('later', now.add(const Duration(minutes: 30)))], clock);
      expect(shown, isEmpty);
    });

    test('a failure to show one reminder does not stop the others', () async {
      final failing = PollingReminderScheduler(
        show: (r) async {
          if (r.taskId == 'bad') throw StateError('toast refused');
          shown.add(r.taskId);
        },
        clock: () => clock,
        loadLastLook: () async => lastLook,
        saveLastLook: (t) async => lastLook = t,
        interval: const Duration(hours: 1),
      );
      addTearDown(failing.dispose);
      lastLook = now.subtract(const Duration(hours: 1));
      await failing.replaceAll([
        reminder('bad', now.subtract(const Duration(minutes: 20))),
        reminder('good', now.subtract(const Duration(minutes: 10))),
      ], clock);
      expect(shown, ['good']);
    });

    test('permission is never asked of the user on Windows', () async {
      expect(await scheduler.requestPermission(), isTrue);
    });
  });

  test('the no-op scheduler accepts a plan and says notifications are off', () async {
    const scheduler = NoopReminderScheduler();
    await scheduler.replaceAll([reminder('a', now)], now);
    expect(await scheduler.requestPermission(), isFalse);
  });
}
