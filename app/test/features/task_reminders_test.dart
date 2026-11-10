import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/app.dart';
import 'package:sheettick/core/auth/auth_controller.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/providers.dart';
import 'package:sheettick/core/reminders/reminder_planner.dart';
import 'package:sheettick/core/reminders/reminder_scheduler.dart';
import 'package:sheettick/core/reminders/snooze.dart';
import 'package:sheettick/core/time.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';

import '../support/fake_auth_service.dart';

class RecordingScheduler implements ReminderScheduler {
  RecordingScheduler({this.allowed = true});

  final bool allowed;
  int permissionAsks = 0;
  final plans = <List<PlannedReminder>>[];

  List<PlannedReminder> get latest => plans.last;

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return allowed;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, DateTime now) async => plans.add(plan);

  @override
  void dispose() {}
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const zone = 'Europe/Paris';

  late AppDatabase db;
  late DriftLocalStore store;
  LocalWriter writer() => LocalWriter(store, deviceId: 'win-test');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  Widget app(RecordingScheduler scheduler) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWith((ref) => 'win-test'),
        deviceZoneProvider.overrideWith((ref) async => zone),
        authServiceProvider.overrideWithValue(FakeAuthService()),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: const SheetTickApp(),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> animate(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<String> seedInbox(WidgetTester tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('lists', {'name': 'Inbox', 'is_inbox': true});
    });
    return id;
  }

  Future<Task> onlyTask(WidgetTester tester) async => (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;

  /// A day [offset] days from now, as `YYYY-MM-DD` (the exact day does not matter to these tests).
  String day(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> openTask(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await animate(tester);
    await settle(tester);
  }

  Future<void> openReminders(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('taskReminders')));
    await animate(tester);
  }

  Future<void> choose(WidgetTester tester, String trigger) async {
    await tester.tap(find.byKey(Key('reminder:$trigger')));
    await tester.pump();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('remindersDone')));
    await animate(tester);
    await settle(tester);
  }

  testWidgets('a task with a due time gets a reminder from the page: stored as the Sheet describes it, permission asked', (
    tester,
  ) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Call the bank',
        'due_at': '${day(2)}T09:00:00+01:00',
        'tz': zone,
      }),
    );
    final scheduler = RecordingScheduler();
    await tester.pumpWidget(app(scheduler));
    await settle(tester);
    await openTask(tester, 'Call the bank');
    expect(find.descendant(of: find.byKey(const Key('taskReminders')), matching: find.text('Add reminder')), findsOneWidget);

    await openReminders(tester);
    expect(find.text('15 minutes before'), findsOneWidget);
    expect(find.text('On the day, 9:00'), findsNothing);
    await choose(tester, 'TRIGGER:-PT15M');
    await choose(tester, 'TRIGGER:PT0S');
    await done(tester);

    final task = await onlyTask(tester);
    expect(task.reminders, '["TRIGGER:-PT15M","TRIGGER:PT0S"]');
    expect(task.version, 2);
    expect(scheduler.permissionAsks, 1);
    expect(find.descendant(of: find.byKey(const Key('taskReminders')), matching: find.text('2 reminders')), findsOneWidget);
    // The plan handed to the platform follows the row, with no sync in between.
    final plan = scheduler.latest.where((r) => r.taskId == task.id).toList();
    expect(plan, hasLength(2));
    expect(plan.first.at.isBefore(plan.last.at), isTrue);
    await unmount(tester);
  });

  testWidgets('an all-day task is offered times of day, and its reminder is stored the way TickTick writes it', (
    tester,
  ) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent', 'due_at': day(3), 'all_day': true}),
    );
    final scheduler = RecordingScheduler();
    await tester.pumpWidget(app(scheduler));
    await settle(tester);
    await openTask(tester, 'Pay rent');

    await openReminders(tester);
    expect(find.text('15 minutes before'), findsNothing);
    expect(find.text('1 day before, 9:00'), findsOneWidget);
    await choose(tester, 'TRIGGER:-PT15H');
    await done(tester);

    expect((await onlyTask(tester)).reminders, '["TRIGGER:-PT15H"]');
    expect(find.descendant(of: find.byKey(const Key('taskReminders')), matching: find.text('1 day before, 9:00')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('refusing notifications keeps the reminder and says it will not show', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent', 'due_at': day(3), 'all_day': true}),
    );
    final scheduler = RecordingScheduler(allowed: false);
    await tester.pumpWidget(app(scheduler));
    await settle(tester);
    await openTask(tester, 'Pay rent');

    await openReminders(tester);
    await choose(tester, 'TRIGGER:PT9H');
    await done(tester);

    expect(scheduler.permissionAsks, 1);
    expect((await onlyTask(tester)).reminders, '["TRIGGER:PT9H"]');
    expect(find.textContaining('Notifications are off'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('removing a reminder does not ask for permission, and an unchanged Done writes nothing', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Pay rent',
        'due_at': day(3),
        'all_day': true,
        'reminders': '["TRIGGER:PT9H"]',
      }),
    );
    final scheduler = RecordingScheduler();
    await tester.pumpWidget(app(scheduler));
    await settle(tester);
    await openTask(tester, 'Pay rent');

    await openReminders(tester);
    await done(tester);
    expect((await onlyTask(tester)).version, 1);

    await openReminders(tester);
    await choose(tester, 'TRIGGER:PT9H');
    await done(tester);
    final task = await onlyTask(tester);
    expect(task.reminders, isNull);
    expect(task.version, 2);
    expect(scheduler.permissionAsks, 0);
    expect(scheduler.latest.where((r) => r.taskId == task.id), isEmpty);
    await unmount(tester);
  });

  testWidgets('a reminder the Sheet holds that the picker does not offer is listed and can be removed', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Pay rent',
        'due_at': '${day(3)}T09:00:00+01:00',
        'tz': zone,
        'reminders': '["TRIGGER:-PT2H"]',
      }),
    );
    final scheduler = RecordingScheduler();
    await tester.pumpWidget(app(scheduler));
    await settle(tester);
    await openTask(tester, 'Pay rent');

    await openReminders(tester);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('-PT2H')), findsOneWidget);
    await choose(tester, 'TRIGGER:-PT2H');
    await done(tester);
    expect((await onlyTask(tester)).reminders, isNull);
    await unmount(tester);
  });

  testWidgets('a task with no date cannot have a reminder yet', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent'}));
    await tester.pumpWidget(app(RecordingScheduler()));
    await settle(tester);
    await openTask(tester, 'Pay rent');

    final chip = tester.widget<ActionChip>(find.byKey(const Key('taskReminders')));
    expect(chip.onPressed, isNull);
    await unmount(tester);
  });

  testWidgets('completing a task takes its reminders out of the plan', (tester) async {
    final inbox = await seedInbox(tester);
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Pay rent',
        'due_at': day(3),
        'all_day': true,
        'reminders': '["TRIGGER:PT9H"]',
      });
    });
    final scheduler = RecordingScheduler();
    await tester.pumpWidget(app(scheduler));
    await settle(tester);
    expect(scheduler.latest.where((r) => r.taskId == id), hasLength(1));

    await tester.runAsync(() => writer().update('tasks', id, {'status': 2}));
    await settle(tester);
    expect(scheduler.latest.where((r) => r.taskId == id), isEmpty);
    await unmount(tester);
  });

  testWidgets('a row that arrives from a sync is planned like one typed here', (tester) async {
    final inbox = await seedInbox(tester);
    final scheduler = RecordingScheduler();
    await tester.pumpWidget(app(scheduler));
    await settle(tester);
    expect(scheduler.latest, isEmpty);

    // A pull writes through the store, not through the page.
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('tasks', {
        'list_id': inbox,
        'title': 'From the phone',
        'due_at': day(4),
        'all_day': true,
        'reminders': '["TRIGGER:PT9H"]',
      });
    });
    await settle(tester);
    expect(scheduler.latest.map((r) => r.taskId), [id]);
    await unmount(tester);
  });

  group('snooze', () {
    /// A task that was due 30 minutes ago and has a reminder at that moment.
    Future<String> seedDuePast(WidgetTester tester) async {
      final inbox = await seedInbox(tester);
      late String id;
      await tester.runAsync(() async {
        id = await writer().insert('tasks', {
          'list_id': inbox,
          'title': 'Call the bank',
          'due_at': formatUtc(DateTime.now().subtract(const Duration(minutes: 30))),
          'tz': zone,
          'reminders': '["TRIGGER:PT0S"]',
        });
      });
      return id;
    }

    Future<void> snoozeWith(WidgetTester tester, String choice) async {
      await tester.tap(find.byKey(const Key('taskSnooze')));
      await animate(tester);
      await tester.tap(find.byKey(Key(choice)));
      await animate(tester);
      await settle(tester);
    }

    testWidgets('Snooze moves the reminder 10 minutes on, leaves the task as it was, and the plan follows', (
      tester,
    ) async {
      final id = await seedDuePast(tester);
      final scheduler = RecordingScheduler();
      await tester.pumpWidget(app(scheduler));
      await settle(tester);
      await openTask(tester, 'Call the bank');
      // Due half an hour ago: still in the plan (a closed app catches up on the last day), at its own time.
      expect(scheduler.latest.single.at.isBefore(DateTime.now()), isTrue);
      final before = await onlyTask(tester);

      await snoozeWith(tester, 'snooze:10m');

      final task = await onlyTask(tester);
      expect(task.dueAt, before.dueAt);
      expect(task.reminders, before.reminders);
      expect(task.version, before.version);
      final r = scheduler.latest.single;
      expect(r.taskId, id);
      final wait = r.at.difference(DateTime.now());
      expect(wait, greaterThan(const Duration(minutes: 9)));
      expect(wait, lessThanOrEqualTo(const Duration(minutes: 10)));
      expect(find.textContaining('Snoozed until'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('snoozing again replaces the first snooze', (tester) async {
      await seedDuePast(tester);
      final scheduler = RecordingScheduler();
      await tester.pumpWidget(app(scheduler));
      await settle(tester);
      await openTask(tester, 'Call the bank');

      await snoozeWith(tester, 'snooze:10m');
      await snoozeWith(tester, 'snooze:1h');
      expect(scheduler.latest, hasLength(1));
      expect(scheduler.latest.single.at.difference(DateTime.now()), greaterThan(const Duration(minutes: 50)));
      await unmount(tester);
    });

    testWidgets('a snooze made on the notification with the app closed is read when the plan is made again', (
      tester,
    ) async {
      final id = await seedDuePast(tester);
      final scheduler = RecordingScheduler();
      await tester.pumpWidget(app(scheduler));
      await settle(tester);
      expect(scheduler.latest.single.at.isBefore(DateTime.now()), isTrue);

      await tester.runAsync(() async {
        final row = await db.select(db.tasks).getSingle();
        // A moment is held to the minute, so the reminder was due at the start of that minute.
        final d = DateTime.parse(row.dueAt!).toUtc();
        await snoozeStoreOf(db).snooze(
          '$id|TRIGGER:PT0S',
          from: DateTime.utc(d.year, d.month, d.day, d.hour, d.minute),
          until: DateTime.now().add(const Duration(minutes: 5)),
          now: DateTime.now(),
        );
        // Any task change makes the plan again, as the app coming back to the front does.
        await writer().update('tasks', id, {'title': 'Call the bank today'});
      });
      await settle(tester);
      expect(scheduler.latest.single.taskId, id);
      expect(scheduler.latest.single.at.isAfter(DateTime.now()), isTrue);
      await unmount(tester);
    });

    testWidgets('there is nothing to snooze on a task with no reminder', (tester) async {
      final inbox = await seedInbox(tester);
      await tester.runAsync(
        () => writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent', 'due_at': day(3), 'all_day': true}),
      );
      await tester.pumpWidget(app(RecordingScheduler()));
      await settle(tester);
      await openTask(tester, 'Pay rent');
      expect(find.byKey(const Key('taskSnooze')), findsNothing);
      await unmount(tester);
    });
  });
}
