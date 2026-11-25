import 'package:flutter/gestures.dart' show GestureBinding, PointerMoveEvent, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/task_bulk.dart';
import '../../core/tasks/task_move.dart';
import '../common/undo.dart';
import '../lists/lists_providers.dart';
import 'task_selection.dart';

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
Future<void> moveTaskToList(BuildContext context, WidgetRef ref, Task task) => moveTasksToList(context, ref, [task]);

/// [moveTaskToList] for several tasks at once: they go to the end of the list asked for, in the order given, with their
/// subtasks, and one Undo puts them all back. The list they are all in already is not offered. Returns whether they moved
/// (false: the question was dismissed, or nothing had to move).
Future<bool> moveTasksToList(BuildContext context, WidgetRef ref, List<Task> tasks) async {
  final here = {for (final t in tasks) t.listId};
  final lists = (await ref.read(sidebarListsProvider.future))
      .where((l) => !l.archived && !(here.length == 1 && here.single == l.id))
      .toList();
  if (!context.mounted) return false;
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
  if (picked == null) return false;
  final ids = [for (final t in tasks) if (t.listId != picked.id) t.id];
  if (ids.isEmpty) return false;
  final writer = await ref.read(localWriterProvider.future);
  final rows = await bulkMoveRows(writer, ids, picked.id);
  final label = ids.length == 1 ? 'Moved to ${picked.name}' : '${ids.length} tasks moved to ${picked.name}';
  final moved = await changeWithUndo<int>(ref, label, rows, (writer) => moveTasksToListEnd(writer, ids, picked.id));
  return moved > 0;
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

/// Whether the platform is a touch one, where a finger drags and a mouse does not.
bool isTouchPlatform(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

/// Makes a top-level task's row draggable, and, with [reorder], a place to drop another task before it.
///
/// A mouse drags at once. A finger long-presses first, so that a swipe still scrolls the list; the task is then held,
/// and what happens next depends on the finger: moving it drags the task, lifting it without moving starts a selection
/// with this task in it (see [TaskSelection]). While a selection is under way a row is not dragged: a tap picks it.
/// Subtasks (depth above 0) are not dragged on their own: they move with their task, and Indent and Outdent change their
/// place.
class TaskDragShell extends ConsumerStatefulWidget {
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
  ConsumerState<TaskDragShell> createState() => _TaskDragShellState();
}

class _TaskDragShellState extends ConsumerState<TaskDragShell> {
  /// How far the held finger has gone since the task was picked up, and whether that was far enough to be a drag.
  double _travelled = 0;
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final child = widget.child;
    if (widget.depth > 0 || ref.watch(selectingProvider)) return child;
    final dragging = ref.read(draggingTaskProvider.notifier);
    final selection = ref.read(taskSelectionProvider.notifier);
    final feedback = _Feedback(title: task.title);
    final source = isTouchPlatform(context)
        ? LongPressDraggable<Task>(
            data: task,
            feedback: feedback,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            childWhenDragging: Opacity(opacity: 0.4, child: child),
            onDragStarted: () {
              _travelled = 0;
              _moved = false;
              HapticFeedback.selectionClick();
            },
            onDragUpdate: (details) {
              _travelled += details.delta.distance;
              // The drop spots appear only once it is a drag, so a hold that turns into a selection moves nothing.
              if (!_moved && _travelled > kTouchSlop) {
                _moved = true;
                dragging.start(task);
              }
            },
            onDragEnd: (_) {
              dragging.stop();
              if (!_moved) selection.add(task.id);
              _moved = false;
            },
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
    if (!widget.reorder) return source;
    return TaskDropTarget(
      line: true,
      accepts: (dragged) => dragged.id != task.id,
      onDrop: (dragged) =>
          moveTaskTo(ref, dragged, listId: widget.listId, sectionId: widget.section, beforeId: task.id),
      child: source,
    );
  }
}

/// Scrolls the list under it while a task is dragged near its top or bottom edge, faster the closer to the edge, so a
/// task can be dropped further than the first screenful. [builder] makes the scrolling list and must give it the
/// controller.
///
/// A plain `Draggable` does not scroll anything by itself. The finger's place comes from the pointer events that pass
/// through here, and the scrolling runs for as long as a task is being dragged (see [draggingTaskProvider]).
class DragAutoScroll extends ConsumerStatefulWidget {
  const DragAutoScroll({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollController controller) builder;

  @override
  ConsumerState<DragAutoScroll> createState() => _DragAutoScrollState();
}

class _DragAutoScrollState extends ConsumerState<DragAutoScroll> with SingleTickerProviderStateMixin {
  /// How deep the scrolling zone at each edge is, and how fast it scrolls (pixels a second) at the very edge.
  static const _zone = 96.0;
  static const _topSpeed = 1100.0;

  final _controller = ScrollController();
  late final Ticker _ticker = createTicker(_onTick);
  double? _pointerY;

  /// The last move of the finger (or mouse) that drags, to say it again after the list has scrolled under it.
  PointerMoveEvent? _lastMove;
  Duration _last = Duration.zero;

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDragging(Task? dragged) {
    if (dragged == null) {
      _ticker.stop();
      return;
    }
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final seconds = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    final y = _pointerY;
    final box = context.findRenderObject();
    if (y == null || box is! RenderBox || !box.attached || !_controller.hasClients) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final double depth;
    if (y < top + _zone) {
      depth = -((top + _zone - y) / _zone).clamp(0.0, 1.0).toDouble();
    } else if (y > bottom - _zone) {
      depth = ((y - (bottom - _zone)) / _zone).clamp(0.0, 1.0).toDouble();
    } else {
      return;
    }
    final position = _controller.position;
    final target = (position.pixels + depth * _topSpeed * seconds).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return;
    position.jumpTo(target.toDouble());
    // The list moved under a finger that did not, and a drag only looks at what is under the finger when the finger
    // moves. Without a nudge the drop spot (and the line that shows it) would stay on a row that has scrolled away,
    // and lifting the finger would drop the task there. The new layout is needed first, hence the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _repeatPointer());
  }

  /// Says again where the finger is, with no movement: the drag finds the row under it in the list as it is now.
  void _repeatPointer() {
    final last = _lastMove;
    if (!mounted || last == null || !_ticker.isActive) return;
    GestureBinding.instance.pointerRouter.route(last.copyWith(delta: Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(draggingTaskProvider, (_, dragged) => _onDragging(dragged));
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _pointerY = e.position.dy;
        _lastMove = null;
      },
      onPointerMove: (e) {
        _pointerY = e.position.dy;
        _lastMove = e;
      },
      child: widget.builder(context, _controller),
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
