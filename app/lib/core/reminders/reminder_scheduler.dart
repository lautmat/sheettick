import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import 'reminder_planner.dart';

/// Puts the notifications of a plan on the platform. The plan is always the whole picture: what the scheduler holds
/// that is not in the plan has been moved, completed or deleted and must not fire.
abstract class ReminderScheduler {
  /// Asks the user to allow notifications, if the platform needs it. True when reminders will be shown. Refusing only
  /// means nothing is shown: no task is changed.
  Future<bool> requestPermission();

  /// Makes [plan] the reminders to deliver. [now] is the current time.
  Future<void> replaceAll(List<PlannedReminder> plan, DateTime now);
}

/// For a platform with no notifications (and for tests): accepts every plan and shows nothing.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, DateTime now) async {}
}

/// Shows reminders while the app runs, for platforms where a scheduled notification cannot be cancelled or changed
/// (Windows, outside an MSIX package). The app keeps running in the tray so reminders fire.
///
/// It looks at the plan every [interval] and shows the reminders whose time fell since the last look, so a reminder is
/// shown once. After the app was closed or the computer asleep, reminders from up to [catchUp] ago that were missed are
/// shown on the first look. The time of the last look is kept through [loadLastLook] and [saveLastLook].
class PollingReminderScheduler implements ReminderScheduler {
  PollingReminderScheduler({
    required this.show,
    required this.clock,
    required this.loadLastLook,
    required this.saveLastLook,
    this.interval = const Duration(seconds: 15),
    this.catchUp = const Duration(hours: 24),
  });

  final Future<void> Function(PlannedReminder reminder) show;
  final DateTime Function() clock;
  final Future<DateTime?> Function() loadLastLook;
  final Future<void> Function(DateTime time) saveLastLook;
  final Duration interval;
  final Duration catchUp;

  List<PlannedReminder> _plan = const [];
  Timer? _timer;
  Future<void>? _looking;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, DateTime now) async {
    _plan = plan;
    _timer ??= Timer.periodic(interval, (_) => look());
    await look();
  }

  /// One look at the plan. Looks never overlap.
  Future<void> look() => _looking ??= _look().whenComplete(() => _looking = null);

  Future<void> _look() async {
    final now = clock();
    final saved = await loadLastLook();
    final earliest = now.subtract(catchUp);
    // The first run on a device has no past to catch up on.
    var since = saved == null ? now : (saved.isBefore(earliest) ? earliest : saved);
    if (since.isAfter(now)) since = now;
    for (final reminder in _plan) {
      if (!reminder.at.isAfter(since) || reminder.at.isAfter(now)) continue;
      try {
        await show(reminder);
      } catch (e) {
        debugPrint('Could not show the reminder for ${reminder.taskId}: $e');
      }
    }
    await saveLastLook(now);
  }

  void dispose() => _timer?.cancel();
}
