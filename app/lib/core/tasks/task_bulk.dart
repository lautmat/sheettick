import '../db/database.dart';
import '../sync/local_writer.dart';
import '../undo/undo.dart';
import 'task_move.dart';

/// The ids of the tasks a folded section hides: the tasks filed in one of the [folded] sections, and the subtasks under
/// them (a subtask is shown in its top-level task's section, whatever its own `section_id` says).
Set<String> hiddenByFolding(List<Task> tasks, Set<String> folded) {
  if (folded.isEmpty) return const {};
  final byId = {for (final t in tasks) t.id: t};
  bool hidden(Task task) {
    var top = task;
    final seen = <String>{};
    while (top.parentId != null && byId.containsKey(top.parentId) && seen.add(top.id)) {
      top = byId[top.parentId]!;
    }
    return folded.contains(top.sectionId);
  }

  return {
    for (final t in tasks)
      if (hidden(t)) t.id,
  };
}

/// [ids] and every live task under them, each once.
Future<List<String>> withSubtasks(LocalWriter writer, Iterable<String> ids) async {
  final tasks = await writer.store.rowsById('tasks');
  final all = <String>{...ids};
  var frontier = {...ids};
  while (frontier.isNotEmpty) {
    frontier = {
      for (final t in tasks.values)
        if (t.fields['deleted'] != true && frontier.contains(t.fields['parent_id']) && all.add(t.id)) t.id,
    };
  }
  return all.toList();
}

/// Moves each task of [ids], in that order, to the end of the list [listId], outside any section, as one drag onto
/// the list in the sidebar would. Returns how many moved.
///
/// A task's subtasks go with it. A selected subtask whose parent is also selected is left to follow the parent; one whose
/// parent is not becomes a task of its own in the new list. A task that is already a top-level task of that list stays
/// where it is.
Future<int> moveTasksToListEnd(LocalWriter writer, List<String> ids, String listId) async {
  final tasks = await writer.store.rowsById('tasks');
  final chosen = ids.toSet();

  bool followsParent(String id) {
    final seen = <String>{id};
    var parent = tasks[id]?.fields['parent_id'];
    while (parent is String && seen.add(parent)) {
      if (chosen.contains(parent)) return true;
      parent = tasks[parent]?.fields['parent_id'];
    }
    return false;
  }

  var moved = 0;
  for (final id in ids) {
    final fields = tasks[id]?.fields;
    if (fields == null || fields['deleted'] == true || followsParent(id)) continue;
    if (fields['list_id'] == listId && fields['parent_id'] == null) continue;
    final plan = await planMove(writer, id, listId: listId);
    if (plan.isEmpty) continue;
    await applyMove(writer, plan);
    moved++;
  }
  return moved;
}

/// The rows [moveTasksToListEnd] may write, for [recordUndo]: the tasks, their subtasks, and the tasks already in the
/// list (a move renumbers a place when it has to).
Future<List<RowRef>> bulkMoveRows(LocalWriter writer, Iterable<String> ids, String listId) async {
  final tasks = await writer.store.rowsById('tasks');
  final rows = <String>{
    ...await withSubtasks(writer, ids),
    for (final t in tasks.values)
      if (t.fields['list_id'] == listId) t.id,
  };
  return [for (final id in rows) (tab: 'tasks', id: id)];
}

/// Moves the tasks of [ids] and their subtasks to the Trash (a tombstone, so they can be restored). Returns how many
/// rows it tombstoned.
Future<int> trashTasks(LocalWriter writer, Iterable<String> ids) async {
  final all = await withSubtasks(writer, ids);
  final rows = await writer.store.rowsById('tasks');
  var trashed = 0;
  for (final id in all) {
    if (rows[id]?.fields['deleted'] == true) continue;
    await writer.delete('tasks', id);
    trashed++;
  }
  return trashed;
}
