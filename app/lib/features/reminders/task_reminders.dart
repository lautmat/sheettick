import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          content: Text('Reminder saved. Notifications are off, so it will not show until you turn them on in your device settings.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(deviceZoneProvider).value;
    final dates = task.dates(zone);
    final triggers = parseReminders(task.reminders);
    final label = switch (triggers.length) {
      0 => 'Add reminder',
      1 => describeReminder(triggers.single, allDay: dates.allDay),
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

/// Asks which of the reminders to keep. Returns the chosen triggers, or null when the user cancels. A reminder the task
/// already has that the picker does not offer (custom, or from the Sheet) is listed too, so it can be removed, and
/// "Custom" adds any other.
Future<List<ReminderTrigger>?> showRemindersDialog(
  BuildContext context, {
  required List<ReminderTrigger> selected,
  required bool allDay,
}) {
  final presets = allDay ? allDayReminderPresets : timedReminderPresets;
  final extra = [
    for (final t in selected)
      if (!presets.any((p) => p.trigger == t)) ReminderPreset(describeReminder(t, allDay: allDay), t),
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
  late final List<ReminderPreset> _options = [...widget.options];
  late final Set<ReminderTrigger> _chosen = {...widget.selected};

  Future<void> _addCustom() async {
    final trigger = await showDialog<ReminderTrigger>(
      context: context,
      builder: (_) => _CustomReminderDialog(allDay: widget.allDay),
    );
    if (trigger == null || !mounted) return;
    setState(() {
      if (!_options.any((o) => o.trigger == trigger)) {
        _options.add(ReminderPreset(describeReminder(trigger, allDay: widget.allDay), trigger));
      }
      _chosen.add(trigger);
    });
  }

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
              for (final option in _options)
                CheckboxListTile(
                  key: Key('reminder:${option.trigger.format()}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(option.label),
                  value: _chosen.contains(option.trigger),
                  onChanged: (on) => setState(() => on == true ? _chosen.add(option.trigger) : _chosen.remove(option.trigger)),
                ),
              ListTile(
                key: const Key('reminderCustom'),
                contentPadding: EdgeInsets.zero,
                leading: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.add)),
                title: const Text('Custom…'),
                onTap: _addCustom,
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

/// Asks for one reminder the presets do not offer. On an all-day task: how many days before, and at what time. On a task
/// with a time: how long before it. Returns the trigger, or null when the user cancels.
class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog({required this.allDay});

  final bool allDay;

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  late final _amount = TextEditingController(text: widget.allDay ? '0' : '10');
  var _unit = ReminderUnit.minutes;
  var _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// What the fields say, or null while the number is missing or out of range.
  ReminderTrigger? get _trigger {
    final n = int.tryParse(_amount.text.trim());
    if (n == null) return null;
    if (widget.allDay) {
      if (n > 365) return null;
      return allDayReminderAt(daysBefore: n, hour: _time.hour, minute: _time.minute);
    }
    if (n < 1) return null;
    return timedReminderBefore(n, _unit);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time, helpText: 'Reminder time');
    if (picked != null && mounted) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final trigger = _trigger;
    final clock = '${_time.hour}:${_time.minute.toString().padLeft(2, '0')}';
    return AlertDialog(
      title: const Text('Custom reminder'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('reminderCustomAmount'),
                    controller: _amount,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    decoration: InputDecoration(
                      labelText: widget.allDay ? 'Days before' : 'How long before',
                      helperText: widget.allDay ? '0 is the day itself' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.allDay)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      key: const Key('reminderCustomTime'),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(clock),
                      onPressed: _pickTime,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: DropdownButton<ReminderUnit>(
                      key: const Key('reminderCustomUnit'),
                      value: _unit,
                      items: [for (final u in ReminderUnit.values) DropdownMenuItem(value: u, child: Text(u.label))],
                      onChanged: (u) => setState(() => _unit = u ?? _unit),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              trigger == null
                  ? (widget.allDay ? 'Enter 0 to 365 days.' : 'Enter a number from 1 to 999.')
                  : describeReminder(trigger, allDay: widget.allDay),
              key: const Key('reminderCustomPreview'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('reminderCustomAdd'),
          onPressed: trigger == null ? null : () => Navigator.pop(context, trigger),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
