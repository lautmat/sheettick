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
import 'package:sheettick/core/theme/theme_choice.dart';
import 'package:sheettick/features/common/theme.dart';

import '../support/fake_auth_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

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
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// The brightness the page is drawn in.
  Brightness shown(WidgetTester tester) => Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

  Future<void> pick(WidgetTester tester, String choice) async {
    await tester.tap(find.byKey(const Key('themeMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('theme-$choice')));
    await settle(tester);
  }

  Future<String?> stored(WidgetTester tester) async =>
      await tester.runAsync<String?>(() => db.getDeviceState(DeviceStateKeys.themeChoice));

  testWidgets('by default the theme follows the system, light or dark', (tester) async {
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(app());
    await settle(tester);
    expect(shown(tester), Brightness.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await settle(tester);
    expect(shown(tester), Brightness.dark);
    expect(await stored(tester), isNull, reason: 'following the system stores nothing');

    await unmount(tester);
  });

  testWidgets('a manual choice beats the system, and System goes back to following it', (tester) async {
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(app());
    await settle(tester);

    await pick(tester, 'dark');
    expect(shown(tester), Brightness.dark);
    expect(await stored(tester), 'dark');

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await pick(tester, 'light');
    expect(shown(tester), Brightness.light, reason: 'light stays light while the system is dark');
    expect(await stored(tester), 'light');

    await pick(tester, 'system');
    expect(shown(tester), Brightness.dark);
    expect(await stored(tester), 'system');

    await unmount(tester);
  });

  testWidgets('the menu ticks the current choice', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await pick(tester, 'dark');

    await tester.tap(find.byKey(const Key('themeMenu')));
    await tester.pumpAndSettle();
    final checked = tester
        .widgetList<CheckedPopupMenuItem<ThemeChoice>>(find.byType(CheckedPopupMenuItem<ThemeChoice>))
        .where((i) => i.checked)
        .map((i) => i.value);
    expect(checked, [ThemeChoice.dark]);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('the choice is kept on this device and is not a Sheet row', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await pick(tester, 'dark');
    await unmount(tester);

    // A restart: a new app over the same database.
    await tester.pumpWidget(app());
    await settle(tester);
    expect(shown(tester), Brightness.dark);

    // Nothing waits to be pushed to the Sheet: the choice is not a row of any tab.
    final waiting = await tester.runAsync(
      () => DriftLocalStore(db).dirtyCount(['tasks', 'lists', 'folders', 'sections', 'checklist', 'tags']),
    );
    expect(waiting, 0);
    await unmount(tester);
  });

  test('both themes are built, one light and one dark', () {
    expect(appTheme(Brightness.light).brightness, Brightness.light);
    expect(appTheme(Brightness.dark).brightness, Brightness.dark);
    expect(
      appTheme(Brightness.dark).colorScheme.surface,
      isNot(appTheme(Brightness.light).colorScheme.surface),
    );
  });
}
