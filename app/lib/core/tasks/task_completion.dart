import '../db/database.dart';
import '../sync/local_writer.dart';
import '../sync/record.dart';
import 'recurrence.dart';
import 'task_dates.dart';
import 'task_status.dart';

/// Columns that belong to one particular task row and are not carried to the next round of a repeating task.
const _notCopied = {
  'id',
  'created_at',
  'updated_at',
  'version',
  'device',
  'deleted',
  'status',
  'completed_at',
  'pinned_at',
  'start_at',
  'due_at',
  'all_day',
  'tz',
  'rrule',
};

/// Sets [task] to [status] at [now], and carries a repeating task on.
///
/// Finishing (completed or won't do) an open task that repeats creates the next one: a copy with its dates moved on by
/// [nextOccurrence] (see there for how), open again, with its checklist unticked. The finished task stops repeating,
/// so reopening it later does not start a second series. When the series is over (the rule has no occurrence left or
/// `COUNT` ran out) no new task is made. Everything is written in one transaction.
///
/// Reopening a task, or changing the status of one that does not repeat, is just the status change. Returns the id of
/// the new task, or null.
Future<String?> setTaskStatus(
  LocalWriter writer,
  Task task,
  TaskStatus status, {
  required DateTime now,
  required String? zone,
}) {
  return writer.store.transaction(() async {
    final finishing = task.status == TaskStatus.open.value && status != TaskStatus.open;
    final dates = TaskDates.fromRow(
      startAt: task.startAt,
      dueAt: task.dueAt,
      allDay: task.allDay,
      tz: task.tz,
      deviceZone: zone,
    );
    final next = finishing
        ? nextOccurrence(
            rrule: task.rrule,
            repeatFrom: RepeatFrom.parse(task.repeatFrom),
            exDates: task.exDates,
            dates: dates,
            completedWall: TaskDates(zone: zone).wallOf(now),
          )
        : null;
    final changes = <String, Object?>{
      ...statusFields(status, now),
      if (next != null) 'rrule': null,
    };
    await writer.update('tasks', task.id, changes);
    if (next == null) return null;

    final row = await writer.store.getRow('tasks', task.id);
    final copy = <String, Object?>{
      for (final e in (row?.fields ?? <String, Object?>{}).entries)
        if (!_notCopied.contains(e.key)) e.key: e.value,
      ...next.dates.toFields(),
      'rrule': next.rrule,
      'status': TaskStatus.open.value,
    };
    final newId = await writer.insert('tasks', copy);
    await _copyChecklist(writer, from: task.id, to: newId);
    return newId;
  });
}

Future<void> _copyChecklist(LocalWriter writer, {required String from, required String to}) async {
  final items = await writer.store.rowsById('checklist');
  final mine = [
    for (final item in items.values)
      if (item.fields['task_id'] == from && item.fields['deleted'] != true) item,
  ]..sort((a, b) => ((a.fields['sort_order'] as num?) ?? 0).compareTo((b.fields['sort_order'] as num?) ?? 0));
  for (final item in mine) {
    final Fields fields = {
      'task_id': to,
      'title': item.fields['title'],
      'sort_order': item.fields['sort_order'],
      'status': 0,
    };
    await writer.insert('checklist', fields);
  }
}
