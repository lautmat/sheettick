import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/tasks/priority.dart';
import '../../core/tasks/tags.dart';
import '../../core/tasks/task_status.dart';
import '../../core/tasks/task_tree.dart';
import '../common/local_edit.dart';
import '../lists/lists_providers.dart';
import '../lists/lists_sidebar.dart';
import '../sections/sections_providers.dart';
import '../sections/sections_widgets.dart';
import '../tasks/date_labels.dart';
import '../tasks/task_attributes.dart';
import '../tasks/task_detail_screen.dart';
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
      appBar: AppBar(
        title: Text(_titleOf(active.value)),
        actions: [
          if (active.value case final list?) NewSectionButton(listId: list.id),
          const _SyncButton(),
          const _AccountMenu(),
        ],
      ),
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
    final sections = ref.watch(sectionsProvider(list.id)).value ?? const <Section>[];
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(syncControllerProvider.notifier).sync(),
            child: tasks.when(
              data: (items) => items.isEmpty && sections.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: Text('Nothing here. Add your first task below.')),
                        ),
                      ],
                    )
                  : ListView(physics: const AlwaysScrollableScrollPhysics(), children: _rows(items, sections)),
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

/// The rows of a list: the tasks outside any section first, then each section's heading and, unless it is
/// folded, its tasks. A subtask is shown under its top-level task, in that task's section.
List<Widget> _rows(List<Task> items, List<Section> sections) {
  final known = {for (final s in sections) s.id};
  // Each block is a top-level task followed by the subtasks under it.
  final blocks = <List<({Task item, int depth})>>[];
  for (final row in arrangeTree(items, idOf: (t) => t.id, parentOf: (t) => t.parentId)) {
    if (row.depth == 0) {
      blocks.add([row]);
    } else {
      blocks.last.add(row);
    }
  }
  bool inSection(List<({Task item, int depth})> block, String id) => block.first.item.sectionId == id;

  final shown = <Object>[
    for (final b in blocks)
      if (!known.contains(b.first.item.sectionId)) ...b,
  ];
  for (final s in sections) {
    shown.add(s);
    if (!s.collapsed) {
      for (final b in blocks.where((b) => inSection(b, s.id))) {
        shown.addAll(b);
      }
    }
  }

  final widgets = <Widget>[];
  // The task shown just above the next row: indenting a task puts it under that one. A heading breaks the chain.
  String? above;
  // The section the rows are shown in, null above the first heading.
  String? section;
  for (final entry in shown) {
    if (entry is Section) {
      above = null;
      section = entry.id;
      final count = blocks.where((b) => inSection(b, entry.id)).fold(0, (n, b) => n + b.length);
      widgets.add(SectionHeader(section: entry, count: count));
    } else {
      final row = entry as ({Task item, int depth});
      widgets.add(
        _TaskTile(key: ValueKey(row.item.id), task: row.item, depth: row.depth, above: above, section: section),
      );
      above = row.item.id;
    }
  }
  return widgets;
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({super.key, required this.task, this.depth = 0, this.above, this.section});

  final Task task;

  /// How many levels the task is nested under a top-level task.
  final int depth;

  /// The id of the task shown directly above this one, or null when a heading or the list's start is above it.
  final String? above;

  /// The section the task is shown in, null when it is shown outside any section. A subtask is shown in its
  /// top-level task's section, whatever its own `section_id` says.
  final String? section;

  bool get _done => task.status == TaskStatus.completed.value;

  Future<void> _toggle(WidgetRef ref, bool done) async {
    final writer = await ref.read(localWriterProvider.future);
    await writer.update('tasks', task.id, statusFields(done ? TaskStatus.completed : TaskStatus.open, DateTime.now()));
    ref.read(syncControllerProvider.notifier).requestSoon();
  }

  /// Makes this task a subtask of [parentId], or back to a top-level task when it is null. Its `section_id` is set to
  /// the section it is shown in, so an outdented task stays where it was rather than following a stale section.
  Future<void> _setParent(WidgetRef ref, String? parentId) async {
    await updateRow(ref, 'tasks', task.id, {'parent_id': parentId, 'section_id': section});
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'section':
        await moveTaskToSection(context, ref, task);
      case 'indent':
        await _setParent(ref, above);
      case 'outdent':
        await _setParent(ref, null);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // The box is drawn in the priority's colour, as in TickTick; a done task's box keeps the theme's colour.
    final flag = _done ? null : priorityColor(Priority.of(task.priority));
    final tags = parseTags(task.tags);
    final headline = task.dates(ref.watch(deviceZoneProvider).value).headline(DateTime.now());
    // A past due is red until the task is done or dropped.
    final overdue = (headline?.overdue ?? false) && task.status == TaskStatus.open.value;
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(start: 16 + 32.0 * depth, end: 16),
      leading: Checkbox(
        key: Key('taskCheck-${task.id}'),
        value: _done,
        side: flag == null ? null : BorderSide(color: flag, width: 2),
        onChanged: (v) => _toggle(ref, v ?? false),
      ),
      title: Text(
        task.title.isEmpty ? '(untitled)' : task.title,
        style: _done ? TextStyle(decoration: TextDecoration.lineThrough, color: muted) : null,
      ),
      subtitle: headline == null && tags.isEmpty
          ? null
          : Row(
              children: [
                if (headline != null)
                  Text(
                    headlineText(context, headline),
                    key: Key('taskDue-${task.id}'),
                    style: TextStyle(color: overdue ? Theme.of(context).colorScheme.error : muted),
                  ),
                if (headline != null && tags.isNotEmpty) const SizedBox(width: 12),
                if (tags.isNotEmpty)
                  Flexible(
                    child: Text(
                      tags.map((t) => '#$t').join('  '),
                      key: Key('taskTags-${task.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted),
                    ),
                  ),
              ],
            ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(task: task))),
      trailing: PopupMenuButton<String>(
        key: Key('taskMenu-${task.id}'),
        tooltip: 'Task options',
        onSelected: (value) => _onMenu(context, ref, value),
        itemBuilder: (_) => [
          // A subtask is filed under its parent's section, so only a top-level task moves on its own.
          if (depth == 0) const PopupMenuItem(value: 'section', child: Text('Move to section')),
          if (above != null && task.parentId != above) const PopupMenuItem(value: 'indent', child: Text('Indent')),
          if (task.parentId != null) const PopupMenuItem(value: 'outdent', child: Text('Outdent')),
        ],
      ),
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
