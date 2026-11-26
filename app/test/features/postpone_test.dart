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
import 'package:sheettick/core/tasks/task_postpone.dart';

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

  String day(int offset) {
    final d = dayOf(const TaskDates(zone: zone).wallOf(DateTime.now())).add(Duration(days: offset));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>> seed(WidgetTester tester, Map<String, Map<String, Object?>> tasks) async {
    final ids = <String, String>{};
    await tester.runAsync(() async {
      final inbox = await writer().insert('lists', {'name': 'Inbox', 'is_inbox': true});
      for (final e in tasks.entries) {
        ids[e.key] = await writer().insert('tasks', {'list_id': inbox, 'title': e.key, ...e.value});
      }
    });
    return ids;
  }

  Future<Task> row(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle()))!;

  /// A choice in an open task menu. The sidebar has entries with the same words (Today, Tomorrow), so look inside the menu.
  Finder choice(String label) => find.widgetWithText(PopupMenuItem<String>, label);

  Future<void> openToday(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('smart-today')));
    await settle(tester);
  }

  testWidgets('a task\'s menu postpones it to Tomorrow in one step, and Undo brings the date back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester, {
      'Water the plants': {
        'due_at': day(-2),
        'all_day': true,
        'rrule': 'RRULE:FREQ=WEEKLY',
        'reminders': '["TRIGGER:PT9H"]',
      },
    });
    await tester.pumpWidget(app());
    await settle(tester);
    await openToday(tester);

    await tester.tap(find.byKey(Key('taskMenu-${ids['Water the plants']}')));
    await animate(tester);
    expect(find.text('Postpone to'), findsOneWidget);
    await tester.tap(choice('Tomorrow'));
    await animate(tester);
    await settle(tester);

    var task = await row(tester, ids['Water the plants']!);
    expect(task.dueAt, day(1));
    expect(task.rrule, 'RRULE:FREQ=WEEKLY');
    expect(task.reminders, '["TRIGGER:PT9H"]');
    expect(find.text('Task postponed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    task = await row(tester, ids['Water the plants']!);
    expect(task.dueAt, day(-2));
    await unmount(tester);
  });

  testWidgets('the menu only offers what would change something', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester, {'Due today': {'due_at': day(0), 'all_day': true}});
    await tester.pumpWidget(app());
    await settle(tester);
    await openToday(tester);
    await tester.tap(find.byKey(Key('taskMenu-${ids['Due today']}')));
    await animate(tester);
    expect(choice('Today'), findsNothing, reason: 'it is already due today');
    expect(choice('Tomorrow'), findsOneWidget);
    expect(choice('Next week'), findsOneWidget);
    expect(choice('No date'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('No date clears the dates, and the task leaves Today', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester, {'Due today': {'due_at': day(0), 'all_day': true}});
    await tester.pumpWidget(app());
    await settle(tester);
    await openToday(tester);
    await tester.tap(find.byKey(Key('taskMenu-${ids['Due today']}')));
    await animate(tester);
    await tester.tap(choice('No date'));
    await animate(tester);
    await settle(tester);
    expect((await row(tester, ids['Due today']!)).dueAt, isNull);
    expect(find.text('Date removed'), findsOneWidget);
    expect(find.byKey(Key('taskMenu-${ids['Due today']}')), findsNothing, reason: 'it left Today');
    await unmount(tester);
  });

  testWidgets('Postpone all overdue moves every overdue task in one write, and one Undo puts them back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester, {
      'Late one': {'due_at': day(-3), 'all_day': true},
      'Late two': {'due_at': day(-1), 'all_day': true},
      'Due today': {'due_at': day(0), 'all_day': true},
    });
    await tester.pumpWidget(app());
    await settle(tester);
    await openToday(tester);

    expect(find.text('2 overdue'), findsOneWidget);
    await tester.tap(find.byKey(const Key('postponeOverdue')));
    await animate(tester);
    await tester.tap(find.widgetWithText(PopupMenuItem<PostponeTarget>, 'Tomorrow'));
    await animate(tester);
    await settle(tester);

    expect((await row(tester, ids['Late one']!)).dueAt, day(1));
    expect((await row(tester, ids['Late two']!)).dueAt, day(1));
    final untouched = await row(tester, ids['Due today']!);
    expect(untouched.dueAt, day(0));
    expect(untouched.version, 1);
    expect(find.text('2 tasks postponed'), findsOneWidget);
    expect(find.byKey(const Key('overdueBar')), findsNothing);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await row(tester, ids['Late one']!)).dueAt, day(-3));
    expect((await row(tester, ids['Late two']!)).dueAt, day(-1));
    expect(find.text('2 overdue'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no overdue bar when nothing is overdue, and it is only in Today', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seed(tester, {'Due today': {'due_at': day(0), 'all_day': true}, 'Late': {'due_at': day(-5), 'all_day': true}});
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byKey(const Key('smart-all')));
    await settle(tester);
    expect(find.byKey(const Key('overdueBar')), findsNothing);
    await openToday(tester);
    expect(find.byKey(const Key('overdueBar')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the task page menu postpones too', (tester) async {
    final ids = await seed(tester, {'Pay Visa card': {'due_at': day(-1), 'all_day': true}});
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('Pay Visa card'));
    await animate(tester);
    await settle(tester);
    await tester.tap(find.byKey(const Key('taskMenu')));
    await animate(tester);
    await tester.tap(choice('Today'));
    await animate(tester);
    await settle(tester);
    expect((await row(tester, ids['Pay Visa card']!)).dueAt, day(0));
    expect(find.text('Task postponed'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a done task has nothing to postpone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester, {'Finished': {'due_at': day(-1), 'all_day': true, 'status': 2}});
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byKey(const Key('smart-completed')));
    await settle(tester);
    // It still has a menu (Duplicate), with nothing to postpone it to.
    await tester.tap(find.byKey(Key('taskMenu-${ids['Finished']}')));
    await animate(tester);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Postpone to'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await animate(tester);
    await unmount(tester);
  });
}
