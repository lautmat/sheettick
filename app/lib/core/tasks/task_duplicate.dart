import '../sync/local_writer.dart';
import '../sync/record.dart';
import '../undo/undo.dart';
import 'task_reorder.dart';
import 'task_status.dart';

/// The columns a copy does not take over: its own id and bookkeeping (the writer sets them), and what says the original
/// was done or pinned.
const _notCopied = {'id', 'created_at', 'updated_at', 'version', 'device', 'deleted', 'completed_at', 'pinned_at'};

Fields _copyOf(Fields fields) => {
  for (final e in fields.entries)
    if (!_notCopied.contains(e.key)) e.key: e.value,
};

num _order(Fields f) => (f['sort_order'] as num?) ?? 0;

/// [rows] as the lists show them by hand: by `sort_order`, then by age.
List<Fields> _inOrder(Iterable<Fields> rows) => rows.toList()
  ..sort((a, b) {
    final byOrder = _order(a).compareTo(_order(b));
    return byOrder != 0 ? byOrder : '${a['created_at']}'.compareTo('${b['created_at']}');
  });

/// The task rows [duplicateTask] may change besides the ones it makes, for [recordUndo]: those of the task's list, which
/// are renumbered when there is no room between two of them.
Future<List<RowRef>> duplicateRows(LocalWriter writer, String taskId) async {
  final tasks = await writer.store.rowsById('tasks');
  final listId = tasks[taskId]?.fields['list_id'];
  return [
    for (final t in tasks.values)
      if (t.fields['list_id'] == listId) (tab: 'tasks', id: t.id),
  ];
}

/// Copies the task [taskId] with its subtasks and checklist items, under new ids, and puts the copy just below the
/// original. Everything in the copy is open. Subtasks marked Won't Do (and what is under them) and deleted rows are left
/// behind. Returns the rows made, the copy of the task itself first. One transaction.
Future<List<RowRef>> duplicateTask(LocalWriter writer, String taskId) {
  return writer.store.transaction(() async {
    final tasks = {for (final r in (await writer.store.rowsById('tasks')).values) r.id: r.fields};
    final original = tasks[taskId] ?? (throw StateError('No tasks row $taskId'));
    final items = [
      for (final r in (await writer.store.rowsById('checklist')).values)
        if (r.fields['deleted'] != true) r.fields,
    ];
    final made = <RowRef>[];
    final copied = <String>{};

    // [order] is the copy's `sort_order`. Rows made in one go have the same age, so the copies under the task are
    // numbered 1, 2, 3... to keep the originals' order.
    Future<String> copy(Fields source, {required String? parentId, required num order}) async {
      final sourceId = source['id'] as String;
      copied.add(sourceId);
      final id = await writer.insert('tasks', {
        ..._copyOf(source),
        'parent_id': parentId,
        'sort_order': order.toDouble(),
        'status': TaskStatus.open.value,
      });
      made.add((tab: 'tasks', id: id));
      final own = _inOrder(items.where((i) => i['task_id'] == sourceId));
      for (var i = 0; i < own.length; i++) {
        final itemId = await writer.insert('checklist', {
          ..._copyOf(own[i]),
          'task_id': id,
          'sort_order': (i + 1).toDouble(),
          'status': TaskStatus.open.value,
        });
        made.add((tab: 'checklist', id: itemId));
      }
      final children = _inOrder(
        tasks.values.where(
          (t) =>
              t['parent_id'] == sourceId &&
              t['deleted'] != true &&
              t['status'] != TaskStatus.wontDo.value &&
              !copied.contains(t['id']),
        ),
      );
      for (var i = 0; i < children.length; i++) {
        await copy(children[i], parentId: id, order: i + 1);
      }
      return id;
    }

    final siblings = _inOrder(
      tasks.values.where(
        (t) =>
            t['deleted'] != true &&
            t['list_id'] == original['list_id'] &&
            t['parent_id'] == original['parent_id'] &&
            (original['parent_id'] != null || t['section_id'] == original['section_id']),
      ),
    );
    final id = await copy(original, parentId: original['parent_id'] as String?, order: _order(original));

    final shown = [for (final t in siblings) (id: t['id'] as String, order: _order(t).toDouble())];
    final after = shown.indexWhere((t) => t.id == taskId) + 1;
    final orders = placeBefore(
      shown,
      (id: id, order: _order(original).toDouble()),
      after < shown.length ? shown[after].id : null,
    );
    for (final e in orders.entries) {
      await writer.update('tasks', e.key, {'sort_order': e.value});
    }
    return made;
  });
}
