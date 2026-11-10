import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/reminders/reminder_planner.dart';
import '../../core/reminders/snooze.dart';

/// Every task row. Reminders are planned from the local database, so a task changed by this device, by a sync or by
/// hand in the Sheet all end up in the same plan (`docs/sync-protocol.md`, step 6).
final allTasksProvider = StreamProvider<List<Task>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.tasks).watch();
});

/// Counts the times something other than a task changed the plan: a reminder was snoozed, or the app came back to the
/// front (a snooze may have been made on the notification with the app closed). The plan is made again on each change.
class PlanRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final planRevisionProvider = NotifierProvider<PlanRevision, int>(PlanRevision.new);

/// How far back a reminder still counts when the app was closed or asleep, and how far ahead it is planned.
const _lookBack = Duration(hours: 24);
const _lookAhead = Duration(days: 90);

/// How often the plan is made again with no change, so a reminder that came into the look-ahead window is planned.
const _refresh = Duration(hours: 1);

/// Keeps the platform's reminders in step with the tasks: plans them whenever a task changes and hands the plan to the
/// scheduler. Watched once, by the app.
final remindersBindingProvider = Provider<void>((ref) {
  final scheduler = ref.watch(reminderSchedulerProvider);

  var generation = 0;

  Future<void> apply() async {
    final tasks = ref.read(allTasksProvider).value;
    final zone = ref.read(deviceZoneProvider);
    if (tasks == null || zone.isLoading) return;
    final mine = ++generation;
    // Read fresh each time: a snooze made on the notification with the app closed was written by another isolate.
    final snoozes = await snoozeStoreOf(ref.read(appDatabaseProvider)).load();
    // A newer plan started while this one waited: it has the later tasks, so this one is dropped.
    if (mine != generation) return;
    final now = DateTime.now();
    final plan = planReminders(
      tasks,
      after: now.subtract(_lookBack),
      until: now.add(_lookAhead),
      deviceZone: zone.value,
      snoozes: snoozes,
    );
    await scheduler.replaceAll(plan, now);
  }

  ref.listen(allTasksProvider, (_, _) => unawaited(apply()), fireImmediately: true);
  ref.listen(deviceZoneProvider, (_, _) => unawaited(apply()));
  ref.listen(planRevisionProvider, (_, _) => unawaited(apply()));
  final timer = Timer.periodic(_refresh, (_) => unawaited(apply()));
  ref.onDispose(timer.cancel);
});
