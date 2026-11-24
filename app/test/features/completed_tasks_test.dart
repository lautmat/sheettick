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
        authServiceProvider.overrideWithValue(FakeAuthService()),
      ],
      child: const SheetTickApp(),
    );
  }

  /// Lets queued database work and stream emissions finish, pumping a frame after each slice.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// A phone-width window: one column, no sidebar, and every row is built.
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<String> seed(WidgetTester tester, String tab, Map<String, Object?> values) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert(tab, values);
    });
    return id;
  }

  Future<String> seedInbox(WidgetTester tester, {String? groupBy}) => seed(tester, 'lists', {
    'name': 'Inbox',
    'is_inbox': true,
    'group_by': ?groupBy,
  });

  Future<String?> storedFold(WidgetTester tester) async {
    final value = await tester.runAsync(() => db.getDeviceState(DeviceStateKeys.completedCollapsed));
    return value;
  }

  Future<String> seedDone(WidgetTester tester, String listId, String title, {String? sectionId}) =>
      seed(tester, 'tasks', {
        'list_id': listId,
        'title': title,
        'status': 2,
        'completed_at': '2026-11-20T10:00:00Z',
        'section_id': ?sectionId,
      });

  double topOf(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

  final completedHeader = find.byKey(const Key('completedHeader'));

  testWidgets('completed tasks gather under a Completed heading at the foot, below the open ones', (tester) async {
    phoneSize(tester);
    final inbox = await seedInbox(tester);
    final work = await seed(tester, 'sections', {'list_id': inbox, 'name': 'Work'});
    await seedDone(tester, inbox, 'Filed done', sectionId: work);
    await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Open in work', 'section_id': work});
    await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Open loose'});
    await seedDone(tester, inbox, 'Loose done');
    await tester.pumpWidget(app());
    await settle(tester);

    expect(completedHeader, findsOneWidget);
    expect(find.descendant(of: completedHeader, matching: find.text('2')), findsOneWidget);
    // Open tasks stay in their places; the completed ones wherever they were filed sit below the heading.
    expect(topOf(tester, find.text('Open loose')), lessThan(topOf(tester, find.text('Open in work'))));
    expect(topOf(tester, find.text('Open in work')), lessThan(topOf(tester, completedHeader)));
    expect(topOf(tester, completedHeader), lessThan(topOf(tester, find.text('Filed done'))));
    expect(topOf(tester, completedHeader), lessThan(topOf(tester, find.text('Loose done'))));
    // The section counts only the tasks still open in it.
    expect(
      find.descendant(of: find.byKey(Key('section-$work')), matching: find.text('1')),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('folding the Completed heading hides its tasks, and the choice survives a restart', (tester) async {
    phoneSize(tester);
    final inbox = await seedInbox(tester);
    await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Keep me'});
    await seedDone(tester, inbox, 'Done one');
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('Done one'), findsOneWidget);

    await tester.tap(completedHeader);
    await settle(tester);
    expect(find.text('Done one'), findsNothing);
    expect(find.text('Keep me'), findsOneWidget);
    expect(completedHeader, findsOneWidget);
    expect(await storedFold(tester), 'true');

    // A restart keeps it folded.
    await unmount(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('Done one'), findsNothing);

    await tester.tap(completedHeader);
    await settle(tester);
    expect(find.text('Done one'), findsOneWidget);
    expect(await storedFold(tester), 'false');
    await unmount(tester);
  });

  testWidgets('unticking a completed task brings it back among the open tasks', (tester) async {
    phoneSize(tester);
    final inbox = await seedInbox(tester);
    final done = await seedDone(tester, inbox, 'Reopen me');
    await tester.pumpWidget(app());
    await settle(tester);
    expect(completedHeader, findsOneWidget);

    await tester.tap(find.byKey(Key('taskCheck-$done')));
    await settle(tester);

    expect(completedHeader, findsNothing);
    expect(find.text('Reopen me'), findsOneWidget);
    final row = (await tester.runAsync(() => db.select(db.tasks).get()))!.single;
    expect(row.status, 0);
    await unmount(tester);
  });

  testWidgets('a list with nothing completed has no Completed heading', (tester) async {
    phoneSize(tester);
    final inbox = await seedInbox(tester);
    await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Still open'});
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Still open'), findsOneWidget);
    expect(completedHeader, findsNothing);
    await unmount(tester);
  });

  testWidgets('a subtask stays with its parent: under an open task it stays open, under a completed one it goes below the heading', (tester) async {
    phoneSize(tester);
    final inbox = await seedInbox(tester);
    final openParent = await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Plan trip'});
    await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Book hotel', 'parent_id': openParent, 'status': 2});
    final donParent = await seedDone(tester, inbox, 'Old errand');
    await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Old errand step', 'parent_id': donParent});
    await tester.pumpWidget(app());
    await settle(tester);

    expect(topOf(tester, find.text('Plan trip')), lessThan(topOf(tester, find.text('Book hotel'))));
    expect(topOf(tester, find.text('Book hotel')), lessThan(topOf(tester, completedHeader)));
    expect(topOf(tester, completedHeader), lessThan(topOf(tester, find.text('Old errand'))));
    expect(topOf(tester, find.text('Old errand')), lessThan(topOf(tester, find.text('Old errand step'))));
    await unmount(tester);
  });

  testWidgets('grouped by priority, the completed tasks still gather at the foot', (tester) async {
    phoneSize(tester);
    final inbox = await seedInbox(tester, groupBy: 'priority');
    await seed(tester, 'tasks', {'list_id': inbox, 'title': 'Grouped open'});
    await seedDone(tester, inbox, 'Grouped done');
    await tester.pumpWidget(app());
    await settle(tester);

    expect(topOf(tester, find.text('Grouped open')), lessThan(topOf(tester, completedHeader)));
    expect(topOf(tester, completedHeader), lessThan(topOf(tester, find.text('Grouped done'))));

    await tester.tap(completedHeader);
    await settle(tester);
    expect(find.text('Grouped done'), findsNothing);
    expect(find.text('Grouped open'), findsOneWidget);
    await unmount(tester);
  });
}
