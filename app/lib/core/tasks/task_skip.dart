import 'dart:convert';

import '../db/database.dart';
import '../sync/local_writer.dart';
import 'checklist.dart';
import 'recurrence.dart';
import 'task_dates.dart';
import 'task_status.dart';

/// What [skipOccurrence] did.
enum SkipOutcome {
  /// The task moved to its next occurrence.
  skipped,

  /// The series has no occurrence left (the rule ended, or `COUNT` ran out). Nothing was changed.
  noMoreOccurrences,

  /// The task is not open, does not repeat, or has no date to repeat from. Nothing was changed.
  cannotSkip,
}

/// Whether [skipOccurrence] has something to do for [task]: it is open, has a readable rule, and a date to count from.
bool canSkipOccurrence(Task task) {
  if (task.status != TaskStatus.open.value) return false;
  if (parseRrule(task.rrule) == null) return false;
  final dates = TaskDates.fromRow(startAt: task.startAt, dueAt: task.dueAt, allDay: task.allDay, tz: task.tz);
  return (dates.due ?? dates.start) != null;
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Moves the repeating [task] on to its next occurrence without finishing it: nothing is marked done or won't do.
///
/// The next occurrence is the first one after the task's own date, whatever [RepeatFrom] says and whatever today is,
/// so skipping an overdue task moves it one step, not to the future. The day skipped is added to `ex_dates`, and a
/// rule with `COUNT` counts the skipped one as used. Ticked checklist items are unticked for the new round. It is
/// the same row throughout, in one transaction. Subtasks stay as they are.
///
/// [zone] is the IANA name of the zone the dates are shown in, as for `setTaskStatus`. Callers that want an undo list
/// the task's checklist rows too: [checklistItemIds] gives their ids.
Future<SkipOutcome> skipOccurrence(LocalWriter writer, Task task, {required String? zone}) {
  return writer.store.transaction(() async {
    if (!canSkipOccurrence(task)) return SkipOutcome.cannotSkip;
    final dates = TaskDates.fromRow(
      startAt: task.startAt,
      dueAt: task.dueAt,
      allDay: task.allDay,
      tz: task.tz,
      deviceZone: zone,
    );
    final anchor = (dates.due ?? dates.start)!;
    final next = nextOccurrence(
      rrule: task.rrule,
      repeatFrom: RepeatFrom.due,
      exDates: task.exDates,
      dates: dates,
      completedWall: anchor,
    );
    if (next == null) return SkipOutcome.noMoreOccurrences;

    final skipped = {...exDays(task.exDates), _day(anchor)}.toList()..sort();
    await writer.update('tasks', task.id, {
      ...next.dates.toFields(),
      'rrule': next.rrule,
      'ex_dates': jsonEncode(skipped),
    });
    for (final id in await checklistItemIds(writer, task.id, onlyTicked: true)) {
      await writer.update('checklist', id, checklistItemFields(done: false, now: DateTime.now()));
    }
    return SkipOutcome.skipped;
  });
}

/// The ids of the live checklist rows of [taskId]; with [onlyTicked], just those that are done.
Future<List<String>> checklistItemIds(LocalWriter writer, String taskId, {bool onlyTicked = false}) async {
  final items = await writer.store.rowsById('checklist');
  return [
    for (final item in items.values)
      if (item.fields['task_id'] == taskId &&
          item.fields['deleted'] != true &&
          (!onlyTicked || (item.fields['status'] as num?)?.toInt() == TaskStatus.completed.value))
        item.fields['id'] as String,
  ];
}
