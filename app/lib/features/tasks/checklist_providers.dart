import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/providers.dart';

/// The live (not deleted) items of one task's checklist, in their order.
SimpleSelectStatement<Checklist, ChecklistItem> _itemsOf(AppDatabase db, String taskId) {
  return db.select(db.checklist)
    ..where((c) => c.taskId.equals(taskId) & c.deleted.equals(false))
    ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.createdAt)]);
}

final checklistProvider = StreamProvider.family<List<ChecklistItem>, String>((ref, taskId) {
  return _itemsOf(ref.watch(appDatabaseProvider), taskId).watch();
});

/// The items as the database holds them right now. Read this, not the last value of [checklistProvider], before a
/// write that depends on the current order: the stream may not have caught up with the write before it.
Future<List<ChecklistItem>> checklistNow(AppDatabase db, String taskId) => _itemsOf(db, taskId).get();
