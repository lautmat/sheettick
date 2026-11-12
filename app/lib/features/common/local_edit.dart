import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import 'undo.dart';

/// Writes [changes] to the row [id] of [tab] through the local writer, then asks for a sync. With [undo], the change is
/// also offered for undoing, under that name ("Priority changed").
Future<void> updateRow(WidgetRef ref, String tab, String id, Map<String, Object?> changes, {String? undo}) async {
  if (undo != null) {
    await changeWithUndo<void>(ref, undo, [(tab: tab, id: id)], (writer) => writer.update(tab, id, changes));
    return;
  }
  final writer = await ref.read(localWriterProvider.future);
  await writer.update(tab, id, changes);
  ref.read(syncControllerProvider.notifier).requestSoon();
}

/// One step after the highest order in [orders]: where a new row goes at the end of its group.
double nextSortOrder(Iterable<double> orders) => orders.fold<double>(0, (m, v) => v > m ? v : m) + 1;
