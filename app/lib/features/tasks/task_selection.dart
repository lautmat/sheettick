import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/task_bulk.dart';
import '../../core/tasks/task_order.dart';
import '../inbox/inbox_providers.dart';
import '../lists/lists_providers.dart';
import '../sections/sections_providers.dart';
import '../smart/smart_providers.dart';

/// The ids of the tasks picked for a batch edit. Empty means no selection, and the screen is as usual.
///
/// The selection belongs to the list it was made in: showing another list or smart list drops it.
class TaskSelection extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.listen(selectedListIdProvider, (_, _) => clear());
    ref.listen(selectedSmartListProvider, (_, _) => clear());
    return const {};
  }

  bool contains(String id) => state.contains(id);

  /// Picks [id] if it is not picked, drops it if it is. Dropping the last one ends the selection.
  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  /// Starts a selection with just [id], or adds it to the one under way.
  void add(String id) => state = {...state, id};

  /// Replaces the selection by [ids].
  void select(Iterable<String> ids) => state = {...ids};

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}

final taskSelectionProvider = NotifierProvider<TaskSelection, Set<String>>(TaskSelection.new);

/// Whether a selection is under way. Rows then show a tick instead of their check box and a tap picks them.
final selectingProvider = Provider<bool>((ref) => ref.watch(taskSelectionProvider).isNotEmpty);

/// The tasks on screen, in the order the list sorts them: those of the smart list or of the list shown. A task that a
/// folded section hides is not among them, so "select all" never picks what cannot be seen. Empty while loading.
final shownTasksProvider = Provider<List<Task>>((ref) {
  final smart = ref.watch(selectedSmartListProvider);
  if (smart != null) return ref.watch(smartListRowsProvider(smart)).value ?? const <Task>[];
  final list = ref.watch(activeListProvider).value;
  if (list == null) return const <Task>[];
  final tasks = ref.watch(listTasksProvider(list.id)).value ?? const <Task>[];
  final ordered = sortTasks(tasks, TaskOrder.of(list.orderBy), zone: ref.watch(deviceZoneProvider).value);
  // Grouped, a list ignores its sections, so nothing is folded away.
  if (TaskGroup.of(list.groupBy) != TaskGroup.none) return ordered;
  final folded = {
    for (final s in ref.watch(sectionsProvider(list.id)).value ?? const <Section>[])
      if (s.collapsed) s.id,
  };
  final hidden = hiddenByFolding(ordered, folded);
  return [
    for (final t in ordered)
      if (!hidden.contains(t.id)) t,
  ];
});

/// The picked tasks that are still on screen, in the order they are shown. A task that left (done, moved, synced away)
/// drops out of the batch.
final selectedTasksProvider = Provider<List<Task>>((ref) {
  final ids = ref.watch(taskSelectionProvider);
  if (ids.isEmpty) return const <Task>[];
  return [
    for (final t in ref.watch(shownTasksProvider))
      if (ids.contains(t.id)) t,
  ];
});
