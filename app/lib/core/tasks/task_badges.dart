import '../db/database.dart';
import '../reminders/reminder_trigger.dart';
import 'task_status.dart';

/// How far a task's checklist is: [done] of [total] items ticked.
typedef ChecklistProgress = ({int done, int total});

/// The progress of each task that has checklist items, by task id. Deleted items do not count, and a task with none has
/// no entry.
Map<String, ChecklistProgress> checklistProgress(Iterable<ChecklistItem> items) {
  final progress = <String, ChecklistProgress>{};
  for (final item in items) {
    final taskId = item.taskId;
    if (item.deleted || taskId == null) continue;
    final so = progress[taskId] ?? (done: 0, total: 0);
    progress[taskId] = (done: so.done + (item.status == TaskStatus.completed.value ? 1 : 0), total: so.total + 1);
  }
  return progress;
}

/// The number of subtasks directly under each task that has any, by task id: the open and the completed ones. Deleted
/// subtasks and those marked Won't Do are not counted.
Map<String, int> subtaskCounts(Iterable<Task> tasks) {
  final counts = <String, int>{};
  for (final task in tasks) {
    final parent = task.parentId;
    if (parent == null || task.deleted || task.status == TaskStatus.wontDo.value) continue;
    counts[parent] = (counts[parent] ?? 0) + 1;
  }
  return counts;
}

/// Whether [task] has a reminder the app can read.
bool hasReminder(Task task) => parseReminders(task.reminders).isNotEmpty;

/// Whether [task] has a repeat rule.
bool isRepeating(Task task) => task.rrule?.trim().isNotEmpty ?? false;

/// Whether [task] has anything written in its note.
bool hasNote(Task task) => task.content.trim().isNotEmpty;
