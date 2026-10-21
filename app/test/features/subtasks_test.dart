import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Signed out: the lists and tasks are on the device, and the screen works without Google.
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

  /// Lets queued database work and stream emissions finish. Each slice also moves the fake clock on, so a menu or
  /// route that closes after a write finishes its transition.
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

  /// A task in the Inbox. [order] keeps the rows in a known order, since tasks created in the same second tie.
  Future<String> addTask(WidgetTester tester, String list, String title, double order, {String? section}) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('tasks', {
        'list_id': list,
        'title': title,
        'sort_order': order,
        'section_id': ?section,
      });
    });
    return id;
  }

  Future<Task> taskTitled(WidgetTester tester, String title) async =>
      (await tester.runAsync(() => (db.select(db.tasks)..where((t) => t.title.equals(title))).getSingle()))!;

  /// Opens the options menu of the task [id] and picks [item].
  Future<void> pickMenu(WidgetTester tester, String id, String item) async {
    await tester.tap(find.byKey(Key('taskMenu-$id')));
    await animate(tester);
    await tester.tap(find.text(item));
    await animate(tester);
    await settle(tester);
  }

  testWidgets('indent puts a task under the task above: it is nested, below its parent, and its parent_id is set', (
    tester,
  ) async {
    final inbox = await seedInbox(tester);
    final plan = await addTask(tester, inbox, 'Plan', 1);
    final pack = await addTask(tester, inbox, 'Pack', 2);
    await tester.pumpWidget(app());
    await settle(tester);

    await pickMenu(tester, pack, 'Indent');

    final child = await taskTitled(tester, 'Pack');
    expect(child.parentId, plan);
    expect(child.version, 2);
    final planAt = tester.getTopLeft(find.text('Plan'));
    final packAt = tester.getTopLeft(find.text('Pack'));
    expect(packAt.dx, greaterThan(planAt.dx));
    expect(packAt.dy, greaterThan(planAt.dy));
    await unmount(tester);
  });

  testWidgets('the first task has no Indent, and a subtask has no Indent for the task it is already under', (
    tester,
  ) async {
    final inbox = await seedInbox(tester);
    final plan = await addTask(tester, inbox, 'Plan', 1);
    final pack = await addTask(tester, inbox, 'Pack', 2);
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(Key('taskMenu-$plan')));
    await animate(tester);
    expect(find.text('Move to section'), findsOneWidget);
    expect(find.text('Indent'), findsNothing);
    expect(find.text('Outdent'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await animate(tester);

    await pickMenu(tester, pack, 'Indent');
    await tester.tap(find.byKey(Key('taskMenu-$pack')));
    await animate(tester);
    expect(find.text('Indent'), findsNothing);
    expect(find.text('Outdent'), findsOneWidget);
    expect(find.text('Move to section'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await animate(tester);
    await unmount(tester);
  });

  testWidgets('outdent returns a subtask to the top level, in its place in the list', (tester) async {
    final inbox = await seedInbox(tester);
    final plan = await addTask(tester, inbox, 'Plan', 1);
    final pack = await addTask(tester, inbox, 'Pack', 2);
    await tester.runAsync(() => writer().update('tasks', pack, {'parent_id': plan}));
    await tester.pumpWidget(app());
    await settle(tester);

    await pickMenu(tester, pack, 'Outdent');

    expect((await taskTitled(tester, 'Pack')).parentId, isNull);
    expect(tester.getTopLeft(find.text('Pack')).dx, tester.getTopLeft(find.text('Plan')).dx);
    expect(tester.getTopLeft(find.text('Pack')).dy, greaterThan(tester.getTopLeft(find.text('Plan')).dy));
    await unmount(tester);
  });

  testWidgets('completing the parent keeps its open subtasks shown under it', (tester) async {
    final inbox = await seedInbox(tester);
    final plan = await addTask(tester, inbox, 'Plan', 1);
    final pack = await addTask(tester, inbox, 'Pack', 2);
    await tester.runAsync(() => writer().update('tasks', pack, {'parent_id': plan}));
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byType(Checkbox).first); // the parent
    await settle(tester);

    expect((await taskTitled(tester, 'Plan')).status, 2);
    expect(find.text('Pack'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pack')).dx, greaterThan(tester.getTopLeft(find.text('Plan')).dx));
    await unmount(tester);
  });

  testWidgets('a subtask counts in its section heading, and stays in that section', (tester) async {
    final inbox = await seedInbox(tester);
    late String section;
    await tester.runAsync(() async {
      section = await writer().insert('sections', {'list_id': inbox, 'name': 'Later', 'sort_order': 1.0});
    });
    final plan = await addTask(tester, inbox, 'Plan', 1, section: section);
    final pack = await addTask(tester, inbox, 'Pack', 2, section: section);
    await tester.pumpWidget(app());
    await settle(tester);
    final heading = find.byKey(Key('section-$section'));
    expect(find.descendant(of: heading, matching: find.text('2')), findsOneWidget);

    await pickMenu(tester, pack, 'Indent');

    expect((await taskTitled(tester, 'Pack')).parentId, plan);
    expect(find.descendant(of: heading, matching: find.text('2')), findsOneWidget);
    expect(find.text('Pack'), findsOneWidget);
    await unmount(tester);
  });
}
