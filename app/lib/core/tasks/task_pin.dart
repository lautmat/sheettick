import '../db/database.dart';
import '../sync/local_writer.dart';
import '../time.dart';
import 'task_status.dart';

/// Whether [task] is pinned: its `pinned_at` says when it was.
bool isPinned(Task task) => task.pinnedAt?.isNotEmpty ?? false;

/// Whether [task], shown as a top-level task, goes to the head of its list: pinned and not completed.
bool showsPinned(Task task) => isPinned(task) && task.status != TaskStatus.completed.value;

/// The ids of the tasks shown at the head of the list: the pinned top-level tasks and the subtasks under them.
Set<String> underPinned(List<Task> tasks) {
  final byId = {for (final t in tasks) t.id: t};
  bool pinned(Task task) {
    var top = task;
    final seen = <String>{};
    while (top.parentId != null && byId.containsKey(top.parentId) && seen.add(top.id)) {
      top = byId[top.parentId]!;
    }
    return showsPinned(top);
  }

  return {
    for (final t in tasks)
      if (pinned(t)) t.id,
  };
}

/// Pins the task [taskId] at [now], or unpins it.
Future<void> setPinned(LocalWriter writer, String taskId, bool pinned, {required DateTime now}) =>
    writer.update('tasks', taskId, {'pinned_at': pinned ? formatUtc(now) : null});
