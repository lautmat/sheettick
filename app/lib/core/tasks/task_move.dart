import '../sync/local_writer.dart';
import '../sync/record.dart';
import '../undo/undo.dart';
import 'task_reorder.dart';

/// One write of a plan: the columns to set on a row.
typedef RowWrite = ({RowRef row, Fields changes});

/// What moving a task would write. Empty when the task is dropped where it already is.
class MovePlan {
  const MovePlan(this.writes);

  final List<RowWrite> writes;

  bool get isEmpty => writes.isEmpty;

  /// The rows the plan changes, for [recordUndo].
  List<RowRef> get rows => [for (final w in writes) w.row];
}

/// Works out how to put the top-level task [taskId] in the list [listId], in the section [sectionId] (null: outside
/// any section), just before the task [beforeId] (null: at the end). Reads only; [applyMove] writes it.
///
/// The task's subtasks follow it into another list. The rest of the place is renumbered only when it has to be (see
/// [placeBefore]). The place is ordered the way the list shows it: open tasks first, then by `sort_order`, then by when
/// the task was created. A task whose `section_id` names a section that is gone counts as outside any section, as it is
/// shown.
Future<MovePlan> planMove(
  LocalWriter writer,
  String taskId, {
  required String listId,
  String? sectionId,
  String? beforeId,
}) async {
  final tasks = await writer.store.rowsById('tasks');
  final task = tasks[taskId] ?? (throw StateError('No tasks row $taskId'));
  final liveSections = {
    for (final s in (await writer.store.rowsById('sections')).values)
      if (s.fields['deleted'] != true && s.fields['list_id'] == listId) s.id,
  };
  bool inPlace(LocalRow t) {
    final f = t.fields;
    if (f['deleted'] == true || f['list_id'] != listId || f['parent_id'] != null) return false;
    final status = f['status'];
    if (status != 0 && status != 2) return false;
    final section = f['section_id'];
    final shownIn = liveSections.contains(section) ? section : null;
    return shownIn == sectionId;
  }

  double orderOf(LocalRow t) => (t.fields['sort_order'] as num?)?.toDouble() ?? 0;
  final siblings = tasks.values.where(inPlace).toList()
    ..sort((a, b) {
      final byStatus = ((a.fields['status'] as num?) ?? 0).compareTo((b.fields['status'] as num?) ?? 0);
      if (byStatus != 0) return byStatus;
      final byOrder = orderOf(a).compareTo(orderOf(b));
      return byOrder != 0 ? byOrder : '${a.fields['created_at']}'.compareTo('${b.fields['created_at']}');
    });

  final orders = placeBefore(
    [for (final t in siblings) (id: t.id, order: orderOf(t))],
    (id: taskId, order: orderOf(task)),
    beforeId,
  );

  final writes = <RowWrite>[];
  final moved = task.fields['list_id'] != listId || task.fields['section_id'] != sectionId || task.fields['parent_id'] != null;
  if (moved || orders.containsKey(taskId)) {
    writes.add((
      row: (tab: 'tasks', id: taskId),
      changes: {
        'list_id': listId,
        'section_id': sectionId,
        'parent_id': null,
        if (orders.containsKey(taskId)) 'sort_order': orders[taskId],
      },
    ));
  }
  for (final e in orders.entries) {
    if (e.key != taskId) writes.add((row: (tab: 'tasks', id: e.key), changes: {'sort_order': e.value}));
  }
  if (task.fields['list_id'] != listId) {
    // Subtasks live in their parent's list; left behind they would show up as tasks of the old list.
    final seen = {taskId};
    var frontier = [taskId];
    while (frontier.isNotEmpty) {
      final next = [
        for (final t in tasks.values)
          if (t.fields['deleted'] != true && frontier.contains(t.fields['parent_id']) && seen.add(t.id)) t.id,
      ];
      for (final id in next) {
        writes.add((row: (tab: 'tasks', id: id), changes: {'list_id': listId}));
      }
      frontier = next;
    }
  }
  return MovePlan(writes);
}

/// Writes [plan] through [writer], so every row it touches gets a new `version` and syncs.
Future<void> applyMove(LocalWriter writer, MovePlan plan) async {
  for (final w in plan.writes) {
    await writer.update(w.row.tab, w.row.id, w.changes);
  }
}
