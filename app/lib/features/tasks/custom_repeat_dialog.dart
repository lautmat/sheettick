import 'package:flutter/material.dart';

import '../../core/tasks/repeat_spec.dart';

const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// The custom repeat editor: frequency, interval, weekdays or day of the month, and an end. Returns the RFC 5545 rule, or
/// null when cancelled. [initial] is the rule being edited (null starts a new one); [anchor] is the task's date, which
/// fills in the weekday or day of the month the user has not picked.
Future<String?> showCustomRepeatDialog(BuildContext context, {RepeatSpec? initial, required DateTime anchor}) {
  return showDialog<String>(
    context: context,
    builder: (_) => CustomRepeatDialog(initial: initial ?? RepeatSpec.starting(RepeatUnit.week, anchor), anchor: anchor),
  );
}

class CustomRepeatDialog extends StatefulWidget {
  const CustomRepeatDialog({super.key, required this.initial, required this.anchor});

  final RepeatSpec initial;
  final DateTime anchor;

  @override
  State<CustomRepeatDialog> createState() => _CustomRepeatDialogState();
}

class _CustomRepeatDialogState extends State<CustomRepeatDialog> {
  late RepeatSpec _spec = widget.initial;

  Set<int> get _weekdays => _spec.weekdays.isEmpty ? {widget.anchor.weekday} : _spec.weekdays;

  Widget _stepper(String key, int value, ValueChanged<int> onChanged, {int min = 1, int max = 99}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('$key:down'),
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(width: 32, child: Text('$value', key: Key('$key:value'), textAlign: TextAlign.center)),
        IconButton(
          key: Key('$key:up'),
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  Widget _endTile(Key key, bool selected, Widget title, VoidCallback onTap, {Widget? trailing}) {
    return ListTile(
      key: key,
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
      title: title,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Future<void> _pickUntil() async {
    final anchorDay = DateTime(widget.anchor.year, widget.anchor.month, widget.anchor.day);
    final current = _spec.end;
    final initial = current is RepeatUntil
        ? DateTime(current.day.year, current.day.month, current.day.day)
        : DateTime(anchorDay.year + 1, anchorDay.month, anchorDay.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(anchorDay) ? anchorDay : initial,
      firstDate: anchorDay,
      lastDate: DateTime(anchorDay.year + 50),
    );
    if (picked == null || !mounted) return;
    setState(() => _spec = _spec.copyWith(end: RepeatUntil(picked)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = _spec.end;
    return AlertDialog(
      title: const Text('Custom repeat'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Every'),
                  _stepper('customInterval', _spec.interval, (v) => setState(() => _spec = _spec.copyWith(interval: v))),
                ],
              ),
              SegmentedButton<RepeatUnit>(
                key: const Key('customUnit'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: RepeatUnit.day, label: Text('Day')),
                  ButtonSegment(value: RepeatUnit.week, label: Text('Week')),
                  ButtonSegment(value: RepeatUnit.month, label: Text('Month')),
                  ButtonSegment(value: RepeatUnit.year, label: Text('Year')),
                ],
                selected: {_spec.unit},
                onSelectionChanged: (s) => setState(() => _spec = _spec.copyWith(unit: s.single)),
              ),
              if (_spec.unit == RepeatUnit.week) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        key: Key('customWeekday$d'),
                        label: Text(_initials[d - 1]),
                        tooltip: _weekdayNames[d - 1],
                        showCheckmark: false,
                        selected: _weekdays.contains(d),
                        onSelected: (on) {
                          final next = {..._weekdays};
                          on ? next.add(d) : next.remove(d);
                          // A weekly rule needs a day: the last one cannot be switched off.
                          if (next.isNotEmpty) setState(() => _spec = _spec.copyWith(weekdays: next));
                        },
                      ),
                  ],
                ),
              ],
              if (_spec.unit == RepeatUnit.month) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('On'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      key: const Key('customMonthDay'),
                      value: _spec.monthDay ?? widget.anchor.day,
                      items: [
                        for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('day $d')),
                        const DropdownMenuItem(value: -1, child: Text('the last day')),
                      ],
                      onChanged: (v) => setState(() => _spec = _spec.copyWith(monthDay: v)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text('Ends', style: theme.textTheme.labelLarge),
              _endTile(const Key('customEndNever'), end is RepeatNever, const Text('Never'),
                  () => setState(() => _spec = _spec.copyWith(end: const RepeatNever()))),
              _endTile(
                const Key('customEndUntil'),
                end is RepeatUntil,
                Text(end is RepeatUntil ? 'On ${_date(end.day)}' : 'On a date'),
                _pickUntil,
                trailing: const Icon(Icons.edit_calendar_outlined),
              ),
              _endTile(
                const Key('customEndCount'),
                end is RepeatCount,
                Text(end is RepeatCount ? 'After ${end.times} ${end.times == 1 ? 'time' : 'times'}' : 'After a number of times'),
                () {
                  if (end is! RepeatCount) setState(() => _spec = _spec.copyWith(end: const RepeatCount(10)));
                },
                trailing: end is RepeatCount
                    ? _stepper('customCount', end.times, (v) => setState(() => _spec = _spec.copyWith(end: RepeatCount(v))), max: 999)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(_spec.describe(widget.anchor), key: const Key('customPreview'), style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(key: const Key('customCancel'), onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('customDone'),
          onPressed: () => Navigator.pop(context, _spec.format(widget.anchor)),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
