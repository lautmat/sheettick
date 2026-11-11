import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/task_move.dart';
import '../common/undo.dart';
import '../lists/lists_providers.dart';

/// The task being dragged, or null. The list shows its extra drop spots (no section, end of the list) only then.
class DraggingTask extends Notifier<Task?> {
  @override
  Task? build() => null;

  void start(Task task) => state = task;

  void stop() => state = null;
}

final draggingTaskProvider = NotifierProvider<DraggingTask, Task?>(DraggingTask.new);

/// Puts [task] in the list [listId], in the section [sectionId] (null: outside any section), just before the task
/// [beforeId] (null: at the end), and offers to undo it. Does nothing when it is dropped where it already is.
Future<void> moveTaskTo(
  WidgetRef ref,
  Task task, {
  required String listId,
  String? sectionId,
  String? beforeId,
  String? label,
}) async {
  final writer = await ref.read(localWriterProvider.future);
  final plan = await planMove(writer, task.id, listId: listId, sectionId: sectionId, beforeId: beforeId);
  if (plan.isEmpty) return;
  final moved = task.listId != listId || task.sectionId != sectionId;
  await changeWithUndo<void>(
    ref,
    label ?? (moved ? 'Task moved' : 'Task reordered'),
    plan.rows,
    (writer) => applyMove(writer, plan),
  );
}

/// Asks which list a task goes to, and moves it to the end of that list, outside any section. The same move as dragging
/// it onto a list in the sidebar, for when the sidebar is a drawer and cannot be dropped on.
Future<void> moveTaskToList(BuildContext context, WidgetRef ref, Task task) async {
  final lists = (await ref.read(sidebarListsProvider.future)).where((l) => !l.archived && l.id != task.listId).toList();
  if (!context.mounted) return;
  final picked = await showDialog<TaskList>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('Move to list'),
      children: [
        for (final l in lists)
          SimpleDialogOption(
            key: Key('moveTo-${l.id}'),
            onPressed: () => Navigator.pop(context, l),
            child: Text(l.name.isEmpty ? '(untitled)' : l.name),
          ),
      ],
    ),
  );
  if (picked == null) return;
  await moveTaskTo(ref, task, listId: picked.id, label: 'Moved to ${picked.name}');
}

/// Where a dragged task can be dropped: [onDrop] runs with it. While a task hovers over it, it is drawn as a line above
/// the child ([line]) or as a tinted background.
class TaskDropTarget extends StatelessWidget {
  const TaskDropTarget({
    super.key,
    required this.accepts,
    required this.onDrop,
    required this.child,
    this.line = false,
  });

  final bool Function(Task dragged) accepts;
  final void Function(Task dragged) onDrop;
  final Widget child;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => accepts(d.data),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, hovering, _) {
        if (hovering.isEmpty) return child;
        if (line) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [Container(height: 3, color: primary), child],
          );
        }
        // A Material, not a DecoratedBox: a ListTile paints its background on the nearest Material and would hide a tint.
        return Material(color: primary.withValues(alpha: 0.12), child: child);
      },
    );
  }
}

/// A drop spot that shows only while a task is being dragged, such as "No section" above the first section.
class DropRow extends ConsumerWidget {
  const DropRow({super.key, required this.label, required this.accepts, required this.onDrop});

  final String label;
  final bool Function(Task dragged) accepts;
  final void Function(WidgetRef ref, Task dragged) onDrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dragged = ref.watch(draggingTaskProvider);
    if (dragged == null || !accepts(dragged)) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return TaskDropTarget(
      accepts: accepts,
      onDrop: (dragged) => onDrop(ref, dragged),
      child: Container(
        height: 40,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsetsDirectional.only(start: 16),
        child: Text(label, style: TextStyle(color: muted, fontStyle: FontStyle.italic)),
      ),
    );
  }
}

/// Makes a top-level task's row draggable, and, with [reorder], a place to drop another task before it.
///
/// A mouse drags at once; a finger long-presses first, so that a swipe still scrolls the list. Subtasks (depth above 0)
/// are not dragged on their own: they move with their task, and Indent and Outdent change their place.
class TaskDragShell extends ConsumerWidget {
  const TaskDragShell({
    super.key,
    required this.task,
    required this.depth,
    required this.listId,
    required this.section,
    required this.reorder,
    required this.child,
  });

  final Task task;
  final int depth;

  /// The list on screen, and the section this row is shown in (null: outside any section).
  final String listId;
  final String? section;

  /// Whether another task can be dropped before this one: only when the list is in its manual order.
  final bool reorder;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (depth > 0) return child;
    final dragging = ref.read(draggingTaskProvider.notifier);
    final platform = Theme.of(context).platform;
    final touch = platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    final feedback = _Feedback(title: task.title);
    final source = touch
        ? LongPressDraggable<Task>(
            data: task,
            feedback: feedback,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            childWhenDragging: Opacity(opacity: 0.4, child: child),
            onDragStarted: () => dragging.start(task),
            onDragEnd: (_) => dragging.stop(),
            child: child,
          )
        : Draggable<Task>(
            data: task,
            feedback: feedback,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            childWhenDragging: Opacity(opacity: 0.4, child: child),
            onDragStarted: () => dragging.start(task),
            onDragEnd: (_) => dragging.stop(),
            child: child,
          );
    if (!reorder) return source;
    return TaskDropTarget(
      line: true,
      accepts: (dragged) => dragged.id != task.id,
      onDrop: (dragged) => moveTaskTo(ref, dragged, listId: listId, sectionId: section, beforeId: task.id),
      child: source,
    );
  }
}

/// What follows the pointer while a task is dragged.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(title.isEmpty ? '(untitled)' : title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
