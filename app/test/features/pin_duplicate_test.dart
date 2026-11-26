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
  late String inbox;
  LocalWriter writer() => LocalWriter(store, deviceId: 'win-test');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWith((ref) => 'win-test'),
      deviceZoneProvider.overrideWith((ref) async => 'Europe/Paris'),
      authServiceProvider.overrideWithValue(FakeAuthService()),
    ],
    child: const SheetTickApp(),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<String> insert(WidgetTester tester, String tab, Map<String, Object?> fields) async {
    late String id;
    await tester.runAsync(() async => id = await writer().insert(tab, fields));
    return id;
  }

  Future<void> seedInbox(WidgetTester tester, [Map<String, Object?> fields = const {}]) async {
    inbox = await insert(tester, 'lists', {'name': 'Inbox', 'is_inbox': true, ...fields});
  }

  Future<String> seedTask(WidgetTester tester, String title, [Map<String, Object?> fields = const {}]) =>
      insert(tester, 'tasks', {'list_id': inbox, 'title': title, ...fields});

  Future<List<Task>> tasks(WidgetTester tester) async => (await tester.runAsync(() => db.select(db.tasks).get()))!;

  Future<void> menu(WidgetTester tester, String id, String item) async {
    await tester.tap(find.byKey(Key('taskMenu-$id')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, item));
    await settle(tester);
  }

  double top(WidgetTester tester, String id) => tester.getTopLeft(find.byKey(ValueKey(id))).dy;

  testWidgets('Pin moves a task to the head of its list whatever the sort, and Unpin puts it back', (tester) async {
    await seedInbox(tester, {'order_by': 'title'});
    final apple = await seedTask(tester, 'Apple');
    final zebra = await seedTask(tester, 'Zebra');
    await start(tester);
    expect(top(tester, apple), lessThan(top(tester, zebra)));
    expect(find.byKey(const Key('pinnedHeader')), findsNothing);

    await menu(tester, zebra, 'Pin');

    expect((await tasks(tester)).singleWhere((t) => t.id == zebra).pinnedAt, isNotNull);
    expect(find.byKey(const Key('pinnedHeader')), findsOneWidget);
    expect(top(tester, zebra), lessThan(top(tester, apple)));
    expect(find.text('Task pinned'), findsOneWidget);

    await menu(tester, zebra, 'Unpin');

    expect((await tasks(tester)).singleWhere((t) => t.id == zebra).pinnedAt, isNull);
    expect(find.byKey(const Key('pinnedHeader')), findsNothing);
    expect(top(tester, apple), lessThan(top(tester, zebra)));
    await unmount(tester);
  });

  testWidgets('a pinned task shows above the sections, and stays when its section is folded', (tester) async {
    await seedInbox(tester);
    final section = await insert(tester, 'sections', {'list_id': inbox, 'name': 'Later', 'collapsed': true});
    final loose = await seedTask(tester, 'Loose');
    final filed = await seedTask(tester, 'Filed', {'section_id': section, 'pinned_at': '2026-11-26T09:00:00Z'});
    final child = await seedTask(tester, 'Child of filed', {'parent_id': filed});
    await start(tester);

    expect(top(tester, filed), lessThan(top(tester, child)));
    expect(top(tester, child), lessThan(top(tester, loose)));
    // Select all picks what can be seen, the pinned ones among it.
    await tester.tap(find.byKey(Key('taskMenu-$loose')));
    await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Select'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('selectAll')));
    await settle(tester);
    expect(find.text('3 selected'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a grouped list shows the pinned task once, above the groups', (tester) async {
    await seedInbox(tester, {'group_by': 'priority'});
    final high = await seedTask(tester, 'High one', {'priority': 5});
    final pinned = await seedTask(tester, 'Pinned one', {'pinned_at': '2026-11-26T09:00:00Z'});
    await start(tester);

    expect(find.text('Pinned one'), findsOneWidget);
    expect(top(tester, pinned), lessThan(tester.getTopLeft(find.text('High one')).dy));
    expect(find.text('High one'), findsOneWidget);
    expect(high, isNotEmpty);
    await unmount(tester);
  });

  testWidgets('Duplicate puts a copy under the original, with its subtasks, and Undo takes it all away', (tester) async {
    await seedInbox(tester);
    final trip = await seedTask(tester, 'Plan trip', {'sort_order': 1.0});
    await seedTask(tester, 'Book hotel', {'parent_id': trip});
    final after = await seedTask(tester, 'Water plants', {'sort_order': 2.0});
    await insert(tester, 'checklist', {'task_id': trip, 'title': 'passport'});
    await start(tester);

    await menu(tester, trip, 'Duplicate');

    expect(find.text('Plan trip'), findsNWidgets(2));
    expect(find.text('Book hotel'), findsNWidgets(2));
    expect(find.text('Task duplicated'), findsOneWidget);
    final copy = (await tasks(tester)).singleWhere((t) => t.title == 'Plan trip' && t.id != trip);
    expect(top(tester, trip), lessThan(top(tester, copy.id)));
    expect(top(tester, copy.id), lessThan(top(tester, after)));

    await tester.tap(find.text('Undo'));
    await settle(tester);

    expect(find.text('Plan trip'), findsOneWidget);
    expect(find.text('Book hotel'), findsOneWidget);
    final items = (await tester.runAsync(() => db.select(db.checklist).get()))!;
    expect(items.where((i) => !i.deleted), hasLength(1));
    await unmount(tester);
  });

  testWidgets('a completed task can be duplicated but not pinned; a subtask cannot be pinned', (tester) async {
    await seedInbox(tester);
    final done = await seedTask(tester, 'Finished', {'status': 2});
    final parent = await seedTask(tester, 'Parent');
    final child = await seedTask(tester, 'Child', {'parent_id': parent});
    await start(tester);

    for (final id in [done, child]) {
      await tester.tap(find.byKey(Key('taskMenu-$id')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.widgetWithText(PopupMenuItem<String>, 'Duplicate'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<String>, 'Pin'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await unmount(tester);
  });
}
