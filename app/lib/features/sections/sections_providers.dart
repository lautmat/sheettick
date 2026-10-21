import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

/// The live (not deleted) sections of one list, in their order.
final sectionsProvider = StreamProvider.family<List<Section>, String>((ref, listId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.sections)
    ..where((s) => s.listId.equals(listId) & s.deleted.equals(false))
    ..orderBy([(s) => OrderingTerm.asc(s.sortOrder), (s) => OrderingTerm.asc(s.name)]);
  return query.watch();
});
