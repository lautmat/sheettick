import 'package:drift/drift.dart' as drift show driftRuntimeOptions;
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

  Future<void> swipe(WidgetTester tester, String id, {required bool right}) async {
    // A task in the folded-away Completed section has its own key.
    final row = find.byKey(ValueKey(id)).evaluate().isNotEmpty ? find.byKey(ValueKey(id)) : find.byKey(ValueKey('completed/$id'));
    await tester.fling(row, Offset(right ? 300 : -300, 0), 1500);
    await settle(tester);
  }

  Future<void> choose(WidgetTester tester, String key) async {
    await animate(tester);
    await tester.tap(find.byKey(Key(key)));
    await animate(tester);
    await settle(tester);
  }

  testWidgets('swiping right completes the task and Undo reopens it', (tester) async {
    phone(tester);
    await boot(tester);
    final a = await seedTask(tester, 'A');
    final b = await seedTask(tester, 'B');
    await start(tester);

    await swipe(tester, a, right: true);

    expect((await row(tester, a)).status, 2);
    expect((await row(tester, b)).status, 0);
    expect(find.text('Task completed'), findsOneWidget);
    expect(find.byKey(const Key('taskTitleField')), findsNothing, reason: 'a swipe does not open the task');
    expect(find.byKey(const Key('completedHeader')), findsOneWidget, reason: 'it went to the Completed section');

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await row(tester, a)).status, 0);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('swiping right on a done task reopens it, and it has no left swipe', (tester) async {
    phone(tester);
    await boot(tester);
    final a = await seedTask(tester, 'A', {'status': 2});
    await start(tester);

    await swipe(tester, a, right: false);
    expect(find.byKey(const Key('swipe-trash')), findsNothing, reason: 'nothing to offer for a done task');

    await swipe(tester, a, right: true);
    expect((await row(tester, a)).status, 0);
    expect(find.text('Task reopened'), findsOneWidget);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('swiping left offers the dates that would change something, Move and Trash', (tester) async {
    phone(tester);
    await boot(tester);
    final a = await seedTask(tester, 'A', {'due_at': day(0), 'all_day': true});
    await start(tester);

    await swipe(tester, a, right: false);
    await animate(tester);
    expect(find.byKey(const Key('swipe-today')), findsNothing, reason: 'it is due today already');
    expect(find.byKey(const Key('swipe-tomorrow')), findsOneWidget);
    expect(find.byKey(const Key('swipe-nextWeek')), findsOneWidget);
    expect(find.byKey(const Key('swipe-noDate')), findsOneWidget);
    expect(find.byKey(const Key('swipe-move')), findsOneWidget);
    expect(find.byKey(const Key('swipe-trash')), findsOneWidget);

    await tester.tap(find.byKey(const Key('swipe-tomorrow')));
    await animate(tester);
    await settle(tester);
    expect((await row(tester, a)).dueAt, day(1));
    expect(find.text('Task postponed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await row(tester, a)).dueAt, day(0));
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a left swipe can move the task to another list or to the Trash', (tester) async {
    phone(tester);
    await boot(tester);
    final work = await seedList(tester, 'Work');
    final a = await seedTask(tester, 'A');
    final b = await seedTask(tester, 'B');
    await start(tester);

    await swipe(tester, a, right: false);
    await choose(tester, 'swipe-move');
    await tester.tap(find.byKey(Key('moveTo-$work')));
    await settle(tester);
    expect((await row(tester, a)).listId, work);

    await swipe(tester, b, right: false);
    await choose(tester, 'swipe-trash');
    await tester.tap(find.byKey(const Key('confirmTrash')));
    await settle(tester);
    expect((await row(tester, b)).deleted, isTrue);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('no swipe while tasks are picked', (tester) async {
    phone(tester);
    await boot(tester);
    final a = await seedTask(tester, 'A');
    final b = await seedTask(tester, 'B');
    await start(tester);

    final g = await tester.startGesture(tester.getCenter(find.byKey(ValueKey(a))));
    await tester.pump(const Duration(milliseconds: 600));
    await g.up();
    await settle(tester);
    expect(find.byKey(const Key('selectionCount')), findsOneWidget);
    await swipe(tester, b, right: true);
    expect((await row(tester, b)).status, 0, reason: 'a swipe does not complete a task during a selection');
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('with a mouse the rows do not swipe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await boot(tester);
    await seedTask(tester, 'A');
    await start(tester);
    expect(find.byType(Dismissible), findsNothing);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
