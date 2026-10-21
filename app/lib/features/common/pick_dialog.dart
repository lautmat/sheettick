import 'package:flutter/material.dart';

/// A dialog that lists choices and pops with the chosen id. It pops '' for the "none" choice, and null when
/// cancelled.
class PickDialog extends StatelessWidget {
  const PickDialog({super.key, required this.title, required this.noneLabel, required this.options, this.current});

  final String title;
  final String noneLabel;
  final List<({String id, String name})> options;

  /// The id in use now, marked with a check. Null means the "none" choice is in use.
  final String? current;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(title),
      children: [
        SimpleDialogOption(
          key: const Key('pick-none'),
          onPressed: () => Navigator.pop(context, ''),
          child: _Choice(label: noneLabel, inUse: current == null),
        ),
        for (final o in options)
          SimpleDialogOption(
            key: Key('pick-${o.id}'),
            onPressed: () => Navigator.pop(context, o.id),
            child: _Choice(label: o.name.isEmpty ? '(untitled)' : o.name, inUse: o.id == current),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.inUse});

  final String label;
  final bool inUse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        if (inUse) const Icon(Icons.check, size: 18),
      ],
    );
  }
}
