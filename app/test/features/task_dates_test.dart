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
import 'package:sheettick/features/tasks/date_labels.dart';

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

  /// Signed out, on a fixed device zone so the stored offsets do not depend on the machine running the tests.
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

  Future<Task> onlyTask(WidgetTester tester) async => (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;

  /// Today where the app shows it (the device zone), as the model's wall clock.
  DateTime today() => const TaskDates(zone: zone).wallOf(DateTime.now());

  /// `YYYY-MM-DD` of today plus [offset] days.
  String dayText(int offset) {
    final d = dayOf(today()).add(Duration(days: offset));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> openTask(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await animate(tester);
    await settle(tester);
  }

  Future<void> openDatesDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('taskDates')));
    await animate(tester);
  }

  /// Picks a day of the month the calendar opens on: the 15th, or the 14th when today is the 15th.
  Future<DateTime> pickDayInThisMonth(WidgetTester tester, Key button) async {
    final now = today();
    final day = now.day == 15 ? 14 : 15;
    await tester.tap(find.byKey(button));
    await animate(tester);
    await tester.tap(find.text('$day'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await animate(tester);
    return DateTime.utc(now.year, now.month, day);
  }

  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  testWidgets('a due day is picked in the dialog and stored as an all-day date with no zone', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent'}));
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pay rent');
    expect(find.descendant(of: find.byKey(const Key('taskDates')), matching: find.text('Add date')), findsOneWidget);

    await openDatesDialog(tester);
    final picked = await pickDayInThisMonth(tester, const Key('dueDateButton'));
    await tester.tap(find.byKey(const Key('datesDone')));
    await animate(tester);
    await settle(tester);

    final task = await onlyTask(tester);
    expect(task.dueAt, ymd(picked));
    expect(task.startAt, isNull);
    expect(task.allDay, isTrue);
    expect(task.tz, isNull);
    expect(task.version, 2);
    await unmount(tester);
  });

  testWidgets('a timed due is stored with the offset and the device zone', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'Call the bank'}));
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Call the bank');

    await openDatesDialog(tester);
    await tester.tap(find.byKey(const Key('allDaySwitch')));
    await tester.pump();
    final picked = await pickDayInThisMonth(tester, const Key('dueDateButton'));
    // A new time is 09:00, shown on its own button.
    expect(find.byKey(const Key('dueTimeButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('datesDone')));
    await animate(tester);
    await settle(tester);

    final task = await onlyTask(tester);
    expect(task.allDay, isFalse);
    expect(task.tz, zone);
    expect(task.dueAt, matches(RegExp('^${ymd(picked)}T09:00:00\\+0[12]:00\$')));
    // Reading it back on the same zone gives the 09:00 that was set.
    expect(task.dates(zone).due, DateTime.utc(picked.year, picked.month, picked.day, 9));
    await unmount(tester);
  });

  testWidgets('Clear empties the four columns', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Pay rent',
        'start_at': dayText(0),
        'due_at': dayText(2),
        'all_day': true,
      }),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pay rent');

    await openDatesDialog(tester);
    await tester.tap(find.byKey(const Key('datesClear')));
    await animate(tester);
    await settle(tester);

    final task = await onlyTask(tester);
    expect(task.startAt, isNull);
    expect(task.dueAt, isNull);
    expect(task.allDay, isFalse);
    expect(task.tz, isNull);
    expect(task.version, 2);
    expect(find.descendant(of: find.byKey(const Key('taskDates')), matching: find.text('Add date')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Done with nothing changed, and Cancel, write nothing', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent', 'due_at': dayText(2), 'all_day': true}),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pay rent');

    await openDatesDialog(tester);
    await tester.tap(find.byKey(const Key('datesDone')));
    await animate(tester);
    await settle(tester);
    expect((await onlyTask(tester)).version, 1);

    await openDatesDialog(tester);
    await tester.tap(find.byKey(const Key('dueClear')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('datesCancel')));
    await animate(tester);
    await settle(tester);
    final task = await onlyTask(tester);
    expect(task.version, 1);
    expect(task.dueAt, dayText(2));
    await unmount(tester);
  });

  testWidgets('a timed value set in another zone is shown on the device zone and left alone until edited', (tester) async {
    final inbox = await seedInbox(tester);
    // 09:00 in New York in January is 15:00 in Paris.
    await tester.runAsync(
      () => writer().insert('tasks', {
        'list_id': inbox,
        'title': 'Standup',
        'due_at': '2027-01-15T09:00:00-05:00',
        'tz': 'America/New_York',
        'all_day': false,
      }),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Standup');

    expect(find.descendant(of: find.byKey(const Key('taskDates')), matching: find.textContaining('3:00 PM')), findsOneWidget);
    await openDatesDialog(tester);
    await tester.tap(find.byKey(const Key('datesDone')));
    await animate(tester);
    await settle(tester);
    final task = await onlyTask(tester);
    expect(task.version, 1);
    expect(task.dueAt, '2027-01-15T09:00:00-05:00');
    expect(task.tz, 'America/New_York');
    await unmount(tester);
  });

  testWidgets('list rows show Today, Yesterday and Starts, and a past due is red only while the task is open', (tester) async {
    final inbox = await seedInbox(tester);
    late String doneId;
    await tester.runAsync(() async {
      await writer().insert('tasks', {'list_id': inbox, 'title': 'A today', 'due_at': dayText(0), 'all_day': true, 'sort_order': 1});
      await writer().insert('tasks', {'list_id': inbox, 'title': 'B late', 'due_at': dayText(-1), 'all_day': true, 'sort_order': 2});
      await writer().insert('tasks', {'list_id': inbox, 'title': 'C later', 'start_at': dayText(1), 'all_day': true, 'sort_order': 3});
      doneId = await writer().insert('tasks', {
        'list_id': inbox,
        'title': 'D done',
        'due_at': dayText(-1),
        'all_day': true,
        'status': 2,
        'sort_order': 4,
      });
      await writer().insert('tasks', {'list_id': inbox, 'title': 'E none', 'sort_order': 5});
    });
    await tester.pumpWidget(app());
    await settle(tester);

    Text due(String title) {
      final tile = find.ancestor(of: find.text(title), matching: find.byType(ListTile)).first;
      return tester.widget<Text>(find.descendant(of: tile, matching: find.byWidgetPredicate((w) => w is Text && (w.key as ValueKey?)?.value.toString().startsWith('taskDue-') == true)));
    }

    final error = Theme.of(tester.element(find.text('A today'))).colorScheme.error;
    expect(due('A today').data, 'Today');
    expect(due('A today').style?.color, isNot(error));
    expect(due('B late').data, 'Yesterday');
    expect(due('B late').style?.color, error);
    expect(due('C later').data, 'Starts Tomorrow');
    expect(due('C later').style?.color, isNot(error));
    expect(due('D done').data, 'Yesterday');
    expect(due('D done').style?.color, isNot(error));
    expect(find.byKey(Key('taskDue-$doneId')), findsOneWidget);
    // A task with no dates has no due line.
    final none = find.ancestor(of: find.text('E none'), matching: find.byType(ListTile)).first;
    expect(find.descendant(of: none, matching: find.textContaining('Today')), findsNothing);
    await unmount(tester);
  });

  testWidgets('a due time shows beside the day in a list row', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() async {
      // 14:30 on the day after tomorrow, written the way the app writes it, in the device zone.
      final fields = TaskDates(
        due: dayOf(today()).add(const Duration(days: 2, hours: 14, minutes: 30)),
        zone: zone,
      ).toFields();
      await writer().insert('tasks', {'list_id': inbox, 'title': 'Dentist', ...fields});
    });
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.textContaining('2:30 PM'), findsOneWidget);
    await unmount(tester);
  });
}
