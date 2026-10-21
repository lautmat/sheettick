import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

/// The live (not deleted) items of one task's checklist, in their order.
final checklistProvider = StreamProvider.family<List<ChecklistItem>, String>((ref, taskId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.checklist)
    ..where((c) => c.taskId.equals(taskId) & c.deleted.equals(false))
    ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.createdAt)]);
  return query.watch();
});
