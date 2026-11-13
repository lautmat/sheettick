import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/recurrence.dart';
import '../../core/tasks/repeat_spec.dart';
import '../common/local_edit.dart';
import 'custom_repeat_dialog.dart';
import 'date_labels.dart';

/// A way to repeat that the picker offers.
class RepeatPreset {
  const RepeatPreset(this.label, this.rrule);

  final String label;

  /// The RFC 5545 rule written to the task.
  final String rrule;
}

const _weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// The presets for a task whose date is [anchor] (a wall-clock reading): weekly and monthly rules name that weekday and
/// day of the month.
List<RepeatPreset> repeatPresets(DateTime anchor) {
  final day = _weekdays[anchor.weekday - 1];
  final name = _weekdayNames[anchor.weekday - 1];
  return [
    const RepeatPreset('Every day', 'RRULE:FREQ=DAILY'),
    RepeatPreset('Every week on $name', 'RRULE:FREQ=WEEKLY;BYDAY=$day'),
    RepeatPreset('Every 2 weeks on $name', 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=$day'),
    const RepeatPreset('Every weekday', 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'),
    RepeatPreset('Every month on day ${anchor.day}', 'RRULE:FREQ=MONTHLY;BYMONTHDAY=${anchor.day}'),
    const RepeatPreset('Every year', 'RRULE:FREQ=YEARLY'),
  ];
}

String _plain(String rrule) => rrule.trim().replaceFirst(RegExp('^RRULE:', caseSensitive: false), '');

/// The words for [rrule]: a preset's label, else the rule put into words, else the rule itself without its `RRULE:`
/// label.
String repeatLabel(String? rrule, List<RepeatPreset> presets) {
  if (rrule == null || rrule.trim().isEmpty) return 'Repeat';
  for (final p in presets) {
    if (_plain(p.rrule).toUpperCase() == _plain(rrule).toUpperCase()) return p.label;
  }
  return describeRepeat(rrule) ?? _plain(rrule);
}

/// The chip on a task's page that shows how it repeats and opens [showRepeatDialog]. A change is written at once. A task
/// with no start or due has nothing to repeat from, so the chip waits for a date.
class TaskRepeatChip extends ConsumerWidget {
  const TaskRepeatChip({super.key, required this.task});

  final Task task;

  Future<void> _edit(BuildContext context, WidgetRef ref, DateTime anchor) async {
    final presets = repeatPresets(anchor);
    final current = (rrule: task.rrule, from: RepeatFrom.parse(task.repeatFrom));
    final chosen = await showRepeatDialog(context, presets: presets, current: current, anchor: anchor);
    if (chosen == null) return;
    if (_plain(chosen.rrule ?? '') == _plain(current.rrule ?? '') && chosen.from == current.from) return;
    // The page may have gone while the dialog was open; a disposed widget's ref must not be used.
    if (!context.mounted) return;
    await updateRow(ref, 'tasks', task.id, {
      'rrule': chosen.rrule,
      'repeat_from': chosen.from.value,
    }, undo: 'Repeat changed');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(deviceZoneProvider).value;
    final dates = task.dates(zone);
    final anchor = dates.due ?? dates.start;
    final repeating = (task.rrule ?? '').trim().isNotEmpty;
    final presets = repeatPresets(anchor ?? DateTime.utc(2000));
    return ActionChip(
      key: const Key('taskRepeat'),
      avatar: Icon(repeating ? Icons.repeat_on : Icons.repeat, size: 18),
      label: Text(repeatLabel(task.rrule, presets)),
      tooltip: anchor == null ? 'Set a start or due date first' : 'Repeat',
      onPressed: anchor == null ? null : () => _edit(context, ref, anchor),
    );
  }
}

/// Asks how a task repeats. Returns the rule (null for "does not repeat") and what it counts from, or null when the user
/// cancels. A rule the task already has that the picker does not offer (from the Sheet) is listed too, in words, and kept
/// as it is unless the user picks something else. [anchor] is the task's date, for the Custom editor.
Future<({String? rrule, RepeatFrom from})?> showRepeatDialog(
  BuildContext context, {
  required List<RepeatPreset> presets,
  required ({String? rrule, RepeatFrom from}) current,
  required DateTime anchor,
}) {
  return showDialog<({String? rrule, RepeatFrom from})>(
    context: context,
    builder: (_) => _RepeatDialog(presets: presets, current: current, anchor: anchor),
  );
}

class _RepeatDialog extends StatefulWidget {
  const _RepeatDialog({required this.presets, required this.current, required this.anchor});

  final List<RepeatPreset> presets;
  final ({String? rrule, RepeatFrom from}) current;
  final DateTime anchor;

  @override
  State<_RepeatDialog> createState() => _RepeatDialogState();
}

class _RepeatDialogState extends State<_RepeatDialog> {
  late String? _rrule = (widget.current.rrule ?? '').trim().isEmpty ? null : widget.current.rrule!.trim();
  late RepeatFrom _from = widget.current.from;

  /// Rules listed after the presets: the one the task already has, and any made with Custom in this dialog.
  late final List<String> _extras = [
    if ((widget.current.rrule ?? '').trim().isNotEmpty && !_isPreset(widget.current.rrule!)) widget.current.rrule!.trim(),
  ];

  bool _isPreset(String rrule) => widget.presets.any((p) => _plain(p.rrule).toUpperCase() == _plain(rrule).toUpperCase());

  Future<void> _custom() async {
    final spec = RepeatSpec.parse(_rrule);
    final rule = await showCustomRepeatDialog(context, initial: spec, anchor: widget.anchor);
    if (rule == null || !mounted) return;
    setState(() {
      _rrule = rule;
      if (!_isPreset(rule) && !_extras.any((e) => _plain(e).toUpperCase() == _plain(rule).toUpperCase())) _extras.add(rule);
    });
  }

  bool _selected(String? rrule) =>
      rrule == null ? _rrule == null : _rrule != null && _plain(_rrule!).toUpperCase() == _plain(rrule).toUpperCase();

  Widget _option(Key key, String label, String? rrule) {
    final selected = _selected(rrule);
    return ListTile(
      key: key,
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
      title: Text(label),
      onTap: () => setState(() => _rrule = rrule),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Repeat'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _option(const Key('repeat:none'), 'Does not repeat', null),
              for (final o in widget.presets) _option(Key('repeat:${_plain(o.rrule)}'), o.label, o.rrule),
              for (final e in _extras) _option(Key('repeat:${_plain(e)}'), repeatLabel(e, const []), e),
              ListTile(
                key: const Key('repeat:custom'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune),
                title: const Text('Custom…'),
                onTap: _custom,
              ),
              if (_rrule != null) ...[
                const SizedBox(height: 12),
                Text('Repeat from', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                SegmentedButton<RepeatFrom>(
                  key: const Key('repeatFrom'),
                  segments: const [
                    ButtonSegment(value: RepeatFrom.due, label: Text('Due date'), icon: Icon(Icons.event)),
                    ButtonSegment(value: RepeatFrom.completion, label: Text('Completion'), icon: Icon(Icons.check)),
                  ],
                  selected: {_from},
                  onSelectionChanged: (s) => setState(() => _from = s.single),
                ),
                const SizedBox(height: 8),
                Text(
                  _from == RepeatFrom.due
                      ? 'The next one follows the schedule, even if you finish late.'
                      : 'The next one counts from the day you finish this one.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(key: const Key('repeatCancel'), onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('repeatDone'),
          onPressed: () => Navigator.pop(context, (rrule: _rrule, from: _from)),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
