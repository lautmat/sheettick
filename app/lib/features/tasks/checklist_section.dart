import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/tasks/checklist.dart';
import '../common/local_edit.dart';
import '../common/name_dialog.dart';
import 'checklist_providers.dart';

/// A task's checklist: its items, which tick, rename, drag into order and delete, and a field to add one. Adding the
/// first item makes the task a checklist task.
class ChecklistSection extends ConsumerWidget {
  const ChecklistSection({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(checklistProvider(task.id)).value ?? const <ChecklistItem>[];
    return Column(
      children: [
        ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          physics: const NeverScrollableScrollPhysics(),
          onReorderItem: (oldIndex, newIndex) => _reorder(ref, items, oldIndex, newIndex),
          children: [
            for (var i = 0; i < items.length; i++) _ItemRow(key: ValueKey(items[i].id), item: items[i], index: i),
          ],
        ),
        _AddItemField(task: task),
      ],
    );
  }

  /// Writes the new order. Items are renumbered 1, 2, 3, ..., so the order holds even where stored orders tie. Only
  /// the items whose number changed are written.
  Future<void> _reorder(WidgetRef ref, List<ChecklistItem> items, int oldIndex, int newIndex) async {
    final moved = checklistOrderAfterMove(items, oldIndex, newIndex);
    final writer = await ref.read(localWriterProvider.future);
    for (var i = 0; i < moved.length; i++) {
      final order = i + 1.0;
      if (moved[i].sortOrder != order) await writer.update('checklist', moved[i].id, {'sort_order': order});
    }
    ref.read(syncControllerProvider.notifier).requestSoon();
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({super.key, required this.item, required this.index});

  final ChecklistItem item;

  /// The row's place in the list, for its drag handle.
  final int index;

  bool get _done => item.status == 2;

  Future<void> _tick(WidgetRef ref, bool done) =>
      updateRow(ref, 'checklist', item.id, checklistItemFields(done: done, now: DateTime.now()));

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(title: 'Edit item', initial: item.title),
    );
    if (title == null || title.trim().isEmpty || title.trim() == item.title) return;
    await updateRow(ref, 'checklist', item.id, {'title': title.trim()});
  }

  Future<void> _delete(WidgetRef ref) async {
    final writer = await ref.read(localWriterProvider.future);
    await writer.delete('checklist', item.id);
    ref.read(syncControllerProvider.notifier).requestSoon();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(right: 8),
      leading: Checkbox(value: _done, onChanged: (v) => _tick(ref, v ?? false)),
      title: Text(
        item.title.isEmpty ? '(untitled)' : item.title,
        style: _done ? TextStyle(decoration: TextDecoration.lineThrough, color: muted) : null,
      ),
      onTap: () => _rename(context, ref),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(tooltip: 'Delete item', icon: const Icon(Icons.close), onPressed: () => _delete(ref)),
          ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator)),
        ],
      ),
    );
  }
}

/// The field at the foot of the checklist. Enter adds the item at the end.
class _AddItemField extends ConsumerStatefulWidget {
  const _AddItemField({required this.task});

  final Task task;

  @override
  ConsumerState<_AddItemField> createState() => _AddItemFieldState();
}

class _AddItemFieldState extends ConsumerState<_AddItemField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    _controller.clear();
    final items = ref.read(checklistProvider(widget.task.id)).value ?? const <ChecklistItem>[];
    final writer = await ref.read(localWriterProvider.future);
    await writer.insert('checklist', {
      'task_id': widget.task.id,
      'title': title,
      'sort_order': nextSortOrder(items.map((i) => i.sortOrder)),
    });
    if (widget.task.kind != kChecklistKind) {
      await updateRow(ref, 'tasks', widget.task.id, {'kind': kChecklistKind});
    }
    ref.read(syncControllerProvider.notifier).requestSoon();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('addChecklistItemField'),
      controller: _controller,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(hintText: 'Add an item', prefixIcon: Icon(Icons.add), border: InputBorder.none),
      onSubmitted: (_) => _add(),
    );
  }
}
