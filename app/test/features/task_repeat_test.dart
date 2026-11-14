import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/app.dart';
import 'package:sheettick/core/auth/auth_controller.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/providers.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_dates.dart';

import '../support/fake_auth_service.dart';

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

  Widget app() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWith((ref) => 'win-test'),
        deviceZoneProvider.overrideWith((ref) async => zone),
        authServiceProvider.overrideWithValue(FakeAuthService()),
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

  Future<List<Task>> tasks(WidgetTester tester) async => (await tester.runAsync(() => db.select(db.tasks).get()))!;

  Future<Task> onlyTask(WidgetTester tester) async => (await tasks(tester)).single;

  /// Today where the app shows it, plus [offset] days, as `YYYY-MM-DD`.
  String day(int offset) {
    final d = dayOf(const TaskDates(zone: zone).wallOf(DateTime.now())).add(Duration(days: offset));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> openTask(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await animate(tester);
    await settle(tester);
  }

  Future<void> openRepeat(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('taskRepeat')));
    await animate(tester);
  }

  Future<void> done(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('repeatDone')));
    await animate(tester);
    await settle(tester);
  }

  testWidgets('Repeat sets a rule and what it counts from, written to the Sheet\'s columns', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {'list_id': inbox, 'title': 'Water the plants', 'due_at': day(1), 'all_day': true}),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Water the plants');
    expect(find.descendant(of: find.byKey(const Key('taskRepeat')), matching: find.text('Repeat')), findsOneWidget);

    await openRepeat(tester);
    expect(find.byKey(const Key('repeatFrom')), findsNothing, reason: 'nothing to count from until it repeats');
    await tester.tap(find.byKey(const Key('repeat:FREQ=DAILY')));
    await tester.pump();
    // The dialog scrolls: bring the option into view before pressing it.
    await tester.ensureVisible(find.text('Completion'));
    await tester.pump();
    await tester.tap(find.text('Completion'));
    await tester.pump();
    await done(tester);

    final task = await onlyTask(tester);
    expect(task.rrule, 'RRULE:FREQ=DAILY');
    expect(task.repeatFrom, 'COMPLETION');
    expect(task.version, 2);
    expect(find.descendant(of: find.byKey(const Key('taskRepeat')), matching: find.text('Every day')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('"Does not repeat" clears the rule, and an unchanged Done writes nothing', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Water the plants',
        'due_at': day(1),
        'all_day': true,
        'rrule': 'RRULE:FREQ=YEARLY',
      }),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Water the plants');

    await openRepeat(tester);
    await done(tester);
    expect((await onlyTask(tester)).version, 1);

    await openRepeat(tester);
    await tester.tap(find.byKey(const Key('repeat:none')));
    await tester.pump();
    await done(tester);
    final task = await onlyTask(tester);
    expect(task.rrule, isNull);
    expect(task.version, 2);
    await unmount(tester);
  });

  testWidgets('a rule from the Sheet that the picker does not offer is listed and shown', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Water the plants',
        'due_at': day(1),
        'all_day': true,
        'rrule': 'RRULE:FREQ=MONTHLY;INTERVAL=3;BYDAY=2TU',
      }),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Water the plants');
    expect(
      find.descendant(of: find.byKey(const Key('taskRepeat')), matching: find.text('Every 3 months on 2nd Tuesday')),
      findsOneWidget,
    );
    await openRepeat(tester);
    expect(find.byKey(const Key('repeat:FREQ=MONTHLY;INTERVAL=3;BYDAY=2TU')), findsOneWidget);
    await tester.tap(find.byKey(const Key('repeatCancel')));
    await animate(tester);
    await unmount(tester);
  });

  Future<void> seedRepeating(WidgetTester tester, String rrule) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {'list_id': inbox, 'title': 'Water the plants', 'due_at': day(1), 'all_day': true, 'rrule': rrule}),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Water the plants');
  }

  testWidgets('Custom builds a rule: every 3 months on day 27, ending after 4 times', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {'list_id': inbox, 'title': 'Water the plants', 'due_at': day(1), 'all_day': true}),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Water the plants');
    await openRepeat(tester);

    await tester.tap(find.byKey(const Key('repeat:custom')));
    await animate(tester);
    await tester.tap(find.descendant(of: find.byKey(const Key('customUnit')), matching: find.text('Month')));
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('customInterval:up')));
      await tester.pump();
    }
    // The dropdown menu opens scrolled to the task's own day (tomorrow, so it changes with the date), which made tapping
    // "day 27" depend on today's date. Choose the value the way the menu would, without the menu.
    tester.widget<DropdownButton<int>>(find.byKey(const Key('customMonthDay'))).onChanged!(27);
    await tester.pump();
    await tester.tap(find.byKey(const Key('customEndCount')));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('customCount:down')));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('customPreview'))).data, 'Every 3 months on day 27, 4 times');
    await tester.tap(find.byKey(const Key('customDone')));
    await animate(tester);

    // The new rule is listed, in words, and selected; Done writes it.
    expect(find.text('Every 3 months on day 27, 4 times'), findsOneWidget);
    await done(tester);
    final task = await onlyTask(tester);
    expect(task.rrule, 'RRULE:FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=27;COUNT=4');
    expect(task.version, 2);
    expect(
      find.descendant(of: find.byKey(const Key('taskRepeat')), matching: find.text('Every 3 months on day 27, 4 times')),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('Custom opens on the rule the task has, and leaving it unchanged writes nothing', (tester) async {
    await seedRepeating(tester, 'RRULE:FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=27');
    await openRepeat(tester);
    await tester.ensureVisible(find.byKey(const Key('repeat:custom')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('repeat:custom')));
    await animate(tester);
    expect(tester.widget<Text>(find.byKey(const Key('customInterval:value'))).data, '3');
    expect(tester.widget<Text>(find.byKey(const Key('customPreview'))).data, 'Every 3 months on day 27');
    await tester.tap(find.byKey(const Key('customDone')));
    await animate(tester);
    await done(tester);
    expect((await onlyTask(tester)).version, 1);
    await unmount(tester);
  });

  testWidgets('a weekly rule keeps at least one weekday, and an end date can be picked', (tester) async {
    await seedRepeating(tester, 'RRULE:FREQ=WEEKLY;BYDAY=MO');
    await openRepeat(tester);
    await tester.ensureVisible(find.byKey(const Key('repeat:custom')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('repeat:custom')));
    await animate(tester);
    await tester.tap(find.byKey(const Key('customWeekday1')));
    await tester.pump();
    expect(tester.widget<FilterChip>(find.byKey(const Key('customWeekday1'))).selected, true, reason: 'the last day stays');
    await tester.tap(find.byKey(const Key('customWeekday4')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('customPreview'))).data, 'Every week on Monday and Thursday');

    await tester.tap(find.byKey(const Key('customEndUntil')));
    await animate(tester);
    await tester.tap(find.text('OK'));
    await animate(tester);
    expect(tester.widget<Text>(find.byKey(const Key('customPreview'))).data, startsWith('Every week on Monday and Thursday, until '));
    await tester.tap(find.byKey(const Key('customDone')));
    await animate(tester);
    await done(tester);
    final rule = (await onlyTask(tester)).rrule!;
    expect(rule, matches(RegExp(r'^RRULE:FREQ=WEEKLY;BYDAY=MO,TH;UNTIL=\d{8}T235959Z$')));
    await unmount(tester);
  });

  testWidgets('Cancel in the custom editor changes nothing', (tester) async {
    await seedRepeating(tester, 'RRULE:FREQ=MONTHLY;INTERVAL=3;BYDAY=2TU');
    await openRepeat(tester);
    await tester.ensureVisible(find.byKey(const Key('repeat:custom')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('repeat:custom')));
    await animate(tester);
    await tester.tap(find.byKey(const Key('customCancel')));
    await animate(tester);
    await done(tester);
    final task = await onlyTask(tester);
    expect(task.rrule, 'RRULE:FREQ=MONTHLY;INTERVAL=3;BYDAY=2TU', reason: 'a rule the editor cannot show is kept as it is');
    expect(task.version, 1);
    await unmount(tester);
  });

  testWidgets('a task with no date cannot repeat yet', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'Water the plants'}));
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Water the plants');
    expect(tester.widget<ActionChip>(find.byKey(const Key('taskRepeat'))).onPressed, isNull);
    await unmount(tester);
  });

  testWidgets('completing a repeating task from its page creates the next one', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Water the plants',
        'due_at': day(0),
        'all_day': true,
        'rrule': 'RRULE:FREQ=DAILY',
      }),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Water the plants');

    await tester.tap(find.byKey(const Key('taskCompleteToggle')));
    await animate(tester);
    await settle(tester);

    final all = await tasks(tester);
    expect(all, hasLength(2));
    expect(all.where((t) => t.status == 2).single.dueAt, day(0));
    final next = all.singleWhere((t) => t.status == 0);
    expect(next.dueAt, day(1));
    expect(next.rrule, 'RRULE:FREQ=DAILY');
    await unmount(tester);
  });

  testWidgets('ticking a repeating task in the list creates the next one, which shows up in the list', (tester) async {
    final inbox = await seedInbox(tester);
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Water the plants',
        'due_at': day(0),
        'all_day': true,
        'rrule': 'RRULE:FREQ=DAILY',
      });
    });
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(Key('taskCheck-$id')));
    await animate(tester);
    await settle(tester);

    final all = await tasks(tester);
    expect(all, hasLength(2));
    expect(all.singleWhere((t) => t.id == id).status, 2);
    expect(all.singleWhere((t) => t.id != id).dueAt, day(1));
    // The list shows the finished one (ticked) and the new one.
    expect(find.text('Water the plants'), findsNWidgets(2));
    await unmount(tester);
  });
}
