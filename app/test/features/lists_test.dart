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

  /// Signed out: the lists and folders are on the device, and the sidebar works without Google.
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

  /// Runs a dialog, menu or drawer animation to its end. Fixed steps rather than pumpAndSettle, which never
  /// returns while a spinner is spinning.
  Future<void> animate(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // drift closes a cancelled stream on a zero-duration timer; let it fire before the binding checks timers.
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

  Future<TaskList> listRow(WidgetTester tester, String id) =>
      onDb(tester, () => (db.select(db.lists)..where((l) => l.id.equals(id))).getSingle());

  Future<Folder> folderRow(WidgetTester tester, String id) =>
      onDb(tester, () => (db.select(db.folders)..where((f) => f.id.equals(id))).getSingle());

  /// Types [text] into the name dialog and presses Save. The text field is looked up inside the dialog, since the
  /// Inbox has its own text field.
  Future<void> saveName(WidgetTester tester, String text) async {
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), text);
    await tester.tap(find.text('Save'));
    await animate(tester);
    await settle(tester);
  }

  Future<void> openListMenu(WidgetTester tester, String id, String item) async {
    await tester.tap(find.byKey(Key('listMenu-$id')));
    await animate(tester);
    await tester.tap(find.text(item));
    await animate(tester);
  }

  testWidgets('New list: it is selected, shows in the sidebar, and is stored as a dirty row', (tester) async {
    await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(const Key('newList')));
    await animate(tester);
    await saveName(tester, 'Groceries');

    final created = await onDb(
      tester,
      () => (db.select(db.lists)..where((l) => l.name.equals('Groceries'))).getSingle(),
    );
    expect(created.dirty, isTrue);
    expect(created.sortOrder, 1.0); // after the Inbox, which is at 0
    expect(find.byKey(Key('list-${created.id}')), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Groceries')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('rename a list from its menu', (tester) async {
    await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final id = await seed(tester, 'lists', {'name': 'Errands'});
    await tester.pumpWidget(app());
    await settle(tester);

    await openListMenu(tester, id, 'Rename');
    await saveName(tester, 'Chores');

    expect((await listRow(tester, id)).name, 'Chores');
    expect(find.byKey(Key('list-$id')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('colour a list, and No colour clears it', (tester) async {
    await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final id = await seed(tester, 'lists', {'name': 'Errands'});
    await tester.pumpWidget(app());
    await settle(tester);

    await openListMenu(tester, id, 'Colour');
    await tester.tap(find.byKey(const Key('colour-#E53935')));
    await animate(tester);
    await settle(tester);
    expect((await listRow(tester, id)).color, '#E53935');

    await openListMenu(tester, id, 'Colour');
    await tester.tap(find.byKey(const Key('noColour')));
    await animate(tester);
    await settle(tester);
    expect((await listRow(tester, id)).color, isNull);
    await unmount(tester);
  });

  testWidgets('move a list into a folder: it is listed below the folder header', (tester) async {
    await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final listId = await seed(tester, 'lists', {'name': 'Errands'});
    final folderId = await seed(tester, 'folders', {'name': 'Home'});
    await tester.pumpWidget(app());
    await settle(tester);

    await openListMenu(tester, listId, 'Move to folder');
    await tester.tap(find.byKey(Key('pick-$folderId')));
    await animate(tester);
    await settle(tester);

    expect((await listRow(tester, listId)).folderId, folderId);
    final headerTop = tester.getTopLeft(find.byKey(Key('folder-$folderId'))).dy;
    expect(tester.getTopLeft(find.byKey(Key('list-$listId'))).dy, greaterThan(headerTop));
    await unmount(tester);
  });

  testWidgets('archive a list: it leaves the sidebar, and Restore brings it back', (tester) async {
    await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final id = await seed(tester, 'lists', {'name': 'Old plans'});
    await tester.pumpWidget(app());
    await settle(tester);

    await openListMenu(tester, id, 'Archive');
    await settle(tester);
    expect((await listRow(tester, id)).archived, isTrue);
    expect(find.byKey(Key('list-$id')), findsNothing);

    await tester.tap(find.text('Archived (1)'));
    await animate(tester);
    await tester.tap(find.byTooltip('Restore'));
    await settle(tester);
    expect((await listRow(tester, id)).archived, isFalse);
    expect(find.byKey(Key('list-$id')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('rename a folder; deleting it tombstones it and its lists stay at the top level', (tester) async {
    await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final folderId = await seed(tester, 'folders', {'name': 'Work'});
    final listId = await seed(tester, 'lists', {'name': 'Reports', 'folder_id': folderId});
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byKey(Key('folder-$folderId')), findsOneWidget);

    await tester.tap(find.byKey(Key('folderMenu-$folderId')));
    await animate(tester);
    await tester.tap(find.text('Rename'));
    await animate(tester);
    await saveName(tester, 'Office');
    expect((await folderRow(tester, folderId)).name, 'Office');

    await tester.tap(find.byKey(Key('folderMenu-$folderId')));
    await animate(tester);
    await tester.tap(find.text('Delete'));
    await animate(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await animate(tester);
    await settle(tester);

    expect((await folderRow(tester, folderId)).deleted, isTrue);
    expect(find.byKey(Key('folder-$folderId')), findsNothing);
    expect((await listRow(tester, listId)).deleted, isFalse);
    expect(find.byKey(Key('list-$listId')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('picking a list shows its tasks; the Inbox shows only its own', (tester) async {
    final inbox = await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final groceries = await seed(tester, 'lists', {'name': 'Groceries'});
    await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Call the bank'});
    await seed(tester, 'tasks', {'list_id': groceries, 'title': 'Buy milk'});
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('Call the bank'), findsOneWidget);
    expect(find.text('Buy milk'), findsNothing);

    await tester.tap(find.byKey(Key('list-$groceries')));
    await settle(tester);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Groceries')), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Call the bank'), findsNothing);
    await unmount(tester);
  });

  testWidgets('on a phone the lists sit in a drawer, and picking a list closes it', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final groceries = await seed(tester, 'lists', {'name': 'Groceries'});
    await tester.pumpWidget(app());
    await settle(tester);
    expect(tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen, isFalse);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await animate(tester);
    expect(tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen, isTrue);

    await tester.tap(find.byKey(Key('list-$groceries')));
    await animate(tester);
    await settle(tester);
    expect(tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen, isFalse);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Groceries')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('turning a phone window wide while the drawer is open leaves no error and a working sidebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seed(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
    final groceries = await seed(tester, 'lists', {'name': 'Groceries'});
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await animate(tester);
    expect(tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen, isTrue);

    tester.view.physicalSize = const Size(800, 600);
    await animate(tester);
    await settle(tester);
    expect(tester.takeException(), isNull);

    // The sidebar is beside the list now, so picking a list there works.
    await tester.tap(find.byKey(Key('list-$groceries')).last);
    await animate(tester);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Groceries')), findsOneWidget);
    await unmount(tester);
  });
}
