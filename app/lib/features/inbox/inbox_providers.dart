import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

/// Open and completed tasks of a list, subtasks included: open first, then completed. Won't-do tasks and tombstones
/// are not shown. The order of subtasks under their parents is worked out by `arrangeTree`.
final listTasksProvider = StreamProvider.family<List<Task>, String>((ref, listId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.tasks)
    ..where((t) => t.listId.equals(listId) & t.deleted.equals(false) & t.status.isIn(const [0, 2]))
    ..orderBy([
      (t) => OrderingTerm.asc(t.status),
      (t) => OrderingTerm.asc(t.sortOrder),
      (t) => OrderingTerm.asc(t.createdAt),
    ]);
  return query.watch();
});

/// Whether the Completed tasks at the foot of a list are folded away, as TickTick folds them. Kept on this device in
/// `device_state` (so it survives a restart and never reaches the Sheet); until it is read, the tasks are shown.
class CompletedCollapsed extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final stored = await ref.watch(appDatabaseProvider).getDeviceState(DeviceStateKeys.completedCollapsed);
    return stored == 'true';
  }

  /// Folds the Completed tasks if they are shown, and shows them if folded. The write comes first, so a failing write
  /// leaves the app showing the choice that is still stored.
  Future<void> toggle() async {
    final next = !(state.value ?? false);
    await ref.read(appDatabaseProvider).setDeviceState(DeviceStateKeys.completedCollapsed, '$next');
    state = AsyncData(next);
  }
}

final completedCollapsedProvider = AsyncNotifierProvider<CompletedCollapsed, bool>(CompletedCollapsed.new);
