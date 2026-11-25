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

  testWidgets('on a wide window a task opens beside the list; switching saves edits; the sidebar folds away', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final inbox = await seedInbox(tester);
    await tester.runAsync(() async {
      await writer().insert('tasks', {'list_id': inbox, 'title': 'first'});
      await writer().insert('tasks', {'list_id': inbox, 'title': 'second'});
    });
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.byKey(const Key('taskPane')), findsNothing);
    await tester.tap(find.text('first'));
    await settle(tester);
    expect(find.byKey(const Key('taskPane')), findsOneWidget);
    // The list is still on screen next to the pane.
    expect(find.text('second'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('taskTitleField')), 'first edited');
    await tester.tap(find.text('second'));
    await settle(tester);
    final titles = await tester.runAsync(() async => [for (final t in await db.select(db.tasks).get()) t.title]);
    expect(titles, containsAll(['first edited', 'second']));
    expect(tester.widget<TextField>(find.byKey(const Key('taskTitleField'))).controller!.text, 'second');

    await tester.tap(find.byKey(const Key('taskPaneClose')));
    await settle(tester);
    expect(find.byKey(const Key('taskPane')), findsNothing);

    expect(find.byKey(const Key('newList')), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggleSidebar')));
    await tester.pump();
    expect(find.byKey(const Key('newList')), findsNothing);
    await tester.tap(find.byKey(const Key('toggleSidebar')));
    await tester.pump();
    expect(find.byKey(const Key('newList')), findsOneWidget);
    await unmount(tester);
  });
}
