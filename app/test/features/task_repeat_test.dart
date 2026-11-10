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
      find.descendant(of: find.byKey(const Key('taskRepeat')), matching: find.text('FREQ=MONTHLY;INTERVAL=3;BYDAY=2TU')),
      findsOneWidget,
    );
    await openRepeat(tester);
    expect(find.byKey(const Key('repeat:FREQ=MONTHLY;INTERVAL=3;BYDAY=2TU')), findsOneWidget);
    await tester.tap(find.byKey(const Key('repeatCancel')));
    await animate(tester);
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
