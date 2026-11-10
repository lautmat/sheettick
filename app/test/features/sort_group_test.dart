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

  /// An Inbox with three tasks in the order they were made (manual order): Pear (low), apple (high), Mango (no priority).
  Future<({String inbox, String work})> seed(WidgetTester tester) async {
    late String inbox, work;
    await tester.runAsync(() async {
      final w = writer();
      inbox = await w.insert('lists', {'name': 'Inbox', 'is_inbox': true});
      work = await w.insert('lists', {'name': 'Work'});
      await w.insert('tasks', {'title': 'Pear', 'list_id': inbox, 'priority': 1, 'sort_order': 1.0, 'tags': 'fruit'});
      await w.insert('tasks', {'title': 'apple', 'list_id': inbox, 'priority': 5, 'sort_order': 2.0, 'tags': 'fruit,red'});
      await w.insert('tasks', {'title': 'Mango', 'list_id': inbox, 'sort_order': 3.0});
      await w.insert('tasks', {'title': 'Report', 'list_id': work, 'sort_order': 1.0});
    });
    return (inbox: inbox, work: work);
  }

  Future<TaskList> listRow(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => (db.select(db.lists)..where((l) => l.id.equals(id))).getSingle()))!;

  /// The titles on screen, top to bottom.
  List<String> order(WidgetTester tester, List<String> titles) {
    final found = [
      for (final t in titles)
        if (find.text(t).evaluate().isNotEmpty) (t, tester.getTopLeft(find.text(t)).dy),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final f in found) f.$1];
  }

  Future<void> choose(WidgetTester tester, Key field, String label) async {
    await tester.tap(find.byKey(field));
    await settle(tester);
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('sortGroupButton')));
    await settle(tester);
  }

  Future<void> closeDialog(WidgetTester tester) async {
    await tester.tap(find.text('Done'));
    await settle(tester);
  }

  const titles = ['Pear', 'apple', 'Mango', 'Report'];

  testWidgets('a list starts in manual order with no groups', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(order(tester, titles), ['Pear', 'apple', 'Mango']);
    await unmount(tester);
  });

  testWidgets('sorting reorders the rows and is saved in the list, bumping its version', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester);
    final before = await listRow(tester, ids.inbox);
    await tester.pumpWidget(app());
    await settle(tester);

    await openDialog(tester);
    await choose(tester, const Key('orderByField'), 'Title');
    await closeDialog(tester);
    expect(order(tester, titles), ['apple', 'Mango', 'Pear']);
    var row = await listRow(tester, ids.inbox);
    expect(row.orderBy, 'title');
    expect(row.version, before.version + 1);

    await openDialog(tester);
    await choose(tester, const Key('orderByField'), 'Priority');
    await closeDialog(tester);
    expect(order(tester, titles), ['apple', 'Pear', 'Mango']);

    await openDialog(tester);
    await choose(tester, const Key('orderByField'), 'Manual');
    await closeDialog(tester);
    expect(order(tester, titles), ['Pear', 'apple', 'Mango']);
    row = await listRow(tester, ids.inbox);
    expect(row.orderBy, isNull);
    await unmount(tester);
  });

  testWidgets('grouping shows a heading per group, and is saved in the list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await openDialog(tester);
    await choose(tester, const Key('groupByField'), 'Priority');
    await closeDialog(tester);
    expect(find.byKey(const Key('group-High')), findsOneWidget);
    expect(find.byKey(const Key('group-Low')), findsOneWidget);
    expect(find.byKey(const Key('group-None')), findsOneWidget);
    expect(find.byKey(const Key('group-Medium')), findsNothing);
    expect(order(tester, titles), ['apple', 'Pear', 'Mango']);
    expect((await listRow(tester, ids.inbox)).groupBy, 'priority');

    await openDialog(tester);
    await choose(tester, const Key('groupByField'), 'Tag');
    await closeDialog(tester);
    // apple is in both fruit and red, so it shows twice.
    expect(find.text('apple'), findsNWidgets(2));
    expect(find.byKey(const Key('group-fruit')), findsOneWidget);
    expect(find.byKey(const Key('group-red')), findsOneWidget);
    expect(find.byKey(const Key('group-No tag')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the choice belongs to the list: another list is unchanged, and the choice is still there on return', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester);
    await tester.runAsync(() => writer().update('lists', ids.inbox, {'order_by': 'title', 'group_by': 'priority'}));
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byKey(const Key('group-High')), findsOneWidget);

    await tester.tap(find.byKey(Key('list-${ids.work}')));
    await settle(tester);
    expect(find.byKey(const Key('group-None')), findsNothing);
    expect(find.text('Report'), findsOneWidget);

    await tester.tap(find.byKey(Key('list-${ids.inbox}')));
    await settle(tester);
    expect(find.byKey(const Key('group-High')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the dialog shows the saved choices', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester);
    await tester.runAsync(() => writer().update('lists', ids.inbox, {'order_by': 'created', 'group_by': 'tag'}));
    await tester.pumpWidget(app());
    await settle(tester);

    await openDialog(tester);
    expect(tester.widget<DropdownButton<dynamic>>(find.byKey(const Key('orderByField'))).value.toString(), 'TaskOrder.created');
    expect(tester.widget<DropdownButton<dynamic>>(find.byKey(const Key('groupByField'))).value.toString(), 'TaskGroup.tag');
    await unmount(tester);
  });
}
