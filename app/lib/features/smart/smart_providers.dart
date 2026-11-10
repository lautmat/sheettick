import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/smart_lists.dart';
import '../reminders/reminders_providers.dart';

/// The ids of the lists that are deleted or archived: their tasks are left out of the smart lists.
final hiddenListIdsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.lists)..where((l) => l.deleted.equals(true) | l.archived.equals(true));
  return query.watch().map((rows) => {for (final l in rows) l.id});
});

/// The tasks a smart list shows, in its order. Loading until the tasks, the lists and the device zone are known, so
/// "today" is never worked out in the wrong zone.
///
/// Trash keeps its tasks whatever list they were in; the other lists leave out the tasks of a deleted or archived list.
final smartListRowsProvider = Provider.family<AsyncValue<List<Task>>, SmartList>((ref, list) {
  final tasks = ref.watch(allTasksProvider);
  final hidden = ref.watch(hiddenListIdsProvider);
  final zone = ref.watch(deviceZoneProvider);
  if (tasks.hasError) return AsyncError(tasks.error!, tasks.stackTrace ?? StackTrace.empty);
  if (hidden.hasError) return AsyncError(hidden.error!, hidden.stackTrace ?? StackTrace.empty);
  final taskRows = tasks.value;
  final hiddenIds = hidden.value;
  if (taskRows == null || hiddenIds == null || zone.isLoading) return const AsyncLoading();
  final visible = list == SmartList.trash
      ? taskRows
      : taskRows.where((t) => !hiddenIds.contains(t.listId));
  return AsyncData(smartListRows(list, visible, now: DateTime.now(), zone: zone.value));
});
