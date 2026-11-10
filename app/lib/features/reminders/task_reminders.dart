import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/reminders/reminder_trigger.dart';
import '../common/local_edit.dart';
import '../tasks/date_labels.dart';

/// The chip on a task's page that shows its reminders and opens [showRemindersDialog]. A change is written at once.
/// A task with no start or due has nothing to be relative to, so the chip waits for a date.
class TaskRemindersChip extends ConsumerWidget {
  const TaskRemindersChip({super.key, required this.task});

  final Task task;

  Future<void> _edit(BuildContext context, WidgetRef ref, {required bool allDay}) async {
    final before = parseReminders(task.reminders);
    final chosen = await showRemindersDialog(context, selected: before, allDay: allDay);
    if (chosen == null) return;
    final was = before.toSet(), now = chosen.toSet();
    if (now.length == was.length && now.containsAll(was)) return;
    // The page may have gone while the dialog was open; a disposed widget's ref must not be used.
    if (!context.mounted) return;
    await updateRow(ref, 'tasks', task.id, {'reminders': encodeReminders(now)});
    final added = now.difference(was).isNotEmpty;
    if (!added || !context.mounted) return;
    final allowed = await ref.read(reminderSchedulerProvider).requestPermission();
    if (!allowed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder saved. Notifications are off for SheetTick, so it will not show until you allow them.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(deviceZoneProvider).value;
    final dates = task.dates(zone);
    final triggers = parseReminders(task.reminders);
    final presets = dates.allDay ? allDayReminderPresets : timedReminderPresets;
    final label = switch (triggers.length) {
      0 => 'Add reminder',
      1 => _labelOf(triggers.single, presets),
      final n => '$n reminders',
    };
    return ActionChip(
      key: const Key('taskReminders'),
      avatar: Icon(triggers.isEmpty ? Icons.notifications_none : Icons.notifications_active_outlined, size: 18),
      label: Text(label),
      tooltip: dates.isEmpty ? 'Set a start or due date first' : 'Reminders',
      onPressed: dates.isEmpty ? null : () => _edit(context, ref, allDay: dates.allDay),
    );
  }
}

String _labelOf(ReminderTrigger trigger, List<ReminderPreset> presets) {
  for (final p in presets) {
    if (p.trigger == trigger) return p.label;
  }
  return trigger.format().replaceFirst('TRIGGER:', '');
}

/// Asks which of the reminders to keep. Returns the chosen triggers, or null when the user cancels. A reminder the task
/// already has that the picker does not offer (from the Sheet) is listed too, so it can be removed.
Future<List<ReminderTrigger>?> showRemindersDialog(
  BuildContext context, {
  required List<ReminderTrigger> selected,
  required bool allDay,
}) {
  final presets = allDay ? allDayReminderPresets : timedReminderPresets;
  final extra = [
    for (final t in selected)
      if (!presets.any((p) => p.trigger == t)) ReminderPreset(_labelOf(t, presets), t),
  ];
  return showDialog<List<ReminderTrigger>>(
    context: context,
    builder: (_) => _RemindersDialog(options: [...presets, ...extra], selected: selected.toSet(), allDay: allDay),
  );
}

class _RemindersDialog extends StatefulWidget {
  const _RemindersDialog({required this.options, required this.selected, required this.allDay});

  final List<ReminderPreset> options;
  final Set<ReminderTrigger> selected;
  final bool allDay;

  @override
  State<_RemindersDialog> createState() => _RemindersDialogState();
}

class _RemindersDialogState extends State<_RemindersDialog> {
  late final Set<ReminderTrigger> _chosen = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reminders'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final option in widget.options)
                CheckboxListTile(
                  key: Key('reminder:${option.trigger.format()}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(option.label),
                  value: _chosen.contains(option.trigger),
                  onChanged: (on) => setState(() => on == true ? _chosen.add(option.trigger) : _chosen.remove(option.trigger)),
                ),
              const SizedBox(height: 8),
              Text(
                'Counted from the start, or from the due date when there is no start.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(key: const Key('remindersCancel'), onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('remindersDone'),
          onPressed: () => Navigator.pop(context, _chosen.toList()),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
