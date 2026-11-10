import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/task_dates.dart';
import '../../core/tasks/task_status.dart';
import '../common/local_edit.dart';
import 'date_labels.dart';

/// The hour a date gets when it first gets a time.
const _defaultHour = 9;

final _firstDate = DateTime(2000);
final _lastDate = DateTime(2100);

/// The chip on a task's page that shows its start and due and opens [showTaskDatesDialog]. A change is written at once.
class TaskDatesChip extends ConsumerWidget {
  const TaskDatesChip({super.key, required this.task});

  final Task task;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final zone = await ref.read(deviceZoneProvider.future);
    if (!context.mounted) return;
    final current = task.dates(zone);
    final result = await showTaskDatesDialog(context, initial: current, zone: zone);
    if (result == null || (result.isEmpty && current.isEmpty)) return;
    await updateRow(ref, 'tasks', task.id, result.toFields());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(deviceZoneProvider).value;
    final now = DateTime.now();
    final dates = task.dates(zone);
    final open = task.status == TaskStatus.open.value;
    final overdue = open && (dates.headline(now)?.overdue ?? false);
    return ActionChip(
      key: const Key('taskDates'),
      avatar: Icon(
        Icons.event_outlined,
        size: 18,
        color: overdue ? Theme.of(context).colorScheme.error : null,
      ),
      label: Text(
        datesSummary(context, dates, now),
        style: overdue ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
      ),
      onPressed: () => _edit(context, ref),
    );
  }
}

/// Asks for a task's start, due, and whether they are all-day dates. Null when the user cancels or changes nothing;
/// [TaskDates.isEmpty] when they clear the dates. [zone] is the device's IANA zone, which timed values are set in.
Future<TaskDates?> showTaskDatesDialog(BuildContext context, {required TaskDates initial, required String? zone}) {
  return showDialog<TaskDates>(
    context: context,
    builder: (_) => _TaskDatesDialog(initial: initial, zone: zone),
  );
}

class _TaskDatesDialog extends StatefulWidget {
  const _TaskDatesDialog({required this.initial, required this.zone});

  final TaskDates initial;
  final String? zone;

  @override
  State<_TaskDatesDialog> createState() => _TaskDatesDialogState();
}

class _TaskDatesDialogState extends State<_TaskDatesDialog> {
  /// The dates as the dialog opened, on the device's zone. A new task starts as all-day dates.
  late final TaskDates _baseline = TaskDates(
    start: widget.initial.start,
    due: widget.initial.due,
    allDay: widget.initial.isEmpty ? true : widget.initial.allDay,
    zone: widget.zone,
  );
  late TaskDates _dates = _baseline;

  /// [seed] kept inside the range the picker accepts, as a local date for it.
  DateTime _pickerDate(DateTime seed) {
    final day = DateTime(seed.year, seed.month, seed.day);
    if (day.isBefore(_firstDate)) return _firstDate;
    if (day.isAfter(_lastDate)) return _lastDate;
    return day;
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _dates.start : _dates.due;
    final other = start ? _dates.due : _dates.start;
    final seed = current ?? other ?? _dates.wallOf(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickerDate(seed),
      firstDate: _firstDate,
      lastDate: _lastDate,
      helpText: start ? 'Start date' : 'Due date',
    );
    if (picked == null || !mounted) return;
    final hour = _dates.allDay ? 0 : (current?.hour ?? _defaultHour);
    final minute = _dates.allDay ? 0 : (current?.minute ?? 0);
    final wall = DateTime.utc(picked.year, picked.month, picked.day, hour, minute);
    setState(() => _dates = start ? _dates.withStart(wall) : _dates.withDue(wall));
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _dates.start : _dates.due;
    if (current == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: start ? 'Start time' : 'Due time',
    );
    if (picked == null || !mounted) return;
    final wall = DateTime.utc(current.year, current.month, current.day, picked.hour, picked.minute);
    setState(() => _dates = start ? _dates.withStart(wall) : _dates.withDue(wall));
  }

  void _clearOne({required bool start}) {
    setState(() => _dates = start ? _dates.withStart(null) : _dates.withDue(null));
  }

  void _done() => Navigator.pop(context, _dates == _baseline ? null : _dates);

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    return AlertDialog(
      title: const Text('Dates'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('allDaySwitch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              value: _dates.allDay,
              onChanged: (on) => setState(() => _dates = _dates.withAllDay(on, defaultHour: _defaultHour)),
            ),
            _DateRow(
              label: 'Start',
              keyPrefix: 'start',
              wall: _dates.start,
              timed: !_dates.allDay,
              dateText: (w) => l10n.formatMediumDate(w),
              timeText: (w) => timeText(context, w),
              onPickDate: () => _pickDate(start: true),
              onPickTime: () => _pickTime(start: true),
              onClear: () => _clearOne(start: true),
            ),
            _DateRow(
              label: 'Due',
              keyPrefix: 'due',
              wall: _dates.due,
              timed: !_dates.allDay,
              dateText: (w) => l10n.formatMediumDate(w),
              timeText: (w) => timeText(context, w),
              onPickDate: () => _pickDate(start: false),
              onPickTime: () => _pickTime(start: false),
              onClear: () => _clearOne(start: false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('datesClear'),
          onPressed: () => Navigator.pop(context, const TaskDates()),
          child: const Text('Clear'),
        ),
        TextButton(
          key: const Key('datesCancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(key: const Key('datesDone'), onPressed: _done, child: const Text('Done')),
      ],
    );
  }
}

/// One line of the dialog: a label, then the date and time buttons, or "Set date" while there is none.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.keyPrefix,
    required this.wall,
    required this.timed,
    required this.dateText,
    required this.timeText,
    required this.onPickDate,
    required this.onPickTime,
    required this.onClear,
  });

  final String label;
  final String keyPrefix;
  final DateTime? wall;
  final bool timed;
  final String Function(DateTime) dateText;
  final String Function(DateTime) timeText;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final w = wall;
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label)),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                key: Key('${keyPrefix}DateButton'),
                onPressed: onPickDate,
                child: Text(w == null ? 'Set date' : dateText(w)),
              ),
              if (w != null && timed)
                TextButton(key: Key('${keyPrefix}TimeButton'), onPressed: onPickTime, child: Text(timeText(w))),
            ],
          ),
        ),
        if (w != null)
          IconButton(
            key: Key('${keyPrefix}Clear'),
            tooltip: 'Remove $label',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClear,
          ),
      ],
    );
  }
}
