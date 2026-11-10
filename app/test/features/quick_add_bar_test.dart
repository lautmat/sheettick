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

  Future<List<Task>> tasks(WidgetTester tester) async => (await tester.runAsync(() => db.select(db.tasks).get()))!;

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('addTaskField')), text);
    await tester.pump();
  }

  /// Presses Enter in the field, the way a keyboard or the Enter key does.
  Future<void> enter(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
  }

  /// Today where the app shows it, plus [offset] days, as `YYYY-MM-DD`.
  String day(int offset) {
    final d = dayOf(const TaskDates(zone: zone).wallOf(DateTime.now())).add(Duration(days: offset));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  testWidgets('Enter creates the task with its date, tags and priority set, and the fields come out of the title', (
    tester,
  ) async {
    final inbox = await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'Send the invoice tomorrow #finance #urgent !high');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'Send the invoice');
    expect(t.listId, inbox);
    expect(t.dueAt, day(1));
    expect(t.allDay, isTrue);
    expect(t.tags, 'finance,urgent');
    expect(t.priority, 5);
    expect(find.text('Send the invoice'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('addTaskField'))).controller!.text, isEmpty);
    await unmount(tester);
  });

  testWidgets('the add button does the same as Enter', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'Pay rent in 3 days');
    await tester.tap(find.byKey(const Key('addTaskButton')));
    await settle(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'Pay rent');
    expect(t.dueAt, day(3));
    await unmount(tester);
  });

  testWidgets('French works too', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'Envoyer la facture demain #travail !haute');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'Envoyer la facture');
    expect(t.dueAt, day(1));
    expect(t.tags, 'travail');
    expect(t.priority, 5);
    await unmount(tester);
  });

  testWidgets('a time makes a timed due on the device zone', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'Dentist tomorrow at 3pm');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'Dentist');
    expect(t.allDay, isFalse);
    expect(t.tz, zone);
    expect(t.dueAt, matches(RegExp('^${day(1)}T15:00:00\\+0[12]:00\$')));
    await unmount(tester);
  });

  testWidgets('^list puts the task in that list; without one it goes to the list on screen, the Inbox', (tester) async {
    final inbox = await seedInbox(tester);
    late String work;
    await tester.runAsync(() async => work = await writer().insert('lists', {'name': 'Work'}));
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'Report ^work');
    await enter(tester);
    await type(tester, 'Buy milk');
    await enter(tester);

    final all = await tasks(tester);
    expect(all.singleWhere((t) => t.title == 'Report').listId, work);
    expect(all.singleWhere((t) => t.title == 'Buy milk').listId, inbox);
    await unmount(tester);
  });

  testWidgets('an unknown list is not created: the task goes to the list on screen, and a note says so', (tester) async {
    final inbox = await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'Call Sam ^Nowhere');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'Call Sam');
    expect(t.listId, inbox);
    expect(find.textContaining('There is no list called "Nowhere"'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.lists).get()), hasLength(1));
    await unmount(tester);
  });

  testWidgets('a repeat is stored as a rule', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'Water the plants every day');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.rrule, 'RRULE:FREQ=DAILY');
    expect(t.dueAt, day(0));
    await unmount(tester);
  });

  testWidgets('plain text is a plain task, as before', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, '  Buy milk and eggs ');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'Buy milk and eggs');
    expect(t.dueAt, isNull);
    expect(t.tags, '');
    expect(t.priority, 0);
    await unmount(tester);
  });

  testWidgets('text that is only a date is kept as the title', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'tomorrow');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'tomorrow');
    expect(t.dueAt, isNull);
    await unmount(tester);
  });

  testWidgets('a preview under the field says what the text will become, and goes away for plain text', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byKey(const Key('quickAddPreview')), findsNothing);

    await type(tester, 'Report friday #work ^Office !high');
    final preview = tester.widget<Text>(find.byKey(const Key('quickAddPreview'))).data!;
    expect(preview, contains('#work'));
    expect(preview, contains('^Office'));
    expect(preview, contains('High priority'));

    await type(tester, 'Report for Friday morning meeting');
    // "Friday" alone is a date, so the preview stays; text with nothing recognised shows none.
    await type(tester, 'Plan the offsite');
    expect(find.byKey(const Key('quickAddPreview')), findsNothing);
    await unmount(tester);
  });
}
