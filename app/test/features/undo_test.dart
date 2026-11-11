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

  Widget app() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWith((ref) => 'win-test'),
        deviceZoneProvider.overrideWith((ref) async => 'Europe/Paris'),
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<String> seedTask(WidgetTester tester, String title, [Map<String, Object?> fields = const {}]) async {
    late String id;
    await tester.runAsync(() async {
      final lists = await db.select(db.lists).get();
      final inbox = lists.isEmpty
          ? await writer().insert('lists', {'name': 'Inbox', 'is_inbox': true})
          : lists.single.id;
      id = await writer().insert('tasks', {'list_id': inbox, 'title': title, ...fields});
    });
    return id;
  }

  Future<Task> row(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle()))!;

  Future<void> tapUndo(WidgetTester tester) async {
    await tester.tap(find.text('Undo'));
    await settle(tester);
  }

  testWidgets('ticking a task offers Undo, and Undo unticks it with a new version', (tester) async {
    final id = await seedTask(tester, 'Buy milk');
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(Key('taskCheck-$id')));
    await settle(tester);
    expect(find.text('Task completed'), findsOneWidget);
    expect((await row(tester, id)).status, 2);

    await tapUndo(tester);
    final t = await row(tester, id);
    expect(t.status, 0);
    expect(t.completedAt, isNull);
    expect(t.version, 3); // created, completed, undone
    expect(tester.widget<Checkbox>(find.byKey(Key('taskCheck-$id'))).value, isFalse);
    await unmount(tester);
  });

  testWidgets('unticking offers Undo too', (tester) async {
    final id = await seedTask(tester, 'Done already', {'status': 2, 'completed_at': '2026-11-01T08:00:00Z'});
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(Key('taskCheck-$id')));
    await settle(tester);
    expect(find.text('Task reopened'), findsOneWidget);
    await tapUndo(tester);
    final t = await row(tester, id);
    expect(t.status, 2);
    expect(t.completedAt, '2026-11-01T08:00:00Z');
    await unmount(tester);
  });

  testWidgets('finishing a repeating task and undoing leaves one task, repeating as before', (tester) async {
    final id = await seedTask(tester, 'Water plants', {
      'due_at': '2026-11-11',
      'all_day': true,
      'rrule': 'RRULE:FREQ=DAILY',
    });
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(Key('taskCheck-$id')));
    await settle(tester);
    expect(await tester.runAsync(() => db.select(db.tasks).get()), hasLength(2));

    await tapUndo(tester);
    final all = (await tester.runAsync(() => db.select(db.tasks).get()))!;
    expect(all.where((t) => !t.deleted).map((t) => t.id), [id]);
    final t = await row(tester, id);
    expect((t.status, t.rrule), (0, 'RRULE:FREQ=DAILY'));
    expect(find.text('Water plants'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('deleting from the task page: the snackbar outlives the page, and Undo brings the task back', (
    tester,
  ) async {
    final id = await seedTask(tester, 'draft');
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.text('draft'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('taskMenu')));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Move to Trash'));
    await settle(tester);

    expect(find.byKey(const Key('taskTitleField')), findsNothing);
    expect(find.text('draft'), findsNothing);
    expect(find.text('Task moved to Trash'), findsOneWidget);

    await tapUndo(tester);
    expect((await row(tester, id)).deleted, isFalse);
    expect(find.text('draft'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("Won't do from the task page is undone", (tester) async {
    final id = await seedTask(tester, 'maybe');
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.text('maybe'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('taskMenu')));
    await settle(tester);
    await tester.tap(find.text("Won't do"));
    await settle(tester);
    expect((await row(tester, id)).status, -1);
    expect(find.text("Marked Won't Do"), findsOneWidget);

    await tapUndo(tester);
    expect((await row(tester, id)).status, 0);
    await unmount(tester);
  });

  testWidgets('an edit made on the task page is offered for undo when the page closes', (tester) async {
    final id = await seedTask(tester, 'Old title', {'content': 'old notes'});
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.text('Old title'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('taskTitleField')), 'New title');
    await tester.pump();
    await tester.pageBack();
    await settle(tester);
    expect((await row(tester, id)).title, 'New title');
    expect(find.text('Task edited'), findsOneWidget);

    await tapUndo(tester);
    final t = await row(tester, id);
    expect((t.title, t.content), ('Old title', 'old notes'));
    expect(find.text('Old title'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the snackbar goes away by itself, and a newer change replaces the older offer', (tester) async {
    final a = await seedTask(tester, 'A');
    final b = await seedTask(tester, 'B');
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(Key('taskCheck-$a')));
    await settle(tester);
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.byKey(Key('taskCheck-$b')));
    await settle(tester);
    // Only the last change is offered; Undo reverses B and leaves A done.
    expect(find.text('Undo'), findsOneWidget);
    await tapUndo(tester);
    expect((await row(tester, a)).status, 2);
    expect((await row(tester, b)).status, 0);

    await tester.tap(find.byKey(Key('taskCheck-$b')));
    await settle(tester);
    expect(find.text('Undo'), findsOneWidget);
    // The timer starts when the snackbar has finished sliding in, then the slide out takes a moment more.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Undo'), findsNothing);
    await unmount(tester);
  });
}
