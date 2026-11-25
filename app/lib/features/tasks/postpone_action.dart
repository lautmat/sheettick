import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/task_dates.dart';
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
  final day = postponeDay(target, TaskDates(zone: zone).wallOf(DateTime.now()));
  return _moveWithUndo(
    ref,
    tasks,
    day,
    zone,
    target == PostponeTarget.noDate
        ? (n) => n == 1 ? 'Date removed' : 'Dates removed'
        : (n) => n == 1 ? 'Task postponed' : '$n tasks postponed',
  );
}

/// Moves [tasks] onto the calendar [day] (a UTC midnight) in one write and offers to undo it, as [postponeWithUndo] does
/// for a named target. Returns how many tasks changed.
Future<int> moveToDayWithUndo(WidgetRef ref, List<Task> tasks, DateTime day) async {
  final zone = await ref.read(deviceZoneProvider.future);
  return _moveWithUndo(ref, tasks, day, zone, (n) => n == 1 ? 'Task rescheduled' : '$n tasks rescheduled');
}

/// Writes the move for the tasks it would change, labelled by [label] for how many that is.
Future<int> _moveWithUndo(
  WidgetRef ref,
  List<Task> tasks,
  DateTime? day,
  String? zone,
  String Function(int changed) label,
) async {
  final changing = [for (final t in tasks) if (dayChanges(t, day, zone: zone)) t];
  if (changing.isEmpty) return 0;
  await changeWithUndo<int>(
    ref,
    label(changing.length),
    [for (final t in changing) (tab: 'tasks', id: t.id)],
    (writer) => moveTasksToDay(writer, changing, day, zone: zone),
  );
  return changing.length;
}
