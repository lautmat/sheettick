import 'dart:ui' show PointerDeviceKind;

import 'package:drift/drift.dart' as drift show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
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
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftLocalStore store;
  late String inbox;
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

  Future<String> seedList(WidgetTester tester, String name, {bool isInbox = false}) async {
    late String id;
    await tester.runAsync(() async => id = await writer().insert('lists', {'name': name, 'is_inbox': isInbox}));
    return id;
  }

  Future<String> seedTask(WidgetTester tester, String title, [Map<String, Object?> fields = const {}]) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('tasks', {'list_id': inbox, 'title': title, ...fields});
    });
    return id;
  }

  Future<Task> row(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle()))!;

  double top(WidgetTester tester, String id) => tester.getTopLeft(find.byKey(ValueKey(id))).dy;

  /// Drags the middle of [from] to the middle of [to] and lets go. A finger holds first, as a long press.
  Future<void> drag(WidgetTester tester, Finder from, Finder to, {required bool touch, bool release = true}) async {
    final start = tester.getCenter(from);
    final gesture = await tester.startGesture(start, kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse);
    if (touch) await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 12));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(to));
    await tester.pump();
    if (release) {
      await gesture.up();
      await settle(tester);
    } else {
      _held = gesture;
    }
  }

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
  }

  setUp(() {
    inbox = '';
    _held = null;
  });

  Future<void> seedInbox(WidgetTester tester) async => inbox = await seedList(tester, 'Inbox', isInbox: true);

  testWidgets('long-press and drag reorders the list, and Undo puts it back', (tester) async {
    await seedInbox(tester);
    final a = await seedTask(tester, 'A');
    final b = await seedTask(tester, 'B');
    final c = await seedTask(tester, 'C');
    await boot(tester);
    expect([top(tester, a), top(tester, b), top(tester, c)], isSorted);

    await drag(tester, find.byKey(ValueKey(c)), find.byKey(ValueKey(a)), touch: true);

    expect(top(tester, c), lessThan(top(tester, a)));
    expect(top(tester, a), lessThan(top(tester, b)));
    expect(find.text('Task reordered'), findsOneWidget);
    expect((await row(tester, c)).sortOrder, lessThan((await row(tester, a)).sortOrder));
    expect((await row(tester, c)).version, 2, reason: 'a write through the local writer, so it syncs');

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect([top(tester, a), top(tester, b), top(tester, c)], isSorted);

    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a finger that moves without holding scrolls instead of dragging', (tester) async {
    await seedInbox(tester);
    final a = await seedTask(tester, 'A');
    final b = await seedTask(tester, 'B');
    await boot(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(ValueKey(a))));
    await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(b))));
    await gesture.up();
    await settle(tester);

    expect(top(tester, a), lessThan(top(tester, b)));
    expect((await row(tester, a)).version, 1);
    expect(find.text('Task reordered'), findsNothing);

    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('with the mouse a task is dragged at once, no long press', (tester) async {
    await seedInbox(tester);
    final a = await seedTask(tester, 'A');
    final b = await seedTask(tester, 'B');
    final c = await seedTask(tester, 'C');
    await boot(tester);

    await drag(tester, find.byKey(ValueKey(a)), find.byKey(ValueKey(c)), touch: false);

    expect([top(tester, b), top(tester, a), top(tester, c)], isSorted);

    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('dropping on a section heading puts the task at the top of that section', (tester) async {
    await seedInbox(tester);
    late String home;
    await tester.runAsync(() async => home = await writer().insert('sections', {'list_id': inbox, 'name': 'Home'}));
    final x = await seedTask(tester, 'X', {'section_id': home, 'sort_order': 1});
    final loose = await seedTask(tester, 'Loose');
    await boot(tester);

    await drag(tester, find.byKey(ValueKey(loose)), find.byKey(Key('section-$home')), touch: false);

    expect((await row(tester, loose)).sectionId, home);
    expect(top(tester, loose), lessThan(top(tester, x)));
    expect(find.text('Task moved'), findsOneWidget);

    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('while a task is dragged, "No section" appears above the first heading and takes it out of its section',
      (tester) async {
    await seedInbox(tester);
    late String home;
    await tester.runAsync(() async => home = await writer().insert('sections', {'list_id': inbox, 'name': 'Home'}));
    final x = await seedTask(tester, 'X', {'section_id': home});
    await boot(tester);
    expect(find.text('No section'), findsNothing, reason: 'the drop spot shows only while dragging');

    await drag(tester, find.byKey(ValueKey(x)), find.byKey(Key('section-$home')), touch: false, release: false);
    expect(find.text('No section'), findsOneWidget);
    await _held!.moveTo(tester.getCenter(find.byKey(const Key('dropNoSection'))));
    await tester.pump();
    await _held!.up();
    await settle(tester);

    expect((await row(tester, x)).sectionId, isNull);
    expect(find.text('No section'), findsNothing, reason: 'the drop spot is gone once the drag is over');

    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('dropping on a list in the sidebar moves the task and its subtasks there', (tester) async {
    await seedInbox(tester);
    final work = await seedList(tester, 'Work');
    final parent = await seedTask(tester, 'Parent');
    final child = await seedTask(tester, 'Child', {'parent_id': parent});
    await boot(tester);

    await drag(tester, find.byKey(ValueKey(parent)), find.byKey(Key('list-$work')), touch: false);

    expect((await row(tester, parent)).listId, work);
    expect((await row(tester, child)).listId, work);
    expect(find.byKey(ValueKey(parent)), findsNothing, reason: 'it left the Inbox');
    expect(find.text('Moved to Work'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await row(tester, parent)).listId, inbox);
    expect((await row(tester, child)).listId, inbox);

    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Move to list in the task menu does the same, for a phone whose sidebar is a drawer', (tester) async {
    await seedInbox(tester);
    final work = await seedList(tester, 'Work');
    final a = await seedTask(tester, 'A');
    await boot(tester);

    await tester.tap(find.byKey(Key('taskMenu-$a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to list'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('moveTo-$inbox')), findsNothing, reason: 'it is in the Inbox already');
    await tester.tap(find.byKey(Key('moveTo-$work')));
    await settle(tester);

    expect((await row(tester, a)).listId, work);
    expect(find.text('Moved to Work'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a list sorted by something other than its own order cannot be reordered by dropping', (tester) async {
    await seedInbox(tester);
    await tester.runAsync(() => writer().update('lists', inbox, {'order_by': 'title'}));
    final a = await seedTask(tester, 'A');
    final b = await seedTask(tester, 'B');
    final c = await seedTask(tester, 'C');
    await boot(tester);

    await drag(tester, find.byKey(ValueKey(c)), find.byKey(ValueKey(a)), touch: false);

    expect([top(tester, a), top(tester, b), top(tester, c)], isSorted);
    expect((await row(tester, c)).version, 1);

    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}

/// The pointer of a drag that has not been released yet.
TestGesture? _held;

/// Matches a list of numbers in ascending order.
final isSorted = predicate<List<double>>((l) {
  for (var i = 1; i < l.length; i++) {
    if (l[i] <= l[i - 1]) return false;
  }
  return true;
}, 'is in ascending order');
