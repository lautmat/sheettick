import 'dart:async';

import 'reminder_planner.dart';
import 'reminder_scheduler.dart';

/// What [AlarmReminderScheduler] needs from the platform: alarms that fire a notification at a time even when the app
/// is closed.
abstract class AlarmPort {
  Future<bool> requestPermission();

  /// Whether the system lets the app fire at an exact time. Without it alarms are inexact (some minutes late).
  Future<bool> canScheduleExact();

  /// The ids of the notifications set and not yet shown.
  Future<Set<int>> pendingIds();

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required bool exact,
  });

  Future<void> cancel(int id);
}

/// Reminders as platform alarms (Android). The plan is compared with what is already set, so a sync that changed one
/// task sets or cancels only that task's alarms.
class AlarmReminderScheduler implements ReminderScheduler {
  AlarmReminderScheduler(this._port);

  final AlarmPort _port;

  /// What each alarm set by this run shows and when, by notification id.
  final Map<int, String> _set = {};

  Future<void> _queue = Future.value();

  @override
  Future<bool> requestPermission() => _port.requestPermission();

  /// Alarms belong to the system and keep firing with the app closed: nothing to stop.
  @override
  void dispose() {}

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, DateTime now) {
    // Plans arrive faster than the platform answers: handle them one at a time, in order.
    final run = _queue.then((_) => _apply(plan, now));
    _queue = run.catchError((Object _) {});
    return run;
  }

  Future<void> _apply(List<PlannedReminder> plan, DateTime now) async {
    final wanted = {
      for (final r in plan)
        if (r.at.isAfter(now)) r.notificationId: r,
    };
    final pending = await _port.pendingIds();
    for (final id in pending.difference(wanted.keys.toSet())) {
      await _port.cancel(id);
    }
    _set.removeWhere((id, _) => !wanted.containsKey(id) || !pending.contains(id));
    final exact = await _port.canScheduleExact();
    for (final entry in wanted.entries) {
      final r = entry.value;
      if (_set[entry.key] == r.signature && pending.contains(entry.key)) continue;
      await _port.schedule(
        id: entry.key,
        at: r.at,
        title: r.title,
        body: r.body,
        payload: r.taskId,
        exact: exact,
      );
      _set[entry.key] = r.signature;
    }
  }
}
