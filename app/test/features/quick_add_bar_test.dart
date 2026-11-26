import 'dart:ui' show PointerDeviceKind;

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

  testWidgets('a task typed with no date is due today, all day', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'Buy milk');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'Buy milk');
    expect(t.dueAt, day(0));
    expect(t.allDay, isTrue);
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

  testWidgets('plain text is a plain task for today', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, '  Buy milk and eggs ');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'Buy milk and eggs');
    expect(t.dueAt, day(0));
    expect(t.tags, '');
    expect(t.priority, 0);
    await unmount(tester);
  });

  testWidgets('text that is only a date is kept as the title, and the task is for today', (tester) async {
    await seedInbox(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await type(tester, 'tomorrow');
    await enter(tester);

    final t = (await tasks(tester)).single;
    expect(t.title, 'tomorrow');
    expect(t.dueAt, day(0));
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

  group('the chips under the field', () {
    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byKey(const Key('addTaskField'))).controller!.text;

    bool lit(WidgetTester tester, String key) => tester.widget<FilterChip>(find.byKey(Key(key))).selected;

    Future<void> tapChip(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }

    /// Opens the menu of the chip [key] and taps [item] in it.
    Future<void> choose(WidgetTester tester, String key, Finder item) async {
      // The row scrolls sideways, so a chip at its end may be out of sight.
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pump();
      await tester.tap(find.byKey(Key(key)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(item);
      await settle(tester);
    }

    Future<void> start(WidgetTester tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
    }

    testWidgets('they show only while the field is in use', (tester) async {
      await seedInbox(tester);
      await start(tester);
      expect(find.byKey(const Key('chipToday')), findsNothing);

      await tester.tap(find.byKey(const Key('addTaskField')));
      await tester.pump();

      expect(find.byKey(const Key('chipToday')), findsOneWidget);
      expect(find.byKey(const Key('chipTomorrow')), findsOneWidget);
      expect(find.byKey(const Key('chipPriority')), findsOneWidget);
      expect(find.byKey(const Key('chipList')), findsOneWidget);
      expect(find.byKey(const Key('chipTag')), findsNothing, reason: 'there are no tags to offer yet');
      await unmount(tester);
    });

    testWidgets('on Windows a mouse click on a chip lands, on an empty field too', (tester) async {
      await seedInbox(tester);
      await start(tester);
      await tester.tap(find.byKey(const Key('addTaskField')), kind: PointerDeviceKind.mouse);
      await tester.pump();

      // A real click has frames between the button going down and up; `tap` has none, and would not show a chip that
      // goes away under the pointer.
      final click = await tester.startGesture(tester.getCenter(find.byKey(const Key('chipTomorrow'))), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await click.up();
      await tester.pump();

      expect(fieldText(tester), 'tomorrow ');
      expect(find.byKey(const Key('chipTomorrow')), findsOneWidget);
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('Today and Tomorrow write the day into the text, swap it and take it out again', (tester) async {
      await seedInbox(tester);
      await start(tester);
      await type(tester, 'Send the report');

      await tapChip(tester, 'chipTomorrow');
      expect(fieldText(tester), 'Send the report tomorrow');
      expect(lit(tester, 'chipTomorrow'), isTrue);
      expect(lit(tester, 'chipToday'), isFalse);
      expect(find.byKey(const Key('quickAddPreview')), findsOneWidget);

      await tapChip(tester, 'chipToday');
      expect(fieldText(tester), 'Send the report today');
      expect(lit(tester, 'chipToday'), isTrue);
      expect(lit(tester, 'chipTomorrow'), isFalse);

      await tapChip(tester, 'chipToday');
      expect(fieldText(tester), 'Send the report');
      expect(lit(tester, 'chipToday'), isFalse);
      expect(find.byKey(const Key('quickAddPreview')), findsNothing);

      await tapChip(tester, 'chipTomorrow');
      await enter(tester);
      final t = (await tasks(tester)).single;
      expect(t.title, 'Send the report');
      expect(t.dueAt, day(1));
      await unmount(tester);
    });

    testWidgets('a chip tapped before the title lights up, and can be tapped off again', (tester) async {
      await seedInbox(tester);
      await start(tester);
      await tester.tap(find.byKey(const Key('addTaskField')));
      await tester.pump();

      await tapChip(tester, 'chipTomorrow');
      expect(fieldText(tester), 'tomorrow ');
      expect(lit(tester, 'chipTomorrow'), isTrue);

      await tapChip(tester, 'chipTomorrow');
      expect(fieldText(tester), isEmpty);
      expect(lit(tester, 'chipTomorrow'), isFalse);
      await unmount(tester);
    });

    testWidgets('a menu choice lands even when the field is empty, and the chips stay', (tester) async {
      await seedInbox(tester);
      await start(tester);
      await tester.tap(find.byKey(const Key('addTaskField')));
      await tester.pump();

      await choose(tester, 'chipPriority', find.widgetWithText(PopupMenuItem<int>, 'High'));

      expect(fieldText(tester), '!high ');
      expect(find.byKey(const Key('chipPriority')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Priority and Tag write their token, replace it, and the ticked choice takes it out', (tester) async {
      await seedInbox(tester);
      await tester.runAsync(() => writer().insert('tags', {'name': 'errands', 'sort_order': 1.0}));
      await start(tester);
      await type(tester, 'Buy milk');

      Finder priority(String label) => find.widgetWithText(PopupMenuItem<int>, label);
      await choose(tester, 'chipPriority', priority('High'));
      expect(fieldText(tester), 'Buy milk !high');
      await choose(tester, 'chipPriority', priority('Low'));
      expect(fieldText(tester), 'Buy milk !low');
      await choose(tester, 'chipPriority', priority('Low'));
      expect(fieldText(tester), 'Buy milk');

      final errands = find.widgetWithText(PopupMenuItem<String>, '#errands');
      await choose(tester, 'chipTag', errands);
      expect(fieldText(tester), 'Buy milk #errands');
      await choose(tester, 'chipTag', errands);
      expect(fieldText(tester), 'Buy milk');

      await choose(tester, 'chipTag', errands);
      await choose(tester, 'chipPriority', priority('Medium'));
      await enter(tester);
      final t = (await tasks(tester)).single;
      expect(t.title, 'Buy milk');
      expect(t.tags, 'errands');
      expect(t.priority, 3);
      await unmount(tester);
    });

    testWidgets('List writes ^list, quoted when it has spaces, and the task goes there', (tester) async {
      await seedInbox(tester);
      late String projects;
      await tester.runAsync(() async => projects = await writer().insert('lists', {'name': 'Home projects', 'is_inbox': false}));
      await start(tester);
      await type(tester, 'Fix the tap');

      await choose(tester, 'chipList', find.widgetWithText(PopupMenuItem<String>, 'Home projects'));
      expect(fieldText(tester), 'Fix the tap ^"Home projects"');

      await enter(tester);
      final t = (await tasks(tester)).single;
      expect(t.title, 'Fix the tap');
      expect(t.listId, projects);
      await unmount(tester);
    });
  });
}
