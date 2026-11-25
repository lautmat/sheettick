import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/tasks/task_postpone.dart';
import 'selection_bar.dart';

/// Makes a task row swipe, on a touch screen: right completes the task (or reopens it, when it is done), left asks what
/// to do with it (see [showSwipeChoices]).
///
/// The row never leaves: both swipes do their work and the row springs back, so the list changes only when the data
/// does, and Undo is the one in the snackbar. A swipe needs a move along the row before it starts, while a drag begins
/// with a long press, so the two do not meet.
class TaskSwipe extends StatelessWidget {
  const TaskSwipe({
    super.key,
    required this.task,
    required this.done,
    required this.onToggle,
    required this.onChoose,
    required this.child,
  });

  final Task task;

  /// Whether the task is done: swiping right then reopens it, and there is no left swipe.
  final bool done;
  final Future<void> Function() onToggle;
  final Future<void> Function() onChoose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('swipe-${task.id}'),
      direction: done ? DismissDirection.startToEnd : DismissDirection.horizontal,
      background: _Backdrop(
        color: scheme.primaryContainer,
        onColor: scheme.onPrimaryContainer,
        alignment: AlignmentDirectional.centerStart,
        icon: done ? Icons.undo : Icons.check,
        label: done ? 'Reopen' : 'Complete',
      ),
      secondaryBackground: _Backdrop(
        color: scheme.tertiaryContainer,
        onColor: scheme.onTertiaryContainer,
        alignment: AlignmentDirectional.centerEnd,
        icon: Icons.more_horiz,
        label: 'Date, move, delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onToggle();
        } else {
          await onChoose();
        }
        return false;
      },
      child: child,
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.color,
    required this.onColor,
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Color color;
  final Color onColor;
  final AlignmentGeometry alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: onColor),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: onColor)),
        ],
      ),
    );
  }
}

/// What a left swipe offers for [task]: the dates it would change to, Move to list when [canMove], and Move to Trash.
/// Returns the choice, or null when the sheet is dismissed.
Future<BulkAction?> showSwipeChoices(
  BuildContext context,
  Task task, {
  required DateTime now,
  required String? zone,
  required bool canMove,
}) {
  final dates = [
    (BulkAction.today, PostponeTarget.today, Icons.today, 'Today'),
    (BulkAction.tomorrow, PostponeTarget.tomorrow, Icons.event, 'Tomorrow'),
    (BulkAction.nextWeek, PostponeTarget.nextWeek, Icons.date_range, 'Next week'),
    (BulkAction.noDate, PostponeTarget.noDate, Icons.event_busy, 'No date'),
  ];
  return showModalBottomSheet<BulkAction>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (action, target, icon, label) in dates)
            if (postponeChanges(task, target, now: now, zone: zone))
              ListTile(
                key: Key('swipe-${action.name}'),
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.pop(sheet, action),
              ),
          if (canMove)
            ListTile(
              key: const Key('swipe-move'),
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('Move to list'),
              onTap: () => Navigator.pop(sheet, BulkAction.move),
            ),
          ListTile(
            key: const Key('swipe-trash'),
            leading: const Icon(Icons.delete_outline),
            title: const Text('Move to Trash'),
            onTap: () => Navigator.pop(sheet, BulkAction.trash),
          ),
        ],
      ),
    ),
  );
}
