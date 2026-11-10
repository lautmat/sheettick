import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/reminders/reminder_planner.dart';
import '../../core/reminders/snooze.dart';
import '../../core/tasks/task_dates.dart';
import 'reminders_providers.dart';

/// "Snooze" on a task's page: moves the task's reminder to a later time on this device, without touching the task's
/// dates. It shows only for an open task that has a reminder.
class TaskSnoozeChip extends ConsumerWidget {
  const TaskSnoozeChip({super.key, required this.task});

  final Task task;

  Future<void> _snooze(BuildContext context, WidgetRef ref, PlannedReminder target, String? zone) async {
    final now = DateTime.now();
    final until = await showSnoozeDialog(context, now: now, zone: zone);
    if (until == null) return;
    // The page may have gone while the dialog was open; a disposed widget's ref must not be used.
    if (!context.mounted) return;
    if (!until.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a time in the future.')));
      return;
    }
    await snoozeStoreOf(ref.read(appDatabaseProvider)).snooze(target.key, from: target.originalAt, until: until, now: now);
    ref.read(planRevisionProvider.notifier).bump();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Snoozed until ${_untilText(context, until, now)}.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(deviceZoneProvider).value;
    final target = snoozeTarget(task, now: DateTime.now(), deviceZone: zone);
    if (target == null) return const SizedBox.shrink();
    return ActionChip(
      key: const Key('taskSnooze'),
      avatar: const Icon(Icons.snooze, size: 18),
      label: const Text('Snooze'),
      tooltip: 'Remind me again later',
      onPressed: () => _snooze(context, ref, target, zone),
    );
  }
}

String _untilText(BuildContext context, DateTime until, DateTime now) {
  final l10n = MaterialLocalizations.of(context);
  final local = until.toLocal();
  final time = l10n.formatTimeOfDay(TimeOfDay(hour: local.hour, minute: local.minute));
  final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
  return sameDay ? time : '${l10n.formatShortMonthDay(local)}, $time';
}

/// Asks when to remind again. Returns that instant, or null when the user cancels. [zone] is the device's IANA zone.
Future<DateTime?> showSnoozeDialog(BuildContext context, {required DateTime now, required String? zone}) {
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      void choose(DateTime until) => Navigator.pop(dialogContext, until);
      return SimpleDialog(
        title: const Text('Snooze until'),
        children: [
          for (final a in SnoozeAction.values)
            SimpleDialogOption(
              key: Key(a.id),
              onPressed: () => choose(now.add(a.length)),
              child: Text(a.label == '1 hour' ? 'In 1 hour' : 'In ${a.label}'),
            ),
          SimpleDialogOption(
            key: const Key('snooze:tomorrow'),
            onPressed: () => choose(_tomorrowAtNine(now, zone)),
            child: const Text('Tomorrow, 9:00'),
          ),
          SimpleDialogOption(
            key: const Key('snooze:pick'),
            onPressed: () async {
              final picked = await _pickTime(dialogContext, now, zone);
              if (picked != null && dialogContext.mounted) choose(picked);
            },
            child: const Text('Pick a date and time…'),
          ),
        ],
      );
    },
  );
}

DateTime _tomorrowAtNine(DateTime now, String? zone) {
  final today = TaskDates(zone: zone).wallOf(now);
  return wallToInstant(DateTime.utc(today.year, today.month, today.day + 1, 9), locationOf(zone));
}

Future<DateTime?> _pickTime(BuildContext context, DateTime now, String? zone) async {
  final today = TaskDates(zone: zone).wallOf(now);
  final day = await showDatePicker(
    context: context,
    initialDate: DateTime(today.year, today.month, today.day),
    firstDate: DateTime(today.year, today.month, today.day),
    lastDate: DateTime(today.year + 2),
    helpText: 'Snooze until',
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: today.hour, minute: today.minute));
  if (time == null) return null;
  return wallToInstant(DateTime.utc(day.year, day.month, day.day, time.hour, time.minute), locationOf(zone));
}
