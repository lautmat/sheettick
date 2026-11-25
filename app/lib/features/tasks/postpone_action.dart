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

/// Postpones [tasks] to [target] in one write through the local writer and offers to undo it. Only the tasks it would
/// change are written and counted. Returns how many that was (0: nothing was written and there is nothing to undo).
Future<int> postponeWithUndo(WidgetRef ref, List<Task> tasks, PostponeTarget target) async {
  final zone = await ref.read(deviceZoneProvider.future);
  final now = DateTime.now();
  final changing = [for (final t in tasks) if (postponeChanges(t, target, now: now, zone: zone)) t];
  if (changing.isEmpty) return 0;
  final one = changing.length == 1;
  final label = target == PostponeTarget.noDate
      ? (one ? 'Date removed' : 'Dates removed')
      : (one ? 'Task postponed' : '${changing.length} tasks postponed');
  await changeWithUndo<int>(
    ref,
    label,
    [for (final t in changing) (tab: 'tasks', id: t.id)],
    (writer) => postponeTasks(writer, changing, target, now: now, zone: zone),
  );
  return changing.length;
}
