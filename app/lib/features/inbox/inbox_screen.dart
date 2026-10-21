import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/time.dart';
import '../common/name_dialog.dart';
import '../lists/lists_providers.dart';
import '../lists/lists_sidebar.dart';
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
    final active = ref.watch(activeListProvider);
    final wide = MediaQuery.sizeOf(context).width >= kSidebarBreakpoint;
    final screen = Scaffold(
      appBar: AppBar(title: Text(_titleOf(active.value)), actions: const [_SyncButton(), _AccountMenu()]),
      drawer: wide ? null : const Drawer(child: SafeArea(child: ListsSidebar())),
      body: Column(
        children: [
          const _SyncBanner(),
          Expanded(
            child: active.when(
              data: (list) => list == null ? const _NoInbox() : _InboxBody(list: list),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not read the local database: $e')),
            ),
          ),
        ],
      ),
    );
    if (!wide) return screen;
    return Row(
      children: [
        SizedBox(
          width: kSidebarWidth,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: const SafeArea(right: false, child: ListsSidebar()),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: screen),
      ],
    );
  }

  String _titleOf(TaskList? list) {
    if (list == null) return 'Inbox';
    if (list.name.isNotEmpty) return list.name;
    return list.isInbox ? 'Inbox' : '(untitled)';
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

/// Who is signed in, and Sign out. Hidden while signed out.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider.select((s) => s.session));
    if (session == null) return const SizedBox.shrink();
    return PopupMenuButton<void>(
      key: const Key('accountMenu'),
      tooltip: 'Account',
      icon: const Icon(Icons.account_circle_outlined),
      itemBuilder: (_) => [
        if (session.email != null) PopupMenuItem<void>(enabled: false, child: Text(session.email!)),
        PopupMenuItem<void>(
          key: const Key('signOut'),
          onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// One line under the app bar when sign-in or sync needs attention.
class _SyncBanner extends ConsumerWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    String? text;
    Color? color;
    var offerSignIn = false;
    if (!auth.signedIn && !auth.restoring) {
      text = auth.error ?? 'Not signed in to Google: changes stay on this device.';
      color = auth.error == null ? scheme.secondaryContainer : scheme.errorContainer;
      offerSignIn = true;
    } else if (status.phase == SyncPhase.offline) {
      text = 'Offline: your changes are saved on this device and will sync when you are back online.';
      color = scheme.surfaceContainerHighest;
    } else if (status.phase == SyncPhase.error) {
      text = 'Sync failed: ${status.message}';
      color = scheme.errorContainer;
    }
    if (text == null) return const SizedBox.shrink();
    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(text, key: const Key('syncBanner'))),
            if (offerSignIn)
              TextButton(
                key: const Key('bannerSignIn'),
                onPressed: auth.busy ? null : () => ref.read(authControllerProvider.notifier).signIn(),
                child: const Text('Sign in'),
              ),
          ],
        ),
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
    final auth = ref.watch(authControllerProvider);
    final signedOut = !auth.signedIn;
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
            if (signedOut)
              FilledButton.icon(
                key: const Key('signInButton'),
                onPressed: auth.busy || auth.restoring
                    ? null
                    : () => ref.read(authControllerProvider.notifier).signIn(),
                icon: const Icon(Icons.login),
                label: Text(auth.busy ? 'Waiting for Google...' : 'Sign in with Google'),
              )
            else
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
    final title = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(title: 'Edit title', initial: task.title),
    );
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
            IconButton(
              key: const Key('addTaskButton'),
              tooltip: 'Add task',
              icon: const Icon(Icons.add),
              onPressed: _add,
            ),
          ],
        ),
      ),
    );
  }
}
