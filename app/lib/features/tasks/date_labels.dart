import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/tasks/task_dates.dart';

/// The start and due of a task row, shown on [deviceZone].
extension TaskRowDates on Task {
  TaskDates dates(String? deviceZone) =>
      TaskDates.fromRow(startAt: startAt, dueAt: dueAt, allDay: allDay, tz: tz, deviceZone: deviceZone);
}

/// The time of day of [wall], in the device's 12 or 24 hour style.
String timeText(BuildContext context, DateTime wall) => MaterialLocalizations.of(context).formatTimeOfDay(
  TimeOfDay(hour: wall.hour, minute: wall.minute),
  alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
);

/// The day of [wall] as a list says it: Today, Tomorrow, Yesterday, then "Nov 12", with the year when it is not this
/// one. [today] is today's wall-clock reading.
String dayText(BuildContext context, DateTime wall, DateTime today) {
  final l10n = MaterialLocalizations.of(context);
  return switch (daysBetween(today, wall)) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => wall.year == today.year ? l10n.formatShortMonthDay(wall) : l10n.formatCompactDate(wall),
  };
}

/// One moment: its day, then its time when it has one ("Tomorrow, 9:00 AM").
String momentText(BuildContext context, DateTime wall, {required bool timed, required DateTime today}) {
  final day = dayText(context, wall, today);
  return timed ? '$day, ${timeText(context, wall)}' : day;
}

/// What a list row says about a task's dates: the due, else "Starts" and the start.
String headlineText(BuildContext context, DateHeadline h) {
  final text = momentText(context, h.wall, timed: h.timed, today: h.today);
  return h.isDue ? text : 'Starts $text';
}

/// What the dates chip on the task page says: both ends as a range, one end, or "Add date".
String datesSummary(BuildContext context, TaskDates dates, DateTime now) {
  final start = dates.start, due = dates.due;
  if (start == null && due == null) return 'Add date';
  final today = dates.wallOf(now);
  String moment(DateTime w) => momentText(context, w, timed: !dates.allDay, today: today);
  if (start != null && due != null) return start == due ? moment(due) : '${moment(start)} – ${moment(due)}';
  return due != null ? moment(due) : 'Starts ${moment(start!)}';
}
