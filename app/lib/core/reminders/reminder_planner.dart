import 'dart:convert';

import 'package:timezone/timezone.dart' as tzdb;

import '../db/database.dart';
import '../tasks/task_dates.dart';
import '../tasks/task_status.dart';
import 'reminder_trigger.dart';
import 'snooze.dart';

/// A notification that should appear at [at] for one reminder of one task.
class PlannedReminder {
  const PlannedReminder({
    required this.taskId,
    required this.trigger,
    required this.at,
    required this.title,
    required this.body,
    DateTime? originalAt,
  }) : originalAt = originalAt ?? at;

  final String taskId;
  final ReminderTrigger trigger;

  /// The moment to notify, as an instant (UTC). For a snoozed reminder this is where it was moved to.
  final DateTime at;

  /// The moment the task's dates and trigger give, before any snooze.
  final DateTime originalAt;
  final String title;
  final String body;

  /// Names this reminder across plans: the same task and trigger is the same reminder even when its time moved.
  String get key => '$taskId|${trigger.format()}';

  /// A positive 31-bit number for the platform notification, the same on every run (FNV-1a over [key]).
  int get notificationId => notificationIdOf(key);

  /// Everything that shows on the notification and when, so a changed reminder can be told from an unchanged one.
  String get signature => '${at.millisecondsSinceEpoch}|$title|$body';

  @override
  String toString() => 'PlannedReminder($key at $at)';
}

/// A positive 31-bit number for the platform notification of the reminder [key], the same on every run (FNV-1a).
int notificationIdOf(String key) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(key)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// The reminders to schedule for [tasks]: those of open tasks that are not deleted, from [after] (exclusive) to [until]
/// (inclusive), earliest first, at most [limit] of them.
///
/// A reminder is relative to the task's anchor: the start when the task has one, else the due. An all-day anchor is
/// midnight at the start of its day, so the reminder's duration carries the time of day. Times are read on [deviceZone]
/// the way the app shows them (null: the platform's zone).
///
/// A reminder in [snoozes] whose snooze was made for the time it has now is moved to the end of the snooze; one whose
/// task has since moved to another time is not (the snooze is stale).
List<PlannedReminder> planReminders(
  Iterable<Task> tasks, {
  required DateTime after,
  DateTime? until,
  String? deviceZone,
  int limit = 200,
  Map<String, Snooze> snoozes = const {},
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
      final original = _instant(anchor, trigger, zone);
      final key = '${task.id}|${trigger.format()}';
      final snooze = snoozes[key];
      final at = snooze != null && snooze.from == original ? snooze.until : original;
      if (!at.isAfter(after) || (until != null && at.isAfter(until))) continue;
      planned.add(
        PlannedReminder(taskId: task.id, trigger: trigger, at: at, originalAt: original, title: title, body: body),
      );
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
  return wallToInstant(day, zone).add(Duration(seconds: trigger.seconds));
}

/// The instant the wall-clock reading [wall] (the year to the minute, held in a UTC [DateTime]) is in [zone], or in the
/// platform's zone when [zone] is null.
DateTime wallToInstant(DateTime wall, tzdb.Location? zone) => zone == null
    ? DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute).toUtc()
    : tzdb.TZDateTime(zone, wall.year, wall.month, wall.day, wall.hour, wall.minute).toUtc();

String _two(int n) => n.toString().padLeft(2, '0');

String _when(DateTime wall, {required bool timed}) {
  final day = '${wall.year.toString().padLeft(4, '0')}-${_two(wall.month)}-${_two(wall.day)}';
  return timed ? '$day ${_two(wall.hour)}:${_two(wall.minute)}' : day;
}

/// The reminder of [task] a snooze applies to: the latest one already due at [now], else the next one to come. Null when
/// the task has no reminders to snooze (none set, no date, or not open).
PlannedReminder? snoozeTarget(Task task, {required DateTime now, String? deviceZone}) {
  final all = planReminders([task], after: DateTime.utc(2000), deviceZone: deviceZone);
  if (all.isEmpty) return null;
  final due = all.where((r) => !r.at.isAfter(now));
  return due.isEmpty ? all.first : due.last;
}
