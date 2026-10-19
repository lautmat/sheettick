import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/app.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/providers.dart';
import 'package:sheettick/core/sheets/sheets_backend.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';

import '../support/fake_sheets_backend.dart';
import '../support/test_device.dart';

/// Fails every call, as if the network were down.
class _Unreachable extends FakeSheetsBackend {
  @override
  Future<SpreadsheetFile?> getFile(String id) => throw StateError('network unreachable');
  @override
  Future<List<SpreadsheetFile>> findSpreadsheets() => throw StateError('network unreachable');
}

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

  Widget app({SheetsBackend? backend}) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWith((ref) => 'win-test'),
      sheetsBackendProvider.overrideWithValue(backend),
    ],
    child: const SheetTickApp(),
  );

  /// Lets queued database work and stream emissions finish.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // drift closes a cancelled stream on a zero-duration timer; let it fire before the binding checks timers.
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// A device that already signed in: an Inbox list exists locally.
  Future<String> seedInbox(WidgetTester tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('lists', {'name': 'Inbox', 'is_inbox': true});
    });
    return id;
  }

  Future<List<Task>> tasksInDb(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.tasks).get()))!;

  testWidgets('before the first sign-in it asks to sign in and says changes stay local', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Sign in to Google to set up your Inbox.'), findsOneWidget);
    expect(find.byKey(const Key('syncBanner')), findsOneWidget);
    expect(find.textContaining('Not signed in'), findsOneWidget);
    expect(find.byKey(const Key('addTaskField')), findsNothing);
    await unmount(tester);
  });

  testWidgets('add a task: it shows up, and is stored locally as a dirty row', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('Nothing here. Add your first task below.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('addTaskField')), '  Buy milk ');
    await tester.tap(find.byKey(const Key('addTaskButton')));
    await settle(tester);

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Nothing here. Add your first task below.'), findsNothing);
    final tasks = await tasksInDb(tester);
    expect(tasks.single.title, 'Buy milk');
    expect(tasks.single.dirty, isTrue);
    expect(tasks.single.version, 1);
    expect(tasks.single.device, 'win-test');
    await unmount(tester);
  });

  testWidgets('submitting from the keyboard adds too, and an empty entry adds nothing', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.enterText(find.byKey(const Key('addTaskField')), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(await tasksInDb(tester), isEmpty);

    await tester.enterText(find.byKey(const Key('addTaskField')), 'Call Anna');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Call Anna'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('complete a task: status 2 with completed_at, and it moves below the open ones', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() async {
      final w = writer();
      await w.insert('tasks', {'list_id': inbox, 'title': 'first'});
      await w.insert('tasks', {'list_id': inbox, 'title': 'second'});
    });
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);

    final tasks = await tasksInDb(tester);
    final first = tasks.firstWhere((t) => t.title == 'first');
    expect(first.status, 2);
    expect(first.completedAt, isNotNull);
    expect(first.version, 2);
    // Open tasks come first: "second" is now above the completed "first".
    expect(tester.getTopLeft(find.text('second')).dy, lessThan(tester.getTopLeft(find.text('first')).dy));

    await tester.tap(find.byType(Checkbox).last); // un-complete
    await settle(tester);
    final again = (await tasksInDb(tester)).firstWhere((t) => t.title == 'first');
    expect(again.status, 0);
    expect(again.completedAt, isNull);
    await unmount(tester);
  });

  testWidgets('edit a title: the dialog saves a new one, ignores blank, and cancel changes nothing', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.runAsync(() async => writer().insert('tasks', {'list_id': inbox, 'title': 'draft'}));
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.text('draft'));
    await tester.pumpAndSettle();
    expect(find.text('Edit title'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'final report');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('final report'), findsOneWidget);
    var t = (await tasksInDb(tester)).single;
    expect((t.title, t.version), ('final report', 2));

    await tester.tap(find.text('final report'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('final report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    t = (await tasksInDb(tester)).single;
    expect((t.title, t.version), ('final report', 2));
    await unmount(tester);
  });

  testWidgets('Sync now signs the device in to the Sheet: bootstrap, then the tasks of another device appear', (tester) async {
    final backend = FakeSheetsBackend();
    final other = await tester.runAsync(() async {
      final d = await TestDevice.create(backend, id: 'and-0002');
      await d.addTask('From my phone');
      await d.sync();
      return d;
    });

    await tester.pumpWidget(app(backend: backend)); // starting the app triggers a sync
    await settle(tester);
    await settle(tester);

    expect(find.text('From my phone'), findsOneWidget);
    expect(find.byKey(const Key('addTaskField')), findsOneWidget);
    expect(find.byKey(const Key('syncBanner')), findsNothing);

    // An edit made here reaches the Sheet by pressing Sync now, and the other device sees it.
    await tester.enterText(find.byKey(const Key('addTaskField')), 'From my PC');
    await tester.tap(find.byKey(const Key('addTaskButton')));
    await settle(tester);
    await tester.tap(find.byTooltip('Sync now'));
    await settle(tester);
    await settle(tester);

    await tester.runAsync(() => other!.sync());
    final titles = await tester.runAsync(() async => (await other!.store.rowsById('tasks')).values.map((r) => r.fields['title']).toSet());
    expect(titles, {'From my phone', 'From my PC'});
    await unmount(tester);
    await tester.runAsync(() => other!.close());
  });

  testWidgets('a failing sync shows a message and keeps working offline', (tester) async {
    await seedInbox(tester);
    await tester.runAsync(() => store.setState('spreadsheet_id', 'sheet-1'));
    await tester.pumpWidget(app(backend: _Unreachable()));
    await settle(tester);

    expect(find.textContaining('Sync failed'), findsOneWidget);
    expect(find.textContaining('network unreachable'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('addTaskField')), 'still works offline');
    await tester.tap(find.byKey(const Key('addTaskButton')));
    await settle(tester);
    expect(find.text('still works offline'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('follows the system theme: light and dark', (tester) async {
    await seedInbox(tester);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpWidget(app());
      await settle(tester);
      expect(Theme.of(tester.element(find.byType(Scaffold))).brightness, brightness);
      await unmount(tester);
    }
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  });
}
