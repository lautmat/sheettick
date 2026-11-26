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
import 'package:sheettick/core/tasks/task_dates.dart';

import '../support/fake_auth_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const zone = 'Europe/Paris';

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
      deviceZoneProvider.overrideWith((ref) async => zone),
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

  Future<void> seedInbox(WidgetTester tester) async {
    inbox = await insert(tester, 'lists', {'name': 'Inbox', 'is_inbox': true});
  }

  Future<String> seedTask(WidgetTester tester, String title, [Map<String, Object?> fields = const {}]) =>
      insert(tester, 'tasks', {'list_id': inbox, 'title': title, ...fields});

  String today() {
    final d = dayOf(const TaskDates(zone: zone).wallOf(DateTime.now()));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// The words on the second line of the row of [id], without the date and the marks, which are widgets in the line.
  String details(WidgetTester tester, String id) => tester
      .widget<Text>(find.byKey(Key('taskDetails-$id')))
      .textSpan!
      .toPlainText(includeSemanticsLabels: false, includePlaceholders: false)
      .trim();

  Finder onRow(String id, IconData icon) => find.descendant(of: find.byKey(ValueKey(id)), matching: find.byIcon(icon));

  const marks = [Icons.checklist, Icons.account_tree_outlined, Icons.alarm, Icons.repeat, Icons.notes];

  testWidgets('a row says how far the checklist is, how many subtasks there are, and marks a reminder, repeat and note', (
    tester,
  ) async {
    await seedInbox(tester);
    final full = await seedTask(tester, 'Full', {
      'due_at': today(),
      'all_day': true,
      'reminders': '["TRIGGER:PT9H"]',
      'rrule': 'RRULE:FREQ=DAILY',
      'content': 'Bring the form',
    });
    final items = [
      for (var i = 0; i < 5; i++)
        await insert(tester, 'checklist', {'task_id': full, 'title': 'item $i', 'status': i < 2 ? 2 : 0}),
    ];
    await seedTask(tester, 'Child one', {'parent_id': full});
    await seedTask(tester, 'Child two', {'parent_id': full, 'status': 2});
    final plain = await seedTask(tester, 'Plain');
    await start(tester);

    expect(find.byKey(Key('taskDue-$full')), findsOneWidget);
    expect(details(tester, full), matches(RegExp(r'^2/5\s+2$')), reason: 'the checklist, then the two subtasks');
    for (final icon in marks) {
      expect(onRow(full, icon), findsOneWidget, reason: '$icon');
      expect(onRow(plain, icon), findsNothing, reason: '$icon');
    }
    expect(find.byKey(Key('taskDetails-$plain')), findsNothing);
    expect(tester.widget<ListTile>(find.descendant(of: find.byKey(ValueKey(plain)), matching: find.byType(ListTile))).subtitle, isNull);

    // Ticking an item moves the count on the row.
    await tester.runAsync(() => writer().update('checklist', items[2], {'status': 2}));
    await settle(tester);
    expect(details(tester, full), startsWith('3/5'));
    await unmount(tester);
  });

  testWidgets('a smart list names each task\'s list; the list itself does not', (tester) async {
    await seedInbox(tester);
    final work = await insert(tester, 'lists', {'name': 'Work things', 'is_inbox': false});
    final a = await seedTask(tester, 'In the inbox', {'due_at': today(), 'all_day': true});
    final b = await insert(tester, 'tasks', {'list_id': work, 'title': 'At work', 'due_at': today(), 'all_day': true});
    await start(tester);
    expect(details(tester, a), isEmpty, reason: 'in its own list there is only the date');

    await tester.tap(find.byKey(const Key('smart-all')));
    await settle(tester);

    expect(details(tester, a), 'Inbox');
    expect(details(tester, b), 'Work things');
    await unmount(tester);
  });

  testWidgets('with everything on a phone the row stays two lines and nothing overflows', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seedInbox(tester);
    const longTitle = 'A long title that would take three or four lines on a phone if nothing held it back at all';
    final crowded = await seedTask(tester, longTitle, {
      // Timed and starting only: the longest date a row can say.
      'start_at': '2027-02-24T23:45:00+01:00',
      'tz': zone,
      'reminders': '["TRIGGER:PT0S"]',
      'rrule': 'RRULE:FREQ=DAILY',
      'content': 'note',
      'tags': 'a-rather-long-tag,another-rather-long-tag,and-one-more',
    });
    for (var i = 0; i < 12; i++) {
      await insert(tester, 'checklist', {'task_id': crowded, 'title': 'item $i', 'status': 2});
    }
    await seedTask(tester, 'Child', {'parent_id': crowded});
    final titleOnly = await seedTask(tester, '$longTitle, with nothing under it');
    await start(tester);

    expect(tester.takeException(), isNull);
    double height(String id) => tester.getSize(find.byKey(ValueKey(id))).height;
    // A Material two-line row is 72 logical pixels.
    expect(height(crowded), lessThanOrEqualTo(72));
    expect(height(titleOnly), lessThanOrEqualTo(72));
    Text title(String text) => tester.widget<Text>(find.text(text));
    expect(title(longTitle).maxLines, 1);
    expect(title('$longTitle, with nothing under it').maxLines, 2);
    await unmount(tester);
  });
}
