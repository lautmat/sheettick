import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/task_postpone.dart';
import '../common/undo.dart';

const _prefix = 'postpone:';

/// The menu value for [target], so a menu can tell a postpone choice from its other items.
String postponeValue(PostponeTarget target) => '$_prefix${target.name}';

/// The target a menu value names, or null when [value] is not a postpone choice.
PostponeTarget? postponeTargetOf(String value) {
  if (!value.startsWith(_prefix)) return null;
  final name = value.substring(_prefix.length);
  return PostponeTarget.values.where((t) => t.name == name).firstOrNull;
}

/// The "Postpone to" part of a task's menu: Today, Tomorrow, Next week and No date, each only when it would change
/// something for [task] (a task due today has no "Today", an undated task no "No date"). Empty for a task that is not
/// open or has nothing to offer.
List<PopupMenuEntry<String>> postponeMenuEntries(Task task, {required DateTime now, String? zone}) {
  final targets = [for (final t in PostponeTarget.values) if (postponeChanges(task, t, now: now, zone: zone)) t];
  if (targets.isEmpty) return const [];
  return [
    const PopupMenuDivider(),
    const PopupMenuItem<String>(enabled: false, height: 32, child: Text('Postpone to')),
    for (final t in targets) PopupMenuItem<String>(value: postponeValue(t), child: Text(t.label)),
  ];
}

/// Postpones [tasks] to [target] in one write through the local writer and offers to undo it.
Future<void> postponeWithUndo(WidgetRef ref, List<Task> tasks, PostponeTarget target) async {
  final zone = await ref.read(deviceZoneProvider.future);
  final one = tasks.length == 1;
  final label = target == PostponeTarget.noDate
      ? (one ? 'Date removed' : 'Dates removed')
      : (one ? 'Task postponed' : '${tasks.length} tasks postponed');
  await changeWithUndo<int>(
    ref,
    label,
    [for (final t in tasks) (tab: 'tasks', id: t.id)],
    (writer) => postponeTasks(writer, tasks, target, now: DateTime.now(), zone: zone),
  );
}
