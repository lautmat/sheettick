import 'dart:convert';

import 'package:timezone/timezone.dart' as tzdb;

import '../db/database.dart';
import '../tasks/task_dates.dart';
import '../tasks/task_status.dart';
import 'reminder_trigger.dart';

/// A notification that should appear at [at] for one reminder of one task.
class PlannedReminder {
  const PlannedReminder({
    required this.taskId,
    required this.trigger,
    required this.at,
    required this.title,
    required this.body,
  });

  final String taskId;
  final ReminderTrigger trigger;

  /// The moment to notify, as an instant (UTC).
  final DateTime at;
  final String title;
  final String body;

  /// Names this reminder across plans: the same task and trigger is the same reminder even when its time moved.
  String get key => '$taskId|${trigger.format()}';

  /// A positive 31-bit number for the platform notification, the same on every run (FNV-1a over [key]).
  int get notificationId {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(key)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  /// Everything that shows on the notification and when, so a changed reminder can be told from an unchanged one.
  String get signature => '${at.millisecondsSinceEpoch}|$title|$body';

  @override
  String toString() => 'PlannedReminder($key at $at)';
}

/// The reminders to schedule for [tasks]: those of open tasks that are not deleted, from [after] (exclusive) to [until]
/// (inclusive), earliest first, at most [limit] of them.
///
/// A reminder is relative to the task's anchor: the start when the task has one, else the due. An all-day anchor is
/// midnight at the start of its day, so the reminder's duration carries the time of day. Times are read on [deviceZone]
/// the way the app shows them (null: the platform's zone).
List<PlannedReminder> planReminders(
  Iterable<Task> tasks, {
  required DateTime after,
  DateTime? until,
  String? deviceZone,
  int limit = 200,
}) {
  final zone = locationOf(deviceZone);
  final planned = <PlannedReminder>[];
  for (final task in tasks) {
    if (task.deleted || task.status != TaskStatus.open.value) continue;
    final triggers = parseReminders(task.reminders);
    if (triggers.isEmpty) continue;
    final dates = TaskDates.fromRow(
      startAt: task.startAt,
      dueAt: task.dueAt,
      allDay: task.allDay,
      tz: task.tz,
      deviceZone: deviceZone,
    );
    final fromStart = dates.start != null;
    final anchor = dates.start ?? dates.due;
    if (anchor == null) continue;
    final title = task.title.trim().isEmpty ? 'Untitled task' : task.title.trim();
    final body = '${fromStart ? 'Starts' : 'Due'} ${_when(anchor, timed: !dates.allDay)}';
    for (final trigger in triggers) {
      final at = _instant(anchor, trigger, zone);
      if (!at.isAfter(after) || (until != null && at.isAfter(until))) continue;
      planned.add(PlannedReminder(taskId: task.id, trigger: trigger, at: at, title: title, body: body));
    }
  }
  planned.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    return byTime != 0 ? byTime : a.key.compareTo(b.key);
  });
  return planned.length > limit ? planned.sublist(0, limit) : planned;
}

/// The instant [trigger] after the wall-clock [anchor] in [zone]: whole days on the calendar, then an exact length of
/// time.
DateTime _instant(DateTime anchor, ReminderTrigger trigger, tzdb.Location? zone) {
  final day = DateTime.utc(anchor.year, anchor.month, anchor.day + trigger.days, anchor.hour, anchor.minute);
  final base = zone == null
      ? DateTime(day.year, day.month, day.day, day.hour, day.minute).toUtc()
      : tzdb.TZDateTime(zone, day.year, day.month, day.day, day.hour, day.minute).toUtc();
  return base.add(Duration(seconds: trigger.seconds));
}

String _two(int n) => n.toString().padLeft(2, '0');

String _when(DateTime wall, {required bool timed}) {
  final day = '${wall.year.toString().padLeft(4, '0')}-${_two(wall.month)}-${_two(wall.day)}';
  return timed ? '$day ${_two(wall.hour)}:${_two(wall.minute)}' : day;
}
