import '../db/database.dart';
import 'task_dates.dart';
import 'task_status.dart';

/// The built-in lists that show tasks from every list.
enum SmartList {
  today('Today'),
  tomorrow('Tomorrow'),
  next7Days('Next 7 Days'),
  all('All'),
  noDate('No Date'),
  completed('Completed'),
  wontDo("Won't Do"),
  trash('Trash');

  const SmartList(this.label);

  final String label;
}

/// Whether [task] is shown in [list] at [now], with its dates read on [zone] (the device's IANA zone).
///
/// - Trash holds the tombstoned tasks (`deleted`), whatever their status, and nothing else; every other list leaves
///   them out.
/// - Completed holds the done tasks (`status` 2) and Won't Do the dropped ones (`status` -1).
/// - The other lists hold open tasks only. Today, Tomorrow and Next 7 Days go by the due day, or by the start day when
///   there is no due: Today is that day being today or already past (what is overdue is still to do), Tomorrow is
///   tomorrow, and Next 7 Days is today and the six days after it. A task with no date is not in those; it is in All and
///   in No Date, which holds the open tasks with neither a start nor a due. Text in a date cell that is not a real date
///   reads as no date (see `TaskDates`), so such a task is in No Date, where it can be seen and fixed.
bool smartListHas(SmartList list, Task task, {required DateTime now, String? zone}) {
  // Every list but Trash leaves out the tombstones; the Trash arm below is the only place that takes them in.
  if (task.deleted && list != SmartList.trash) return false;
  switch (list) {
    case SmartList.completed:
      return task.status == TaskStatus.completed.value;
    case SmartList.wontDo:
      return task.status == TaskStatus.wontDo.value;
    case SmartList.all:
      return task.status == TaskStatus.open.value;
    case SmartList.noDate:
      return task.status == TaskStatus.open.value && smartListDate(task, zone) == null;
    case SmartList.today:
    case SmartList.tomorrow:
    case SmartList.next7Days:
      if (task.status != TaskStatus.open.value) return false;
      final dates = TaskDates.fromRow(
        startAt: task.startAt,
        dueAt: task.dueAt,
        allDay: task.allDay,
        tz: task.tz,
        deviceZone: zone,
      );
      final day = dates.due ?? dates.start;
      if (day == null) return false;
      // An all-day task carries no zone of its own, so today is read on the device zone given.
      final days = daysBetween(TaskDates(zone: zone).wallOf(now), day);
      return switch (list) {
        SmartList.today => days <= 0,
        SmartList.tomorrow => days == 1,
        _ => days >= 0 && days <= 6,
      };
    case SmartList.trash:
      return task.deleted;
  }
}

/// The date a task is placed by in the date lists: the due, else the start, as a wall-clock reading. Null when it has
/// neither.
DateTime? smartListDate(Task task, String? zone) {
  final dates = TaskDates.fromRow(
    startAt: task.startAt,
    dueAt: task.dueAt,
    allDay: task.allDay,
    tz: task.tz,
    deviceZone: zone,
  );
  return dates.due ?? dates.start;
}

/// [tasks] as [list] shows them: only its members, in its order. The date lists run from the earliest date; Completed
/// and Trash start with the most recent change; All and No Date keep the order given.
List<Task> smartListRows(SmartList list, Iterable<Task> tasks, {required DateTime now, String? zone}) {
  final rows = [for (final t in tasks) if (smartListHas(list, t, now: now, zone: zone)) t];
  switch (list) {
    case SmartList.today:
    case SmartList.tomorrow:
    case SmartList.next7Days:
      final dates = {for (final t in rows) t.id: smartListDate(t, zone)!};
      rows.sort((a, b) {
        final byDate = dates[a.id]!.compareTo(dates[b.id]!);
        return byDate != 0 ? byDate : a.sortOrder.compareTo(b.sortOrder);
      });
    case SmartList.completed:
      rows.sort((a, b) => (b.completedAt ?? '').compareTo(a.completedAt ?? ''));
    case SmartList.wontDo:
    case SmartList.trash:
      rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    case SmartList.all:
    case SmartList.noDate:
      break;
  }
  return rows;
}
