import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';

/// Writes [changes] to the row [id] of [tab] through the local writer, then asks for a sync.
Future<void> updateRow(WidgetRef ref, String tab, String id, Map<String, Object?> changes) async {
  final writer = await ref.read(localWriterProvider.future);
  await writer.update(tab, id, changes);
  ref.read(syncControllerProvider.notifier).requestSoon();
}

/// One step after the highest order in [orders]: where a new row goes at the end of its group.
double nextSortOrder(Iterable<double> orders) => orders.fold<double>(0, (m, v) => v > m ? v : m) + 1;
