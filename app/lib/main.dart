import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/reminders/platform_reminders.dart';
import 'core/sync/background_sync_entry.dart';
import 'features/reminders/reminders_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Android only: sync every 15 minutes while the app is closed.
  unawaited(registerBackgroundSync());
  runApp(
    ProviderScope(
      overrides: [
        // Tests keep the default (no notifications); the app shows real ones.
        reminderSchedulerProvider.overrideWith((ref) {
          final scheduler = PlatformReminderScheduler(
            ref.watch(appDatabaseProvider),
            onSnoozed: () => ref.read(planRevisionProvider.notifier).bump(),
          );
          ref.onDispose(scheduler.dispose);
          return scheduler;
        }),
      ],
      child: const SheetTickApp(),
    ),
  );
}
