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

  const zone = 'Europe/Paris';

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

  Future<String> seed(WidgetTester tester, Map<String, Object?> fields) async {
    late String id;
    await tester.runAsync(() async {
      final inbox = await writer().insert('lists', {'name': 'Inbox', 'is_inbox': true});
      id = await writer().insert('tasks', {'list_id': inbox, 'title': 'Pay Visa card', ...fields});
    });
    return id;
  }

  Future<Task> row(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle()))!;

  Future<void> openTaskMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('taskMenu')));
    await animate(tester);
  }

  testWidgets('Skip on the task page moves it on, nothing is completed, and Undo puts it back', (tester) async {
    final id = await seed(tester, {'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=MONTHLY;BYMONTHDAY=1'});
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('Pay Visa card'));
    await animate(tester);
    await settle(tester);

    await openTaskMenu(tester);
    await tester.tap(find.text('Skip this occurrence'));
    await animate(tester);
    await settle(tester);

    var task = await row(tester, id);
    expect(task.dueAt, '2027-01-01');
    expect(task.status, 0);
    expect(task.exDates, '["2026-12-01"]');
    expect(task.version, 2);
    expect(find.text('Occurrence skipped'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    task = await row(tester, id);
    expect(task.dueAt, '2026-12-01');
    expect(task.exDates, isNull);
    expect(task.version, 3, reason: 'undo is a new write, so it syncs');
    await unmount(tester);
  });

  testWidgets('Skip is in the list row menu too', (tester) async {
    final id = await seed(tester, {'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY'});
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byTooltip('Task options'));
    await animate(tester);
    await tester.tap(find.text('Skip this occurrence'));
    await animate(tester);
    await settle(tester);
    expect((await row(tester, id)).dueAt, '2026-12-02');
    await unmount(tester);
  });

  testWidgets('the last occurrence says so and changes nothing', (tester) async {
    final id = await seed(tester, {'due_at': '2026-12-01', 'all_day': true, 'rrule': 'RRULE:FREQ=DAILY;COUNT=1'});
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byTooltip('Task options'));
    await animate(tester);
    await tester.tap(find.text('Skip this occurrence'));
    await animate(tester);
    await settle(tester);
    expect(find.textContaining('No more occurrences'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect((await row(tester, id)).version, 1);
    await unmount(tester);
  });

  testWidgets('a task that does not repeat has no Skip', (tester) async {
    await seed(tester, {'due_at': '2026-12-01', 'all_day': true});
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byTooltip('Task options'));
    await animate(tester);
    expect(find.text('Skip this occurrence'), findsNothing);
    expect(find.text('Move to list'), findsOneWidget, reason: 'the menu itself is there');
    await unmount(tester);
  });
}
