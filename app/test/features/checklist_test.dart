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

  /// Lets queued database work and stream emissions finish. Each slice also moves the fake clock on, so a route or
  /// dialog that closes after a write finishes its transition.
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

  Future<String> addTask(WidgetTester tester, String list, String title) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('tasks', {'list_id': list, 'title': title});
    });
    return id;
  }

  Future<String> addItem(WidgetTester tester, String task, String title, double order) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('checklist', {'task_id': task, 'title': title, 'sort_order': order});
    });
    return id;
  }

  Future<Task> taskTitled(WidgetTester tester, String title) async =>
      (await tester.runAsync(() => (db.select(db.tasks)..where((t) => t.title.equals(title))).getSingle()))!;

  Future<ChecklistItem> itemTitled(WidgetTester tester, String title) async =>
      (await tester.runAsync(() => (db.select(db.checklist)..where((c) => c.title.equals(title))).getSingle()))!;

  /// Opens the task titled [title] from the Inbox list.
  Future<void> openTask(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await animate(tester);
    await settle(tester);
  }

  testWidgets('adding items: Enter adds one at the end, and the first makes the task a checklist task', (tester) async {
    final inbox = await seedInbox(tester);
    await addTask(tester, inbox, 'Pack for the trip');
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pack for the trip');

    await tester.enterText(find.byKey(const Key('addChecklistItemField')), 'Socks');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await tester.enterText(find.byKey(const Key('addChecklistItemField')), 'Shirts');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect((await itemTitled(tester, 'Socks')).sortOrder, 1);
    expect((await itemTitled(tester, 'Shirts')).sortOrder, 2);
    expect((await taskTitled(tester, 'Pack for the trip')).kind, 'CHECKLIST');
    expect(find.text('Socks'), findsOneWidget);
    expect(find.text('Shirts'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tick and untick an item: status 2 with completed_at, then back to open', (tester) async {
    final inbox = await seedInbox(tester);
    final task = await addTask(tester, inbox, 'Pack');
    await addItem(tester, task, 'Socks', 1);
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pack');

    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);
    var item = await itemTitled(tester, 'Socks');
    expect(item.status, 2);
    expect(item.completedAt, isNotNull);

    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);
    item = await itemTitled(tester, 'Socks');
    expect(item.status, 0);
    expect(item.completedAt, isNull);
    await unmount(tester);
  });

  testWidgets('rename an item from its dialog; a blank name is ignored', (tester) async {
    final inbox = await seedInbox(tester);
    final task = await addTask(tester, inbox, 'Pack');
    await addItem(tester, task, 'Socks', 1);
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pack');

    await tester.tap(find.text('Socks'));
    await animate(tester);
    expect(find.text('Edit item'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Wool socks');
    await tester.tap(find.text('Save'));
    await animate(tester);
    await settle(tester);
    expect(find.text('Wool socks'), findsOneWidget);
    expect((await itemTitled(tester, 'Wool socks')).version, 2);

    await tester.tap(find.text('Wool socks'));
    await animate(tester);
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.tap(find.text('Save'));
    await animate(tester);
    await settle(tester);
    expect(find.text('Wool socks'), findsOneWidget);
    expect((await itemTitled(tester, 'Wool socks')).version, 2);
    await unmount(tester);
  });

  testWidgets('delete an item: it leaves the list, and its row is kept as a tombstone', (tester) async {
    final inbox = await seedInbox(tester);
    final task = await addTask(tester, inbox, 'Pack');
    final socks = await addItem(tester, task, 'Socks', 1);
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pack');

    await tester.tap(find.byTooltip('Delete item'));
    await settle(tester);

    expect(find.text('Socks'), findsNothing);
    final row = await tester.runAsync(() => store.getRow('checklist', socks));
    expect(row!.fields['deleted'], true);
    await unmount(tester);
  });

  testWidgets('drag an item by its handle to move it above the one before it', (tester) async {
    final inbox = await seedInbox(tester);
    final task = await addTask(tester, inbox, 'Pack');
    await addItem(tester, task, 'Socks', 1);
    await addItem(tester, task, 'Shirts', 2);
    await tester.pumpWidget(app());
    await settle(tester);
    await openTask(tester, 'Pack');

    final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.drag_indicator).last));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await settle(tester);

    expect((await itemTitled(tester, 'Shirts')).sortOrder, 1);
    expect((await itemTitled(tester, 'Socks')).sortOrder, 2);
    expect(tester.getTopLeft(find.text('Shirts')).dy, lessThan(tester.getTopLeft(find.text('Socks')).dy));
    await unmount(tester);
  });
}
