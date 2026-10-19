import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/time.dart';
import 'inbox_providers.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  void initState() {
    super.initState();
    // App start is a sync trigger.
    Future.microtask(() => ref.read(syncControllerProvider.notifier).sync());
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox'), actions: const [_SyncButton()]),
      body: Column(
        children: [
          const _SyncBanner(),
          Expanded(
            child: inbox.when(
              data: (list) => list == null ? const _NoInbox() : _InboxBody(list: list),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not read the local database: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncButton extends ConsumerWidget {
  const _SyncButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(syncControllerProvider).isSyncing;
    if (syncing) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      tooltip: 'Sync now',
      icon: const Icon(Icons.sync),
      onPressed: () => ref.read(syncControllerProvider.notifier).sync(),
    );
  }
}

/// One line under the app bar when sync needs attention.
class _SyncBanner extends ConsumerWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final (text, color) = switch (status.phase) {
      SyncPhase.needsSignIn => ('Not signed in to Google: changes stay on this device.', scheme.secondaryContainer),
      SyncPhase.error => ('Sync failed: ${status.message}', scheme.errorContainer),
      _ => (null, null),
    };
    if (text == null) return const SizedBox.shrink();
    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [Expanded(child: Text(text, key: const Key('syncBanner')))]),
      ),
    );
  }
}

/// Shown until the Inbox list has arrived from the Sheet (first sign-in on this device).
class _NoInbox extends ConsumerWidget {
  const _NoInbox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              status.isSyncing ? 'Setting up your spreadsheet...' : 'Sign in to Google to set up your Inbox.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: status.isSyncing ? null : () => ref.read(syncControllerProvider.notifier).sync(),
              icon: const Icon(Icons.sync),
              label: const Text('Sync now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxBody extends ConsumerWidget {
  const _InboxBody({required this.list});

  final TaskList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(listTasksProvider(list.id));
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(syncControllerProvider.notifier).sync(),
            child: tasks.when(
              data: (items) => items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: Text('Nothing here. Add your first task below.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _TaskTile(key: ValueKey(items[i].id), task: items[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not read tasks: $e')),
            ),
          ),
        ),
        _AddBar(listId: list.id),
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({super.key, required this.task});

  final Task task;

  bool get _done => task.status == 2;

  Future<void> _toggle(WidgetRef ref, bool done) async {
    final writer = await ref.read(localWriterProvider.future);
    await writer.update('tasks', task.id, {
      'status': done ? 2 : 0,
      'completed_at': done ? formatUtc(DateTime.now()) : null,
    });
    ref.read(syncControllerProvider.notifier).requestSoon();
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final title = await showDialog<String>(context: context, builder: (_) => _EditTitleDialog(initial: task.title));
    if (title == null || title.trim().isEmpty || title.trim() == task.title) return;
    final writer = await ref.read(localWriterProvider.future);
    await writer.update('tasks', task.id, {'title': title.trim()});
    ref.read(syncControllerProvider.notifier).requestSoon();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Checkbox(value: _done, onChanged: (v) => _toggle(ref, v ?? false)),
      title: Text(
        task.title.isEmpty ? '(untitled)' : task.title,
        style: _done ? TextStyle(decoration: TextDecoration.lineThrough, color: muted) : null,
      ),
      onTap: () => _rename(context, ref),
    );
  }
}

class _EditTitleDialog extends StatefulWidget {
  const _EditTitleDialog({required this.initial});

  final String initial;

  @override
  State<_EditTitleDialog> createState() => _EditTitleDialogState();
}

class _EditTitleDialogState extends State<_EditTitleDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit title'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Save')),
      ],
    );
  }
}

class _AddBar extends ConsumerStatefulWidget {
  const _AddBar({required this.listId});

  final String listId;

  @override
  ConsumerState<_AddBar> createState() => _AddBarState();
}

class _AddBarState extends ConsumerState<_AddBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    // Cleared first so a second tap or Enter cannot add the same task twice while the write is in flight; the
    // text is put back if the write fails, so nothing the user typed is lost.
    _controller.clear();
    try {
      final writer = await ref.read(localWriterProvider.future);
      await writer.insert('tasks', {'list_id': widget.listId, 'title': title});
    } catch (e) {
      if (!mounted) return;
      if (_controller.text.isEmpty) _controller.text = title;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the task: $e')));
      return;
    }
    ref.read(syncControllerProvider.notifier).requestSoon();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('addTaskField'),
                controller: _controller,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Add a task', border: InputBorder.none),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(key: const Key('addTaskButton'), tooltip: 'Add task', icon: const Icon(Icons.add), onPressed: _add),
          ],
        ),
      ),
    );
  }
}
