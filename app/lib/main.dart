import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/reminders/platform_reminders.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        // Tests keep the default (no notifications); the app shows real ones.
        reminderSchedulerProvider.overrideWith((ref) {
          final scheduler = PlatformReminderScheduler(ref.watch(appDatabaseProvider));
          ref.onDispose(scheduler.dispose);
          return scheduler;
        }),
      ],
      child: const SheetTickApp(),
    ),
  );
}
