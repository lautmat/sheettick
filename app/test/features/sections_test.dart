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

  /// Signed out: the lists, sections and tasks are on the device, and the screen works without Google.
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

  /// Lets queued database work and stream emissions finish. drift answers over several event-loop turns, so this
  /// yields in short real-time slices, pumping a frame after each.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  /// Runs a dialog or menu animation to its end. Fixed steps rather than pumpAndSettle, which never returns while a
  /// spinner is spinning.
  Future<void> animate(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<T> onDb<T>(WidgetTester tester, Future<T> Function() read) async => (await tester.runAsync(read)) as T;

  /// Writes a row through the local writer, as the app does, and returns its id.
  Future<String> seed(WidgetTester tester, String tab, Map<String, Object?> values) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert(tab, values);
    });
    return id;
  }

  Future<Section> sectionRow(WidgetTester tester, String id) =>
      onDb(tester, () => (db.select(db.sections)..where((s) => s.id.equals(id))).getSingle());

  Future<Task> taskRow(WidgetTester tester, String id) =>
      onDb(tester, () => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle());

  /// Types [text] into the name dialog and presses Save. The field is looked up inside the dialog, since the list
  /// has its own text field.
  Future<void> saveName(WidgetTester tester, String text) async {
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), text);
    await tester.tap(find.text('Save'));
    await animate(tester);
    await settle(tester);
  }

  testWidgets('New section: it shows as a heading on the list and is stored as a dirty row', (tester) async {
    await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(const Key('newSection')));
    await animate(tester);
    await saveName(tester, 'Later');

    final created = await onDb(
      tester,
      () => (db.select(db.sections)..where((s) => s.name.equals('Later'))).getSingle(),
    );
    expect(created.dirty, isTrue);
    expect(find.byKey(Key('section-${created.id}')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('move a task into a section: it sits under the heading, and section_id is written', (tester) async {
    final inbox = await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final sectionId = await seed(tester, 'sections', {'list_id': inbox, 'name': 'Later'});
    final taskId = await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Pay rent'});
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(Key('taskMenu-$taskId')));
    await animate(tester);
    await tester.tap(find.text('Move to section'));
    await animate(tester);
    await tester.tap(find.byKey(Key('pick-$sectionId')));
    await animate(tester);
    await settle(tester);

    expect((await taskRow(tester, taskId)).sectionId, sectionId);
    final headingTop = tester.getTopLeft(find.byKey(Key('section-$sectionId'))).dy;
    expect(tester.getTopLeft(find.byKey(ValueKey(taskId))).dy, greaterThan(headingTop));
    await unmount(tester);
  });

  testWidgets('folding a section hides its tasks, and the fold is stored', (tester) async {
    final inbox = await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final sectionId = await seed(tester, 'sections', {'list_id': inbox, 'name': 'Later'});
    await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Pay rent', 'section_id': sectionId});
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('Pay rent'), findsOneWidget);

    await tester.tap(find.byKey(Key('section-$sectionId')));
    await animate(tester);
    await settle(tester);
    expect((await sectionRow(tester, sectionId)).collapsed, isTrue);
    expect(find.text('Pay rent'), findsNothing);

    await tester.tap(find.byKey(Key('section-$sectionId')));
    await animate(tester);
    await settle(tester);
    expect((await sectionRow(tester, sectionId)).collapsed, isFalse);
    expect(find.text('Pay rent'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('rename a section from its menu', (tester) async {
    final inbox = await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final sectionId = await seed(tester, 'sections', {'list_id': inbox, 'name': 'Later'});
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(Key('sectionMenu-$sectionId')));
    await animate(tester);
    await tester.tap(find.text('Rename'));
    await animate(tester);
    await saveName(tester, 'Bills');

    expect((await sectionRow(tester, sectionId)).name, 'Bills');
    await unmount(tester);
  });

  testWidgets('a heading with a long name and a task count fits on a phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final inbox = await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final sectionId = await seed(tester, 'sections', {
      'list_id': inbox,
      'name': 'A very long section name that keeps going well past the width of a phone screen',
    });
    for (var i = 0; i < 12; i++) {
      await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Task $i', 'section_id': sectionId});
    }
    await tester.pumpWidget(app());
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(Key('sectionMenu-$sectionId')), findsOneWidget);
    await unmount(tester);
  });
}
