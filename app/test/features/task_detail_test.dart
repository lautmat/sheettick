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

import '../support/fake_auth_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftLocalStore store;
  LocalWriter writer() => LocalWriter(store, deviceId: 'win-test');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  /// Signed out: the tasks are on the device, and the screens work without Google.
  Widget app() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWith((ref) => 'win-test'),
        authServiceProvider.overrideWithValue(FakeAuthService()),
      ],
      child: const SheetTickApp(),
    );
  }

  /// Lets queued database work and stream emissions finish, in short real-time slices. Each slice also moves the
  /// fake clock on, so a page that was popped after its database write finishes its exit transition.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Runs a route, dialog or menu animation to its end. Fixed steps rather than pumpAndSettle, which never returns
  /// while a spinner is spinning.
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

  /// Opens the task titled [title] from the Inbox list.
  Future<void> openTask(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await animate(tester);
    await settle(tester);
  }

  /// Leaves the task page with the app bar's Back button, as the user does.
  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Back'));
    await animate(tester);
    await settle(tester);
  }

  testWidgets('tapping a task opens it: the title and notes are edited, and leaving saves them', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'draft', 'content': 'old'}));
    await tester.pumpWidget(app());
    await settle(tester);

    await openTask(tester, 'draft');
    await tester.enterText(find.byKey(const Key('taskTitleField')), 'final report');
    await tester.enterText(find.byKey(const Key('taskNotesField')), '# Summary\n- one');
    await goBack(tester);

    expect(find.text('final report'), findsOneWidget);
    final task = await onlyTask(tester);
    expect((task.title, task.content, task.version), ('final report', '# Summary\n- one', 2));
    expect(task.dirty, isTrue);
    await unmount(tester);
  });

  testWidgets('leaving without a change writes nothing, and a blank title is not saved', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'draft'}));
    await tester.pumpWidget(app());
    await settle(tester);

    await openTask(tester, 'draft');
    await goBack(tester);
    expect((await onlyTask(tester)).version, 1);

    await openTask(tester, 'draft');
    await tester.enterText(find.byKey(const Key('taskTitleField')), '   ');
    await goBack(tester);
    final task = await onlyTask(tester);
    expect((task.title, task.version), ('draft', 1));
    expect(find.text('draft'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('complete from the page sets status 2 and stamps completed_at; the same button reopens', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'draft'}));
    await tester.pumpWidget(app());
    await settle(tester);

    await openTask(tester, 'draft');
    await tester.tap(find.byKey(const Key('taskCompleteToggle')));
    await settle(tester);
    var task = await onlyTask(tester);
    expect(task.status, 2);
    expect(task.completedAt, isNotNull);
    expect(find.text('Completed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('taskCompleteToggle')));
    await settle(tester);
    task = await onlyTask(tester);
    expect(task.status, 0);
    expect(task.completedAt, isNull);
    await unmount(tester);
  });

  testWidgets('edits are saved before a status change, so nothing typed is lost', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'draft'}));
    await tester.pumpWidget(app());
    await settle(tester);

    await openTask(tester, 'draft');
    await tester.enterText(find.byKey(const Key('taskNotesField')), 'typed just before completing');
    await tester.tap(find.byKey(const Key('taskCompleteToggle')));
    await settle(tester);

    final task = await onlyTask(tester);
    expect((task.content, task.status), ('typed just before completing', 2));
    await unmount(tester);
  });

  testWidgets("won't do sets status -1, and the task leaves the list", (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'draft'}));
    await tester.pumpWidget(app());
    await settle(tester);

    await openTask(tester, 'draft');
    await tester.tap(find.byKey(const Key('taskMenu')));
    await animate(tester);
    await tester.tap(find.text("Won't do"));
    await animate(tester);
    await settle(tester);

    final task = await onlyTask(tester);
    expect(task.status, -1);
    expect(task.completedAt, isNull);
    expect(find.text("Won't do"), findsOneWidget);
    await goBack(tester);
    expect(find.text('draft'), findsNothing);
    await unmount(tester);
  });

  testWidgets('delete asks first; confirming tombstones the task and closes the page', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'draft'}));
    await tester.pumpWidget(app());
    await settle(tester);

    await openTask(tester, 'draft');
    await tester.tap(find.byKey(const Key('taskMenu')));
    await animate(tester);
    await tester.tap(find.text('Delete'));
    await animate(tester);
    expect(find.text('Move this task to Trash?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await animate(tester);
    expect((await onlyTask(tester)).deleted, isFalse);

    await tester.tap(find.byKey(const Key('taskMenu')));
    await animate(tester);
    await tester.tap(find.text('Delete'));
    await animate(tester);
    await tester.tap(find.text('Move to Trash'));
    await animate(tester);
    await settle(tester);

    // The row is kept as a tombstone, not removed; the page is closed and the list no longer shows it.
    final task = await onlyTask(tester);
    expect((task.deleted, task.version), (true, 2));
    expect(find.byKey(const Key('taskTitleField')), findsNothing);
    expect(find.text('draft'), findsNothing);
    await unmount(tester);
  });
}
