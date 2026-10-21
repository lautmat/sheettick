import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

/// One task row, live. Null once the row no longer exists.
final taskProvider = StreamProvider.family<Task?, String>((ref, id) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.tasks)..where((t) => t.id.equals(id))).watchSingleOrNull();
});
