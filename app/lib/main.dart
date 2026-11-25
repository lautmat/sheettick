import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/desktop/desktop_shell.dart' show kStartHiddenArgument;
import 'core/desktop/platform_desktop_shell.dart';
import 'core/providers.dart';
import 'core/reminders/platform_reminders.dart';
import 'core/sync/background_sync_entry.dart';
import 'core/sync/sync_controller.dart';
import 'features/desktop/desktop_providers.dart';
import 'features/reminders/reminders_providers.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android only: sync every 15 minutes while the app is closed.
  unawaited(registerBackgroundSync());
  // Windows only: closing the window hides it to the tray, with a tray menu and a quick-add hotkey. Started by Windows at
  // sign-in (--minimized), the window stays in the tray.
  PlatformDesktopShell? desktop;
  if (Platform.isWindows) {
    desktop = PlatformDesktopShell(startHidden: args.contains(kStartHiddenArgument));
    await desktop.prepare();
  }
  runApp(
    ProviderScope(
      overrides: [
        if (desktop != null) desktopShellProvider.overrideWithValue(desktop),
        // Tests keep the default (no notifications); the app shows real ones.
        reminderSchedulerProvider.overrideWith((ref) {
          final scheduler = PlatformReminderScheduler(
            ref.watch(appDatabaseProvider),
            onSnoozed: () => ref.read(planRevisionProvider.notifier).bump(),
            onCompleted: () => ref.read(syncControllerProvider.notifier).requestSoon(),
          );
          ref.onDispose(scheduler.dispose);
          return scheduler;
        }),
      ],
      child: const SheetTickApp(),
    ),
  );
}
