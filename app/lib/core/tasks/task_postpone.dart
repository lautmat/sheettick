import '../db/database.dart';
import '../sync/local_writer.dart';
import 'task_dates.dart';
import 'task_status.dart';

/// Where "postpone" moves a task to.
enum PostponeTarget {
  today('Today'),
  tomorrow('Tomorrow'),

  /// The next Monday after today (today itself when it is a Monday is not "next week": the Monday after it is).
  nextWeek('Next week'),

  /// Clears the dates. The repeat rule and the reminders stay on the task, waiting for a date.
  noDate('No date');

  const PostponeTarget(this.label);

  final String label;
}

/// The calendar day [target] means when today is [todayWall] (a wall-clock reading), as a UTC midnight. Null for
/// [PostponeTarget.noDate].
DateTime? postponeDay(PostponeTarget target, DateTime todayWall) {
  final today = dayOf(todayWall);
  return switch (target) {
    PostponeTarget.today => today,
    PostponeTarget.tomorrow => today.add(const Duration(days: 1)),
    PostponeTarget.nextWeek => today.add(Duration(days: 8 - today.weekday)),
    PostponeTarget.noDate => null,
  };
}

/// [dates] after postponing to [target], with today at [todayWall].
///
/// The start and the due move together by the same whole number of calendar days, so the time of day, a timed task's zone
/// and the distance between start and due are kept; the day of the due (the start when there is no due) lands on the
/// target day. A task with no date gets that day as an all-day due. [PostponeTarget.noDate] gives no dates at all.
TaskDates postponedDates(TaskDates dates, PostponeTarget target, {required DateTime todayWall}) =>
    datesOnDay(dates, postponeDay(target, todayWall));

/// [dates] moved onto the calendar [day] (a UTC midnight), the way [postponedDates] moves them: by the same whole number
/// of days for the start and the due, so times of day, the zone and the gap between them are kept. A task with no date
/// gets [day] as an all-day due. A null [day] gives no dates at all.
TaskDates datesOnDay(TaskDates dates, DateTime? day) {
  if (day == null) return const TaskDates();
  final anchor = dates.due ?? dates.start;
  if (anchor == null) return TaskDates(due: day, allDay: true, zone: dates.zone);
  final shift = Duration(days: daysBetween(anchor, day));
  return TaskDates(start: dates.start?.add(shift), due: dates.due?.add(shift), allDay: dates.allDay, zone: dates.zone);
}

/// Whether [task] is open with a due day or time that has gone by at [now] (the same test the lists colour red by).
bool isOverdueTask(Task task, {required DateTime now, String? zone}) {
  if (task.status != TaskStatus.open.value || task.deleted) return false;
  final dates = TaskDates.fromRow(startAt: task.startAt, dueAt: task.dueAt, allDay: task.allDay, tz: task.tz, deviceZone: zone);
  return dates.headline(now)?.overdue ?? false;
}

/// Whether postponing [task] to [target] would change anything: it is open, and its dates differ from the result.
bool postponeChanges(Task task, PostponeTarget target, {required DateTime now, String? zone}) =>
    dayChanges(task, postponeDay(target, TaskDates(zone: zone).wallOf(now)), zone: zone);

/// Whether moving [task] onto [day] (a UTC midnight; null clears the dates) would change anything: it is open, and its
/// dates differ from the result.
bool dayChanges(Task task, DateTime? day, {String? zone}) {
  if (task.status != TaskStatus.open.value) return false;
  final dates = TaskDates.fromRow(startAt: task.startAt, dueAt: task.dueAt, allDay: task.allDay, tz: task.tz, deviceZone: zone);
  final moved = datesOnDay(dates, day).toFields();
  final current = dates.toFields();
  return moved.entries.any((e) => current[e.key] != e.value);
}

/// Postpones every open task of [tasks] to [target], in one transaction through [writer]. A task whose dates would not
/// change is left alone (no new `version`). Reminders, the repeat rule and everything else stay as they are, so a
/// reminder relative to the due moves with it. Returns how many tasks changed.
Future<int> postponeTasks(
  LocalWriter writer,
  Iterable<Task> tasks,
  PostponeTarget target, {
  required DateTime now,
  required String? zone,
}) => moveTasksToDay(writer, tasks, postponeDay(target, TaskDates(zone: zone).wallOf(now)), zone: zone);

/// Moves every open task of [tasks] onto the calendar [day] (a UTC midnight; null clears the dates), the way
/// [postponeTasks] does, so "pick any date" and the named targets change a task in the same way. Returns how many tasks
/// changed.
Future<int> moveTasksToDay(LocalWriter writer, Iterable<Task> tasks, DateTime? day, {required String? zone}) {
  return writer.store.transaction(() async {
    var changed = 0;
    for (final task in tasks) {
      if (!dayChanges(task, day, zone: zone)) continue;
      final dates = TaskDates.fromRow(startAt: task.startAt, dueAt: task.dueAt, allDay: task.allDay, tz: task.tz, deviceZone: zone);
      await writer.update('tasks', task.id, datesOnDay(dates, day).toFields());
      changed++;
    }
    return changed;
  });
}
