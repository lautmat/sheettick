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
import 'package:sheettick/features/desktop/desktop_providers.dart';

import '../support/fake_auth_service.dart';
import '../support/fake_desktop_shell.dart';
import '../support/fake_sheets_backend.dart';

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

  Widget app({FakeDesktopShell? shell, FakeSheetsBackend? backend}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWith((ref) => 'win-test'),
        authServiceProvider.overrideWithValue(FakeAuthService(restored: backend == null ? null : FakeAuthService.session())),
        if (backend != null) backendFactoryProvider.overrideWithValue((_) => backend),
        if (shell != null) desktopShellProvider.overrideWithValue(shell),
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

  Future<String> seedInbox(WidgetTester tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await writer().insert('lists', {'name': 'Inbox', 'is_inbox': true});
    });
    return id;
  }

  bool addFieldHasFocus(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('addTaskField'))).focusNode!.hasFocus;

  group('without a desktop shell (Android, tests)', () {
    testWidgets('nothing starts and the Windows menu is not shown', (tester) async {
      await seedInbox(tester);
      await tester.pumpWidget(app());
      await settle(tester);
      expect(find.byKey(const Key('desktopMenu')), findsNothing);
      expect(find.byKey(const Key('addTaskField')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('the shell is started and wired to the app', () {
    testWidgets('started once, with the tray actions', (tester) async {
      await seedInbox(tester);
      final shell = FakeDesktopShell();
      await tester.pumpWidget(app(shell: shell));
      await settle(tester);
      expect(shell.starts, 1);

      shell.callbacks!.onOpen();
      await settle(tester);
      expect(shell.shows, 1);

      shell.callbacks!.onQuit();
      await settle(tester);
      expect(shell.quits, 1);
      await unmount(tester);
    });

    testWidgets('Sync now in the tray runs a sync cycle', (tester) async {
      await seedInbox(tester);
      final shell = FakeDesktopShell();
      final backend = FakeSheetsBackend();
      await tester.pumpWidget(app(shell: shell, backend: backend));
      await settle(tester);
      await settle(tester);
      backend.calls.clear();
      await tester.runAsync(() async {
        await writer().insert('tasks', {'title': 'edited in the tray test'});
      });

      shell.callbacks!.onSyncNow();
      await settle(tester);
      await settle(tester);
      expect(backend.calls.values.fold<int>(0, (a, b) => a + b), greaterThan(0), reason: 'the cycle talked to the Sheet');
      await unmount(tester);
    });
  });

  group('the quick-add hotkey', () {
    testWidgets('brings the window forward and focuses the add bar', (tester) async {
      await seedInbox(tester);
      final shell = FakeDesktopShell();
      await tester.pumpWidget(app(shell: shell));
      await settle(tester);
      expect(addFieldHasFocus(tester), isFalse);

      shell.callbacks!.onQuickAdd();
      await settle(tester);

      expect(shell.shows, 1);
      expect(addFieldHasFocus(tester), isTrue);
      await unmount(tester);
    });

    testWidgets('pressed again after the focus moved away, it focuses the bar again', (tester) async {
      await seedInbox(tester);
      final shell = FakeDesktopShell();
      await tester.pumpWidget(app(shell: shell));
      await settle(tester);
      shell.callbacks!.onQuickAdd();
      await settle(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(addFieldHasFocus(tester), isFalse);

      shell.callbacks!.onQuickAdd();
      await settle(tester);
      expect(addFieldHasFocus(tester), isTrue);
      await unmount(tester);
    });

    testWidgets('from a smart list, which has no add bar, it goes back to the list and focuses the bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await seedInbox(tester);
      final shell = FakeDesktopShell();
      await tester.pumpWidget(app(shell: shell));
      await settle(tester);
      await tester.tap(find.byKey(const Key('smart-today')));
      await settle(tester);
      expect(find.byKey(const Key('addTaskField')), findsNothing);

      shell.callbacks!.onQuickAdd();
      await settle(tester);
      expect(find.byKey(const Key('addTaskField')), findsOneWidget);
      expect(addFieldHasFocus(tester), isTrue);
      await unmount(tester);
    });

    testWidgets('with a task open on top of the list, it closes the page first', (tester) async {
      final inbox = await seedInbox(tester);
      await tester.runAsync(() => writer().insert('tasks', {'list_id': inbox, 'title': 'open me'}));
      final shell = FakeDesktopShell();
      await tester.pumpWidget(app(shell: shell));
      await settle(tester);
      await tester.tap(find.text('open me'));
      await animate(tester);
      await settle(tester);
      expect(find.byKey(const Key('taskTitleField')), findsOneWidget);

      shell.callbacks!.onQuickAdd();
      await animate(tester);
      await settle(tester);
      expect(find.byKey(const Key('taskTitleField')), findsNothing);
      expect(addFieldHasFocus(tester), isTrue);
      await unmount(tester);
    });

    testWidgets('what is typed afterwards is added as a task', (tester) async {
      await seedInbox(tester);
      final shell = FakeDesktopShell();
      await tester.pumpWidget(app(shell: shell));
      await settle(tester);
      shell.callbacks!.onQuickAdd();
      await settle(tester);

      await tester.enterText(find.byKey(const Key('addTaskField')), 'call Sam');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      final tasks = await tester.runAsync(() => db.select(db.tasks).get());
      expect(tasks!.map((t) => t.title), ['call Sam']);
      await unmount(tester);
    });
  });

  group('Start with Windows', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('desktopMenu')));
      await animate(tester);
    }

    testWidgets('shows what the system says and turns it on', (tester) async {
      await seedInbox(tester);
      final shell = FakeDesktopShell(startup: false);
      await tester.pumpWidget(app(shell: shell));
      await settle(tester);

      await openMenu(tester);
      expect(tester.widget<CheckedPopupMenuItem<bool>>(find.byKey(const Key('startWithWindows'))).checked, isFalse);
      expect(find.textContaining('Ctrl+Alt+N'), findsOneWidget);
      await tester.tap(find.byKey(const Key('startWithWindows')));
      await animate(tester);
      await settle(tester);
      expect(shell.startup, isTrue);

      await openMenu(tester);
      expect(tester.widget<CheckedPopupMenuItem<bool>>(find.byKey(const Key('startWithWindows'))).checked, isTrue);
      await unmount(tester);
    });

    testWidgets('turns it off again', (tester) async {
      await seedInbox(tester);
      final shell = FakeDesktopShell(startup: true);
      await tester.pumpWidget(app(shell: shell));
      await settle(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('startWithWindows')));
      await animate(tester);
      await settle(tester);
      expect(shell.startup, isFalse);
      await unmount(tester);
    });

    testWidgets('when Windows refuses, the user is told and the setting stays as it was', (tester) async {
      await seedInbox(tester);
      final shell = FakeDesktopShell(startup: false, failStartupChange: StateError('Could not turn on Start with Windows: Access is denied.'));
      await tester.pumpWidget(app(shell: shell));
      await settle(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('startWithWindows')));
      await animate(tester);
      await settle(tester);
      expect(find.textContaining('Access is denied'), findsOneWidget);
      expect(shell.startup, isFalse);
      await unmount(tester);
    });
  });
}
