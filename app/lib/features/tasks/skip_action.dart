import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/task_skip.dart';
import '../common/undo.dart';

/// Moves the repeating [task] to its next occurrence (see [skipOccurrence]) and offers to undo it. When the series has
/// no occurrence left it says so and changes nothing.
Future<void> skipTaskOccurrence(BuildContext context, WidgetRef ref, Task task) async {
  final zone = await ref.read(deviceZoneProvider.future);
  final writer = await ref.read(localWriterProvider.future);
  final ticked = await checklistItemIds(writer, task.id, onlyTicked: true);
  final outcome = await changeWithUndo<SkipOutcome>(
    ref,
    'Occurrence skipped',
    [(tab: 'tasks', id: task.id), for (final id in ticked) (tab: 'checklist', id: id)],
    (w) => skipOccurrence(w, task, zone: zone),
  );
  if (outcome == SkipOutcome.noMoreOccurrences && context.mounted) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('No more occurrences. Complete the task to finish it.')));
  }
}
