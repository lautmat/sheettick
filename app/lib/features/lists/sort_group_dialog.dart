import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/tasks/task_order.dart';
import '../common/local_edit.dart';
import 'lists_providers.dart';

/// App bar button that opens [SortGroupDialog] for [list].
class SortGroupButton extends StatelessWidget {
  const SortGroupButton({super.key, required this.list});

  final TaskList list;

  @override
  Widget build(BuildContext context) {
    final active = TaskOrder.of(list.orderBy) != TaskOrder.manual || TaskGroup.of(list.groupBy) != TaskGroup.none;
    return IconButton(
      key: const Key('sortGroupButton'),
      tooltip: 'Sort and group',
      icon: Icon(Icons.sort, color: active ? Theme.of(context).colorScheme.primary : null),
      onPressed: () => showDialog<void>(context: context, builder: (_) => SortGroupDialog(listId: list.id)),
    );
  }
}

/// How the tasks of one list are ordered and grouped. A choice is written to the list's `order_by` or `group_by` at
/// once, so it is saved with the list and syncs with it.
class SortGroupDialog extends ConsumerWidget {
  const SortGroupDialog({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(sidebarListsProvider).value ?? const <TaskList>[];
    final list = lists.where((l) => l.id == listId).firstOrNull;
    final order = TaskOrder.of(list?.orderBy);
    final group = TaskGroup.of(list?.groupBy);
    return AlertDialog(
      title: const Text('Sort and group'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sort by'),
          DropdownButton<TaskOrder>(
            key: const Key('orderByField'),
            isExpanded: true,
            value: order,
            items: [for (final o in TaskOrder.values) DropdownMenuItem(value: o, child: Text(o.label))],
            // Manual is the default, stored as no value rather than as text.
            onChanged: (o) => o == null ? null : updateRow(ref, 'lists', listId, {'order_by': o.value.isEmpty ? null : o.value}),
          ),
          const SizedBox(height: 16),
          const Text('Group by'),
          DropdownButton<TaskGroup>(
            key: const Key('groupByField'),
            isExpanded: true,
            value: group,
            items: [for (final g in TaskGroup.values) DropdownMenuItem(value: g, child: Text(g.label))],
            onChanged: (g) =>
                g == null ? null : updateRow(ref, 'lists', listId, {'group_by': g.value.isEmpty ? null : g.value}),
          ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    );
  }
}
