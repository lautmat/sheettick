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
