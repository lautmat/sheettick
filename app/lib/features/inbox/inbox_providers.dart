import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

/// The Inbox list, or null until the first sign-in has created it in the Sheet and synced it down.
final inboxListProvider = StreamProvider<TaskList?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.lists)
    ..where((l) => l.isInbox.equals(true) & l.deleted.equals(false))
    ..limit(1);
  return query.watchSingleOrNull();
});

/// Open and completed top-level tasks of a list: open first, then completed. Won't-do tasks and tombstones
/// are not shown.
final listTasksProvider = StreamProvider.family<List<Task>, String>((ref, listId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.tasks)
    ..where(
      (t) =>
          t.listId.equals(listId) &
          t.deleted.equals(false) &
          t.parentId.isNull() &
          t.status.isIn(const [0, 2]),
    )
    ..orderBy([
      (t) => OrderingTerm.asc(t.status),
      (t) => OrderingTerm.asc(t.sortOrder),
      (t) => OrderingTerm.asc(t.createdAt),
    ]);
  return query.watch();
});
