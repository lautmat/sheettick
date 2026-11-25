import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/priority.dart';
import '../../core/tasks/task_bulk.dart';
import '../../core/tasks/tags.dart';
import '../../core/tasks/task_completion.dart';
import '../../core/tasks/task_dates.dart';
import '../../core/tasks/task_postpone.dart';
import '../../core/tasks/task_status.dart';
import '../common/undo.dart';
import 'bulk_tag_dialog.dart';
import 'postpone_action.dart';
import 'task_attributes.dart';
import 'task_drag.dart';
import 'task_selection.dart';

/// What the selection bar does to the picked tasks.
enum BulkAction {
  complete,
  today,
  tomorrow,
  nextWeek,
  noDate,

  /// Asks for a day and moves every picked task onto it.
  pickDate,

  /// Asks for a tag and adds it to every picked task.
  addTag,
  move,
  priorityHigh(Priority.high),
  priorityMedium(Priority.medium),
  priorityLow(Priority.low),
  priorityNone(Priority.none),
  trash;

  const BulkAction([this.priority]);

  /// The priority a "priority" action sets, null for the others.
  final Priority? priority;

  /// The date a "postpone" action moves to, null for the others.
  PostponeTarget? get postpone => switch (this) {
    today => PostponeTarget.today,
    tomorrow => PostponeTarget.tomorrow,
    nextWeek => PostponeTarget.nextWeek,
    noDate => PostponeTarget.noDate,
    _ => null,
  };
}

/// The line that takes the place of the app bar while a selection is under way: how many tasks are picked, Select all
/// and a way out.
class SelectionAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const SelectionAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(selectedTasksProvider).length;
    final shown = ref.watch(shownTasksProvider);
    return AppBar(
      leading: IconButton(
        key: const Key('selectionClose'),
        tooltip: 'Cancel selection',
        icon: const Icon(Icons.close),
        onPressed: () => ref.read(taskSelectionProvider.notifier).clear(),
      ),
      title: Text('$picked selected', key: const Key('selectionCount')),
      actions: [
        IconButton(
          key: const Key('selectAll'),
          tooltip: 'Select all',
          icon: const Icon(Icons.select_all),
          onPressed: picked == shown.length
              ? null
              : () => ref.read(taskSelectionProvider.notifier).select([for (final t in shown) t.id]),
        ),
      ],
    );
  }
}

/// The bar at the bottom while a selection is under way: Complete, Today, Tomorrow and Move, and More for the rest.
/// [onAction] does the work, so the bar can go on screen and off without cutting an action short.
class SelectionBar extends StatelessWidget {
  const SelectionBar({super.key, required this.onAction});

  final void Function(BulkAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget button(Key key, IconData icon, String label, BulkAction action) => Expanded(
      child: InkWell(
        key: key,
        onTap: () => onAction(action),
        child: _BarFace(icon: icon, label: label),
      ),
    );
    return Material(
      color: scheme.surfaceContainer,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              button(const Key('bulkComplete'), Icons.check_circle_outline, 'Complete', BulkAction.complete),
              button(const Key('bulkToday'), Icons.today, 'Today', BulkAction.today),
              button(const Key('bulkTomorrow'), Icons.event, 'Tomorrow', BulkAction.tomorrow),
              button(const Key('bulkMove'), Icons.drive_file_move_outlined, 'Move', BulkAction.move),
              Expanded(
                child: PopupMenuButton<BulkAction>(
                  key: const Key('bulkMore'),
                  tooltip: 'More',
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    const PopupMenuItem<BulkAction>(enabled: false, height: 32, child: Text('Postpone to')),
                    const PopupMenuItem(value: BulkAction.nextWeek, child: Text('Next week')),
                    const PopupMenuItem(value: BulkAction.noDate, child: Text('No date')),
                    const PopupMenuItem(value: BulkAction.pickDate, child: Text('Pick a date…')),
                    const PopupMenuDivider(),
                    const PopupMenuItem<BulkAction>(enabled: false, height: 32, child: Text('Priority')),
                    for (final p in const [
                      BulkAction.priorityHigh,
                      BulkAction.priorityMedium,
                      BulkAction.priorityLow,
                      BulkAction.priorityNone,
                    ])
                      PopupMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Icon(
                              p.priority == Priority.none ? Icons.outlined_flag : Icons.flag,
                              color: priorityColor(p.priority!),
                            ),
                            const SizedBox(width: 12),
                            Text(p.priority!.label),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: BulkAction.addTag, child: Text('Add tag…')),
                    const PopupMenuItem(value: BulkAction.trash, child: Text('Move to Trash')),
                  ],
                  child: const _BarFace(icon: Icons.more_horiz, label: 'More'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An icon over a short label: one button of the bar.
class _BarFace extends StatelessWidget {
  const _BarFace({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

void _say(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Does [action] to [tasks], then ends the selection. Everything is one write that Undo reverses. An action that would
/// change nothing, or a question that is dismissed, leaves the selection as it was. [context] and [ref] must be the
/// ones of a widget that stays on screen while the selection comes and goes.
Future<void> runBulkAction(BuildContext context, WidgetRef ref, List<Task> tasks, BulkAction action) async {
  if (tasks.isEmpty) return;
  final selection = ref.read(taskSelectionProvider.notifier);
  final target = action.postpone;
  final priority = action.priority;

  if (target != null) {
    final changed = await postponeWithUndo(ref, tasks, target);
    if (changed > 0) {
      selection.clear();
    } else if (context.mounted) {
      _say(context, target == PostponeTarget.noDate ? 'None of them has a date.' : 'Nothing to change: they are already there.');
    }
    return;
  }

  if (priority != null) {
    final changing = [for (final t in tasks) if (Priority.of(t.priority) != priority) t];
    if (changing.isEmpty) {
      _say(context, 'Already ${priority.label.toLowerCase()} priority.');
      return;
    }
    selection.clear();
    await changeWithUndo<void>(
      ref,
      changing.length == 1 ? 'Priority changed' : 'Priority changed on ${changing.length} tasks',
      [for (final t in changing) (tab: 'tasks', id: t.id)],
      (writer) async {
        for (final t in changing) {
          await writer.update('tasks', t.id, {'priority': priority.value});
        }
      },
    );
    return;
  }

  switch (action) {
    case BulkAction.complete:
      final open = [for (final t in tasks) if (t.status == TaskStatus.open.value) t];
      if (open.isEmpty) {
        _say(context, 'Those tasks are not open.');
        return;
      }
      selection.clear();
      final zone = await ref.read(deviceZoneProvider.future);
      final now = DateTime.now();
      // Finishing a repeating task also creates its next round, which undoing tombstones again.
      await changeWithUndo<List<String>>(
        ref,
        open.length == 1 ? 'Task completed' : '${open.length} tasks completed',
        [for (final t in open) (tab: 'tasks', id: t.id)],
        (writer) async {
          final next = <String>[];
          for (final t in open) {
            final id = await setTaskStatus(writer, t, TaskStatus.completed, now: now, zone: zone);
            if (id != null) next.add(id);
          }
          return next;
        },
        created: (next) => [for (final id in next) (tab: 'tasks', id: id)],
      );
    case BulkAction.pickDate:
      final zone = await ref.read(deviceZoneProvider.future);
      final today = TaskDates(zone: zone).wallOf(DateTime.now());
      if (!context.mounted) return;
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(today.year, today.month, today.day),
        firstDate: DateTime(today.year - 1),
        lastDate: DateTime(today.year + 5),
        helpText: tasks.length == 1 ? 'Due date' : 'Due date for ${tasks.length} tasks',
      );
      if (picked == null) return;
      if (await moveToDayWithUndo(ref, tasks, dayOf(picked)) > 0) {
        selection.clear();
      } else if (context.mounted) {
        _say(context, 'Nothing to change: they are already there.');
      }
    case BulkAction.addTag:
      final known = await readTagNames(ref.read(appDatabaseProvider));
      if (!context.mounted) return;
      final name = cleanTagName(await askTagName(context, count: tasks.length, known: known) ?? '');
      if (name == null) return;
      final lacking = [for (final t in tasks) if (indexOfTag(parseTags(t.tags), name) < 0) t];
      if (lacking.isEmpty) {
        if (context.mounted) _say(context, tasks.length == 1 ? 'It already has #$name.' : 'They all have #$name.');
        return;
      }
      selection.clear();
      // A tag that is new to the `tags` tab is made with the change, so undoing it takes the tag away too.
      await changeWithUndo<String?>(
        ref,
        lacking.length == 1 ? 'Tag added' : 'Tag added to ${lacking.length} tasks',
        [for (final t in lacking) (tab: 'tasks', id: t.id)],
        (writer) async => (await addTagToTasks(writer, [for (final t in lacking) t.id], name))?.createdId,
        created: (tagId) => [if (tagId != null) (tab: 'tags', id: tagId)],
      );
    case BulkAction.move:
      if (await moveTasksToList(context, ref, tasks)) selection.clear();
    case BulkAction.trash:
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tasks.length == 1 ? 'Move this task to Trash?' : 'Move ${tasks.length} tasks to Trash?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              key: const Key('confirmTrash'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Move to Trash'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      selection.clear();
      final writer = await ref.read(localWriterProvider.future);
      final ids = [for (final t in tasks) t.id];
      final rows = [for (final id in await withSubtasks(writer, ids)) (tab: 'tasks', id: id)];
      await changeWithUndo<int>(
        ref,
        tasks.length == 1 ? 'Task moved to Trash' : '${tasks.length} tasks moved to Trash',
        rows,
        (writer) => trashTasks(writer, ids),
      );
    default:
      break;
  }
}
