import 'package:flutter/material.dart';

import '../../core/tasks/tags.dart';

/// Asks which tag to add to [count] tasks: a field for a name, and the tags that exist as chips to tap. Returns the
/// name as typed or tapped, or null when the dialog is dismissed.
Future<String?> askTagName(BuildContext context, {required int count, required List<String> known}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TagNameDialog(count: count, known: known),
    );

class _TagNameDialog extends StatefulWidget {
  const _TagNameDialog({required this.count, required this.known});

  final int count;
  final List<String> known;

  @override
  State<_TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<_TagNameDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _done(String text) {
    if (cleanTagName(text) != null) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.count == 1 ? 'Add a tag' : 'Add a tag to ${widget.count} tasks'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('bulkTagField'),
              controller: _field,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Tag name'),
              onChanged: (_) => setState(() {}),
              onSubmitted: _done,
            ),
            if (widget.known.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final name in widget.known)
                    ActionChip(
                      key: Key('bulkTagOption-$name'),
                      label: Text('#$name'),
                      onPressed: () => Navigator.pop(context, name),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('confirmBulkTag'),
          onPressed: cleanTagName(_field.text) == null ? null : () => _done(_field.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
