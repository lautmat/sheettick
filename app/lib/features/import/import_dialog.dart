import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/import/ticktick_import.dart';
import '../../core/providers.dart';

/// The import tools only show in debug builds, or in a release built with `--dart-define=DEV_TOOLS=true`.
const bool kDevTools = kDebugMode || bool.fromEnvironment('DEV_TOOLS');

/// Dev-only: paste the TickTick JSON, read the dry run, then import. Nothing is written until "Import" is pressed, and
/// editing the text puts it back to the dry-run step.
Future<void> showTickTickImportDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const TickTickImportDialog());

class TickTickImportDialog extends ConsumerStatefulWidget {
  const TickTickImportDialog({super.key});

  @override
  ConsumerState<TickTickImportDialog> createState() => _TickTickImportDialogState();
}

class _TickTickImportDialogState extends ConsumerState<TickTickImportDialog> {
  final _text = TextEditingController();
  ImportPlan? _plan;
  String _report = '';
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<String?> _inboxId() async {
    final lists = await ref.read(localStoreProvider).rowsById('lists');
    return lists.values
        .map((r) => r.fields)
        .where((f) => f['is_inbox'] == true && f['deleted'] != true)
        .map((f) => f['id'] as String)
        .firstOrNull;
  }

  Future<void> _dryRun() async {
    setState(() => _busy = true);
    try {
      final inbox = await _inboxId();
      if (inbox == null) throw StateError('No Inbox yet: sign in and sync first.');
      final plan = planTickTickImport(_text.text, listId: inbox);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _report = plan.describe();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plan = null;
        _report = 'Cannot read this: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() => _busy = true);
    try {
      final writer = await ref.read(localWriterProvider.future);
      final r = await applyTickTickImport(writer, plan);
      if (!mounted) return;
      setState(() {
        _plan = null;
        _report = 'Done: ${r.written} written, ${r.skipped} already there. Sync to push them to the Sheet.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _report = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import from TickTick'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('importJson'),
              controller: _text,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'Paste the JSON here', border: OutlineInputBorder()),
              onChanged: (_) {
                if (_plan != null) setState(() => _plan = null);
              },
            ),
            const SizedBox(height: 12),
            Flexible(child: SingleChildScrollView(child: SelectableText(_report, key: const Key('importReport')))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        TextButton(key: const Key('importDryRun'), onPressed: _busy ? null : _dryRun, child: const Text('Dry run')),
        FilledButton(key: const Key('importGo'), onPressed: _busy || _plan == null ? null : _import, child: const Text('Import')),
      ],
    );
  }
}
