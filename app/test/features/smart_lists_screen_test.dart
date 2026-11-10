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

  /// `YYYY-MM-DD` for today plus [offset] days, on the machine's clock (the test zone is the one the app reads).
  String day(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> open(WidgetTester tester, String smart) async {
    await tester.tap(find.byKey(Key('smart-$smart')));
    await settle(tester);
  }

  /// Seeds the Inbox, a second list and tasks covering every smart list.
  Future<Map<String, String>> seed(WidgetTester tester) async {
    final ids = <String, String>{};
    await tester.runAsync(() async {
      final w = writer();
      final inbox = await w.insert('lists', {'name': 'Inbox', 'is_inbox': true});
      final work = await w.insert('lists', {'name': 'Work'});
      final old = await w.insert('lists', {'name': 'Old', 'archived': true});
      Future<void> task(String title, Map<String, Object?> fields, {String? list, bool trash = false}) async {
        final id = await w.insert('tasks', {'title': title, 'list_id': list ?? inbox, ...fields});
        if (trash) await w.delete('tasks', id);
        ids[title] = id;
      }

      await task('Due today', {'due_at': day(0), 'all_day': true});
      await task('Overdue', {'due_at': day(-3), 'all_day': true});
      await task('Due tomorrow', {'due_at': day(1), 'all_day': true}, list: work);
      await task('Due in five days', {'due_at': day(5), 'all_day': true});
      await task('Due next month', {'due_at': day(30), 'all_day': true});
      await task('No date', {});
      await task('Finished', {'status': 2, 'completed_at': '2026-01-01T08:00:00Z'});
      await task('Dropped', {'status': -1});
      await task('Binned', {'due_at': day(0), 'all_day': true}, trash: true);
      await task('In archived list', {'due_at': day(0), 'all_day': true}, list: old);
    });
    return ids;
  }

  Set<String> shown(WidgetTester tester, Iterable<String> titles) => {
    for (final t in titles)
      if (find.text(t).evaluate().isNotEmpty) t,
  };

  const everything = [
    'Due today',
    'Overdue',
    'Due tomorrow',
    'Due in five days',
    'Due next month',
    'No date',
    'Finished',
    'Dropped',
    'Binned',
    'In archived list',
  ];

  testWidgets('each smart list shows exactly its own rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await open(tester, 'today');
    expect(shown(tester, everything), {'Due today', 'Overdue'});
    await open(tester, 'tomorrow');
    expect(shown(tester, everything), {'Due tomorrow'});
    await open(tester, 'next7Days');
    expect(shown(tester, everything), {'Due today', 'Due tomorrow', 'Due in five days'});
    await open(tester, 'all');
    expect(shown(tester, everything), {
      'Due today',
      'Overdue',
      'Due tomorrow',
      'Due in five days',
      'Due next month',
      'No date',
    });
    await open(tester, 'completed');
    expect(shown(tester, everything), {'Finished'});
    await open(tester, 'wontDo');
    expect(shown(tester, everything), {'Dropped'});
    await open(tester, 'trash');
    expect(shown(tester, everything), {'Binned'});
    await unmount(tester);
  });

  testWidgets('a smart list has no add bar, and a list in the sidebar takes the screen back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byKey(const Key('addTaskField')), findsOneWidget);

    await open(tester, 'today');
    expect(find.byKey(const Key('addTaskField')), findsNothing);

    final inbox = (await tester.runAsync(() => (db.select(db.lists)..where((l) => l.isInbox.equals(true))).getSingle()))!;
    await tester.tap(find.byKey(Key('list-${inbox.id}')));
    await settle(tester);
    expect(find.byKey(const Key('addTaskField')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an empty smart list says so', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() => writer().insert('lists', {'name': 'Inbox', 'is_inbox': true}));
    await tester.pumpWidget(app());
    await settle(tester);

    await open(tester, 'trash');
    expect(find.text('The Trash is empty.'), findsOneWidget);
    await open(tester, 'today');
    expect(find.text('Nothing due today.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Restore takes a task out of the Trash and puts it back in its list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await open(tester, 'trash');
    await tester.tap(find.byKey(Key('restore-${ids['Binned']}')));
    await settle(tester);

    expect(find.text('Binned'), findsNothing);
    expect(find.text('The Trash is empty.'), findsOneWidget);
    final row = (await tester.runAsync(() => (db.select(db.tasks)..where((t) => t.id.equals(ids['Binned']!))).getSingle()))!;
    expect(row.deleted, isFalse);
    expect(row.version, 3); // created, trashed, restored: each write bumps the version
    await open(tester, 'today');
    expect(find.text('Binned'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('finishing a task from Today moves it to Completed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await open(tester, 'today');
    await tester.tap(find.byKey(Key('taskCheck-${ids['Due today']}')));
    await settle(tester);
    expect(find.text('Due today'), findsNothing);
    await open(tester, 'completed');
    expect(shown(tester, everything), {'Finished', 'Due today'});
    await unmount(tester);
  });
}
