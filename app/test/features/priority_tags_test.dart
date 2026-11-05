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

  Future<List<Tag>> tagRows(WidgetTester tester) async => (await tester.runAsync(() => db.select(db.tags).get()))!;

  testWidgets('priority is picked from its menu and written at once as the TickTick value', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent'}));
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pay rent');

    await tester.tap(find.byKey(const Key('taskPriority')));
    await animate(tester);
    await tester.tap(find.byKey(const Key('priority-high')));
    await animate(tester);
    await settle(tester);

    final task = await onlyTask(tester);
    expect(task.priority, 5);
    expect(task.version, 2);
    expect(find.descendant(of: find.byKey(const Key('taskPriority')), matching: find.text('High')), findsOneWidget);

    await tester.tap(find.byKey(const Key('taskPriority')));
    await animate(tester);
    await tester.tap(find.byKey(const Key('priority-none')));
    await animate(tester);
    await settle(tester);
    expect((await onlyTask(tester)).priority, 0);
    await unmount(tester);
  });

  testWidgets('a tag typed and entered is added as a chip, stored on the task and in the tags tab', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent'}));
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pay rent');

    await tester.enterText(find.byKey(const Key('addTagField')), '#home');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await tester.enterText(find.byKey(const Key('addTagField')), 'money');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect((await onlyTask(tester)).tags, 'home,money');
    expect((await tagRows(tester)).map((t) => t.name), ['home', 'money']);
    expect(find.byKey(const Key('tag-home')), findsOneWidget);
    expect(find.byKey(const Key('tag-money')), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('addTagField')));
    expect(field.controller!.text, isEmpty);
    await unmount(tester);
  });

  testWidgets('typing offers the tags already in use; picking one adds it with its spelling', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() async {
      await writer().insert('tags', {'name': 'Errands', 'sort_order': 1.0});
      await writer().insert('tags', {'name': 'Work', 'sort_order': 2.0});
      await writer().insert('tasks', {'list_id': inbox, 'title': 'Buy stamps'});
    });
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Buy stamps');

    await tester.enterText(find.byKey(const Key('addTagField')), 'err');
    await tester.pump();
    expect(find.byKey(const Key('tagOption-Errands')), findsOneWidget);
    expect(find.byKey(const Key('tagOption-Work')), findsNothing);
    await tester.tap(find.byKey(const Key('tagOption-Errands')));
    await settle(tester);

    expect((await onlyTask(tester)).tags, 'Errands');
    expect((await tagRows(tester)).length, 2);

    // A tag the task already has is not offered again.
    await tester.enterText(find.byKey(const Key('addTagField')), 'r');
    await tester.pump();
    expect(find.byKey(const Key('tagOption-Errands')), findsNothing);
    expect(find.byKey(const Key('tagOption-Work')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("a chip's delete button takes the tag off the task", (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(
      () => writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent', 'tags': 'home,money'}),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pay rent');

    await tester.tap(find.descendant(of: find.byKey(const Key('tag-home')), matching: find.byTooltip('Remove tag')));
    await settle(tester);

    expect((await onlyTask(tester)).tags, 'money');
    expect(find.byKey(const Key('tag-home')), findsNothing);
    await unmount(tester);
  });

  testWidgets('the list shows a task\'s tags under its title and its priority on its box', (tester) async {
    final inbox = await seedInbox(tester);
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('tasks', {'list_id': inbox, 'title': 'Pay rent', 'tags': 'home,money', 'priority': 5});
    });
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('#home  #money'), findsOneWidget);
    final box = tester.widget<Checkbox>(find.byKey(Key('taskCheck-$id')));
    expect(box.side?.color, Colors.red.shade600);
    await unmount(tester);
  });
}
