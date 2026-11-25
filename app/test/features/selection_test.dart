import 'dart:ui' show PointerDeviceKind;

import 'package:drift/drift.dart' as drift show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
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
import 'package:sheettick/features/tasks/selection_bar.dart' show BulkAction;

import '../support/fake_auth_service.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const zone = 'Europe/Paris';

  late AppDatabase db;
  late DriftLocalStore store;
  late String inbox;
  LocalWriter writer() => LocalWriter(store, deviceId: 'win-test');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    inbox = '';
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

  /// A phone: 400 by 800 logical pixels, so the sidebar is a drawer. (`setSurfaceSize` would not do: it leaves the
  /// `MediaQuery` at the default 800 pixels wide, and the sidebar stays.)
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  String day(int offset) {
    final d = dayOf(const TaskDates(zone: zone).wallOf(DateTime.now())).add(Duration(days: offset));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<String> seedList(WidgetTester tester, String name, {bool isInbox = false}) async {
    late String id;
    await tester.runAsync(() async => id = await writer().insert('lists', {'name': name, 'is_inbox': isInbox}));
    return id;
  }

  Future<String> seedTask(WidgetTester tester, String title, [Map<String, Object?> fields = const {}]) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('tasks', {'list_id': inbox, 'title': title, ...fields});
    });
    return id;
  }

  Future<Task> row(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle()))!;

  Future<void> boot(WidgetTester tester) async {
    inbox = await seedList(tester, 'Inbox', isInbox: true);
  }

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
  }

  /// Holds a finger on the task and lifts it without moving: picks the task.
  Future<void> holdAndLift(WidgetTester tester, String id, {PointerDeviceKind kind = PointerDeviceKind.touch}) async {
    final g = await tester.startGesture(tester.getCenter(find.byKey(ValueKey(id))), kind: kind);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.up();
    await settle(tester);
  }

  Future<void> tapTask(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey(id)));
    await settle(tester);
  }

  Future<void> tapBar(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  /// A choice in the bar's "More" menu.
  Future<void> more(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('bulkMore')));
    await animate(tester);
    await tester.tap(find.widgetWithText(PopupMenuItem<BulkAction>, label));
    await animate(tester);
    await settle(tester);
  }

  /// The title of the selection bar, when it says [text].
  Finder count(String text) =>
      find.byWidgetPredicate((w) => w is Text && w.key == const Key('selectionCount') && w.data == text);

  group('picking tasks, on a phone', () {
    testWidgets('holding a finger on a task and lifting it starts a selection; taps add and drop tasks', (tester) async {
      phone(tester);
      await boot(tester);
      final a = await seedTask(tester, 'A');
      final b = await seedTask(tester, 'B');
      final c = await seedTask(tester, 'C');
      await start(tester);
      expect(find.byKey(const Key('selectionCount')), findsNothing);
      expect(find.byKey(const Key('addTaskField')), findsOneWidget);

      await holdAndLift(tester, b);
      expect(count('1 selected'), findsOneWidget);
      expect(find.byKey(Key('taskPick-$b')), findsOneWidget);
      expect(find.byKey(const Key('bulkToday')), findsOneWidget, reason: 'the bar with the actions');
      expect(find.byKey(const Key('addTaskField')), findsNothing, reason: 'the add bar gives way to it');
      expect(find.byKey(Key('taskCheck-$a')), findsNothing, reason: 'the check boxes give way to the ticks');
      expect(find.text('No section'), findsNothing, reason: 'a hold that did not move is not a drag');
      expect((await row(tester, b)).version, 1, reason: 'picking writes nothing');

      await tapTask(tester, c);
      expect(count('2 selected'), findsOneWidget);
      expect(find.text('Task options'), findsNothing);

      await tapTask(tester, b);
      expect(count('1 selected'), findsOneWidget);

      await tapTask(tester, c);
      expect(find.byKey(const Key('selectionCount')), findsNothing, reason: 'dropping the last task ends it');
      expect(find.byKey(const Key('addTaskField')), findsOneWidget);
      expect(find.byKey(Key('taskCheck-$a')), findsOneWidget);

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a tap in a selection does not open the task, and without one it still does', (tester) async {
      phone(tester);
      await boot(tester);
      final a = await seedTask(tester, 'A');
      final b = await seedTask(tester, 'B');
      await start(tester);

      await holdAndLift(tester, a);
      await tapTask(tester, b);
      expect(find.byKey(const Key('taskTitleField')), findsNothing, reason: 'still on the list');

      await tapBar(tester, 'selectionClose');
      await tapTask(tester, b);
      expect(find.byKey(const Key('taskTitleField')), findsOneWidget, reason: 'with no selection a tap opens the task');

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Select all, the close button and the back button', (tester) async {
      phone(tester);
      await boot(tester);
      final a = await seedTask(tester, 'A');
      await seedTask(tester, 'B');
      await seedTask(tester, 'C');
      await start(tester);

      await holdAndLift(tester, a);
      await tapBar(tester, 'selectAll');
      expect(count('3 selected'), findsOneWidget);
      expect(tester.widget<IconButton>(find.byKey(const Key('selectAll'))).onPressed, isNull, reason: 'all are picked');

      await tapBar(tester, 'selectionClose');
      expect(find.byKey(const Key('selectionCount')), findsNothing);

      await holdAndLift(tester, a);
      expect(count('1 selected'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byKey(const Key('selectionCount')), findsNothing, reason: 'back ends the selection first');
      expect(find.byKey(Key('taskCheck-$a')), findsOneWidget, reason: 'and the app is still there');

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Select all leaves out the tasks of a folded section', (tester) async {
      phone(tester);
      await boot(tester);
      late String home;
      await tester.runAsync(
        () async => home = await writer().insert('sections', {'list_id': inbox, 'name': 'Home', 'collapsed': true}),
      );
      final a = await seedTask(tester, 'A');
      await seedTask(tester, 'Hidden', {'section_id': home});
      await start(tester);

      await holdAndLift(tester, a);
      await tapBar(tester, 'selectAll');

      expect(count('1 selected'), findsOneWidget, reason: 'the folded task cannot be seen, so it is not picked');

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a subtask can be picked, and so can a task in the Today smart list', (tester) async {
      phone(tester);
      await boot(tester);
      final parent = await seedTask(tester, 'Parent', {'due_at': day(0), 'all_day': true});
      final child = await seedTask(tester, 'Child', {'parent_id': parent});
      await start(tester);

      await holdAndLift(tester, child);
      expect(count('1 selected'), findsOneWidget);
      await tapBar(tester, 'selectionClose');

      await tester.tap(find.byTooltip('Open navigation menu'));
      await animate(tester);
      await tester.tap(find.byKey(const Key('smart-today')));
      await settle(tester);
      await holdAndLift(tester, parent);
      expect(count('1 selected'), findsOneWidget);

      // The selection bar has no menu button; an edge swipe opens the drawer, as on the phone.
      expect(find.byTooltip('Open navigation menu'), findsNothing);
      tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await animate(tester);
      await tester.tap(find.byKey(const Key('smart-all')));
      await settle(tester);
      expect(find.byKey(const Key('selectionCount')), findsNothing, reason: 'another list drops the selection');

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a task\'s menu has Select, and with a mouse a long press picks', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await boot(tester);
      final a = await seedTask(tester, 'A', {'due_at': day(-1), 'all_day': true});
      final b = await seedTask(tester, 'B');
      await start(tester);

      await tester.tap(find.byKey(Key('taskMenu-$a')));
      await animate(tester);
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Select'));
      await animate(tester);
      await settle(tester);
      expect(count('1 selected'), findsOneWidget);
      await tapBar(tester, 'selectionClose');

      await holdAndLift(tester, b, kind: PointerDeviceKind.mouse);
      expect(count('1 selected'), findsOneWidget);

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  group('acting on the picked tasks', () {
    testWidgets('Today puts every picked task on today, in one write, and Undo puts the dates back', (tester) async {
      phone(tester);
      await boot(tester);
      final late = await seedTask(tester, 'Late', {'due_at': day(-3), 'all_day': true});
      final later = await seedTask(tester, 'Later', {'due_at': day(5), 'all_day': true});
      final undated = await seedTask(tester, 'Undated');
      final left = await seedTask(tester, 'Left alone', {'due_at': day(2), 'all_day': true});
      await start(tester);

      await holdAndLift(tester, late);
      await tapTask(tester, later);
      await tapTask(tester, undated);
      expect(count('3 selected'), findsOneWidget);
      await tapBar(tester, 'bulkToday');

      expect((await row(tester, late)).dueAt, day(0));
      expect((await row(tester, later)).dueAt, day(0));
      expect((await row(tester, undated)).dueAt, day(0));
      expect((await row(tester, undated)).allDay, isTrue);
      expect((await row(tester, left)).dueAt, day(2));
      expect((await row(tester, left)).version, 1);
      expect(find.text('3 tasks postponed'), findsOneWidget);
      expect(find.byKey(const Key('selectionCount')), findsNothing, reason: 'the selection is over');

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect((await row(tester, late)).dueAt, day(-3));
      expect((await row(tester, later)).dueAt, day(5));
      expect((await row(tester, undated)).dueAt, isNull);

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Tomorrow moves them to tomorrow, and counts only the tasks that changed', (tester) async {
      phone(tester);
      await boot(tester);
      final a = await seedTask(tester, 'A', {'due_at': day(0), 'all_day': true});
      final already = await seedTask(tester, 'Already', {'due_at': day(1), 'all_day': true});
      await start(tester);

      await holdAndLift(tester, a);
      await tapTask(tester, already);
      await tapBar(tester, 'bulkTomorrow');

      expect((await row(tester, a)).dueAt, day(1));
      expect((await row(tester, already)).version, 1, reason: 'it was due tomorrow: not rewritten');
      expect(find.text('Task postponed'), findsOneWidget, reason: 'one task changed, so one is counted');

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a move that changes nothing says so and keeps the selection', (tester) async {
      phone(tester);
      await boot(tester);
      final a = await seedTask(tester, 'A', {'due_at': day(0), 'all_day': true});
      await start(tester);

      await holdAndLift(tester, a);
      await tapBar(tester, 'bulkToday');

      expect(find.textContaining('Nothing to change'), findsOneWidget);
      expect(count('1 selected'), findsOneWidget, reason: 'the user can pick another action');
      expect((await row(tester, a)).version, 1);

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('More offers Next week and No date', (tester) async {
      phone(tester);
      await boot(tester);
      final a = await seedTask(tester, 'A', {'due_at': day(0), 'all_day': true});
      final b = await seedTask(tester, 'B', {'due_at': day(1), 'all_day': true});
      await start(tester);

      await holdAndLift(tester, a);
      await more(tester, 'Next week');
      expect((await row(tester, a)).dueAt, isNot(day(0)));
      expect(DateTime.parse((await row(tester, a)).dueAt!).weekday, DateTime.monday);

      await holdAndLift(tester, b);
      await more(tester, 'No date');
      expect((await row(tester, b)).dueAt, isNull);
      expect(find.text('Date removed'), findsOneWidget);

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Complete finishes the open ones, carries a repeating one on, and Undo reopens them', (tester) async {
      phone(tester);
      await boot(tester);
      final a = await seedTask(tester, 'A');
      final weekly = await seedTask(tester, 'Weekly', {
        'due_at': day(0),
        'all_day': true,
        'rrule': 'RRULE:FREQ=WEEKLY',
      });
      await start(tester);

      await holdAndLift(tester, a);
      await tapTask(tester, weekly);
      await tapBar(tester, 'bulkComplete');

      expect((await row(tester, a)).status, 2);
      expect((await row(tester, weekly)).status, 2);
      final all = await tester.runAsync(() => db.select(db.tasks).get());
      expect(all!.where((t) => t.title == 'Weekly' && t.status == 0), hasLength(1), reason: 'the next round was made');
      expect(find.text('2 tasks completed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect((await row(tester, a)).status, 0);
      expect((await row(tester, weekly)).status, 0);
      final after = await tester.runAsync(() => db.select(db.tasks).get());
      expect(after!.where((t) => t.title == 'Weekly' && !t.deleted), hasLength(1), reason: 'the next round is gone again');

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Move asks for a list and sends every picked task and its subtasks there', (tester) async {
      phone(tester);
      await boot(tester);
      final work = await seedList(tester, 'Work');
      final a = await seedTask(tester, 'A');
      final sub = await seedTask(tester, 'Sub of A', {'parent_id': a});
      final b = await seedTask(tester, 'B');
      final keep = await seedTask(tester, 'Keep');
      await start(tester);

      await holdAndLift(tester, a);
      await tapTask(tester, b);
      await tapBar(tester, 'bulkMove');
      await animate(tester);
      expect(find.byKey(Key('moveTo-$inbox')), findsNothing, reason: 'they are all in the Inbox already');
      await tester.tap(find.byKey(Key('moveTo-$work')));
      await settle(tester);

      expect((await row(tester, a)).listId, work);
      expect((await row(tester, sub)).listId, work);
      expect((await row(tester, b)).listId, work);
      expect((await row(tester, keep)).listId, inbox);
      expect(find.text('2 tasks moved to Work'), findsOneWidget);
      expect(find.byKey(const Key('selectionCount')), findsNothing);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect((await row(tester, a)).listId, inbox);
      expect((await row(tester, sub)).listId, inbox);
      expect((await row(tester, b)).listId, inbox);

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('cancelling the list question keeps the selection', (tester) async {
      phone(tester);
      await boot(tester);
      await seedList(tester, 'Work');
      final a = await seedTask(tester, 'A');
      await start(tester);

      await holdAndLift(tester, a);
      await tapBar(tester, 'bulkMove');
      await animate(tester);
      await tester.tapAt(const Offset(5, 5));
      await animate(tester);

      expect(count('1 selected'), findsOneWidget);
      expect((await row(tester, a)).listId, inbox);

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('More sets a priority on every picked task, and Undo puts it back', (tester) async {
      phone(tester);
      await boot(tester);
      final a = await seedTask(tester, 'A', {'priority': 1});
      final b = await seedTask(tester, 'B');
      final high = await seedTask(tester, 'Already high', {'priority': 5});
      await start(tester);

      await holdAndLift(tester, a);
      await tapTask(tester, b);
      await tapTask(tester, high);
      await more(tester, 'High');

      expect((await row(tester, a)).priority, 5);
      expect((await row(tester, b)).priority, 5);
      expect((await row(tester, high)).version, 1, reason: 'already high: not rewritten');
      expect(find.text('Priority changed on 2 tasks'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect((await row(tester, a)).priority, 1);
      expect((await row(tester, b)).priority, 0);

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Move to Trash asks first, takes the subtasks along, and Undo brings them back', (tester) async {
      phone(tester);
      await boot(tester);
      final a = await seedTask(tester, 'A');
      final sub = await seedTask(tester, 'Sub of A', {'parent_id': a});
      final b = await seedTask(tester, 'B');
      final keep = await seedTask(tester, 'Keep');
      await start(tester);

      await holdAndLift(tester, a);
      await tapTask(tester, b);
      await more(tester, 'Move to Trash');
      expect(find.text('Move 2 tasks to Trash?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect((await row(tester, a)).deleted, isFalse);
      expect(count('2 selected'), findsOneWidget, reason: 'cancelling keeps the selection');

      await tester.tap(find.byKey(const Key('bulkMore')));
      await animate(tester);
      await tester.tap(find.widgetWithText(PopupMenuItem<BulkAction>, 'Move to Trash'));
      await animate(tester);
      await tester.tap(find.byKey(const Key('confirmTrash')));
      await settle(tester);

      expect((await row(tester, a)).deleted, isTrue);
      expect((await row(tester, sub)).deleted, isTrue);
      expect((await row(tester, b)).deleted, isTrue);
      expect((await row(tester, keep)).deleted, isFalse);
      expect(find.text('2 tasks moved to Trash'), findsOneWidget);
      expect(find.byKey(const Key('selectionCount')), findsNothing);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect((await row(tester, a)).deleted, isFalse);
      expect((await row(tester, sub)).deleted, isFalse);
      expect((await row(tester, b)).deleted, isFalse);

      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
