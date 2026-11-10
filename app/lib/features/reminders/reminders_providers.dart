import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/reminders/reminder_planner.dart';

/// Every task row. Reminders are planned from the local database, so a task changed by this device, by a sync or by
/// hand in the Sheet all end up in the same plan (`docs/sync-protocol.md`, step 6).
final allTasksProvider = StreamProvider<List<Task>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.tasks).watch();
});

/// How far back a reminder still counts when the app was closed or asleep, and how far ahead it is planned.
const _lookBack = Duration(hours: 24);
const _lookAhead = Duration(days: 90);

/// How often the plan is made again with no change, so a reminder that came into the look-ahead window is planned.
const _refresh = Duration(hours: 1);

/// Keeps the platform's reminders in step with the tasks: plans them whenever a task changes and hands the plan to the
/// scheduler. Watched once, by the app.
final remindersBindingProvider = Provider<void>((ref) {
  final scheduler = ref.watch(reminderSchedulerProvider);

  void apply() {
    final tasks = ref.read(allTasksProvider).value;
    final zone = ref.read(deviceZoneProvider);
    if (tasks == null || zone.isLoading) return;
    final now = DateTime.now();
    final plan = planReminders(
      tasks,
      after: now.subtract(_lookBack),
      until: now.add(_lookAhead),
      deviceZone: zone.value,
    );
    unawaited(scheduler.replaceAll(plan, now));
  }

  ref.listen(allTasksProvider, (_, _) => apply(), fireImmediately: true);
  ref.listen(deviceZoneProvider, (_, _) => apply());
  final timer = Timer.periodic(_refresh, (_) => apply());
  ref.onDispose(timer.cancel);
});
