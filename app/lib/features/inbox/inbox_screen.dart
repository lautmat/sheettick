import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/db/database.dart';
import '../../core/parse/quick_add.dart';
import '../../core/providers.dart';
import '../../core/sync/background_sync.dart' show describeBackgroundSync;
import '../../core/sync/sync_controller.dart';
import '../../core/tasks/priority.dart';
import '../../core/tasks/quick_add_create.dart';
import '../../core/tasks/smart_lists.dart';
import '../../core/tasks/tags.dart';
import '../../core/tasks/task_completion.dart';
import '../../core/tasks/task_dates.dart';
import '../../core/tasks/task_order.dart';
import '../../core/tasks/task_postpone.dart';
import '../../core/tasks/task_skip.dart';
import '../../core/tasks/task_status.dart';
import '../../core/tasks/task_tree.dart';
import '../common/local_edit.dart';
import '../common/theme.dart';
import '../common/undo.dart';
import '../desktop/desktop_menu.dart';
import '../desktop/desktop_providers.dart';
import '../lists/lists_providers.dart';
import 'background_sync_status.dart';
import '../lists/lists_sidebar.dart';
import '../lists/sort_group_dialog.dart';
import '../search/search_screen.dart';
import '../sections/sections_providers.dart';
import '../sections/sections_widgets.dart';
import '../smart/smart_providers.dart';
import '../tasks/date_labels.dart';
import '../tasks/postpone_action.dart';
import '../tasks/selection_bar.dart';
import '../tasks/skip_action.dart';
import '../tasks/task_attributes.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_drag.dart';
import '../tasks/task_pane_providers.dart';
import '../tasks/task_providers.dart';
import '../tasks/task_selection.dart';
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

  /// Does [action] to the tasks picked. From here, not from the bar, so it can finish after the bar has gone.
  Future<void> _runBulk(BulkAction action) =>
      runBulkAction(context, ref, ref.read(selectedTasksProvider), action);

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeListProvider);
    final smart = ref.watch(selectedSmartListProvider);
    final selecting = ref.watch(selectingProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= kSidebarBreakpoint;
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final selectedId = width >= kSplitBreakpoint ? ref.watch(selectedTaskIdProvider) : null;
    final selectedTask = selectedId == null ? null : ref.watch(taskProvider(selectedId)).value;
    // Every picked task left the screen (done, moved, synced away): nothing is left to act on.
    ref.listen(selectedTasksProvider, (_, picked) {
      if (picked.isEmpty) ref.read(taskSelectionProvider.notifier).clear();
    });
    final screen = PopScope(
      // Back ends a selection before it leaves the app.
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(taskSelectionProvider.notifier).clear();
      },
      child: Scaffold(
        appBar: selecting
            ? const SelectionAppBar()
            : AppBar(
                leading: wide
                    ? IconButton(
                        key: const Key('toggleSidebar'),
                        tooltip: collapsed ? 'Show lists' : 'Hide lists',
                        icon: const Icon(Icons.menu_open),
                        onPressed: () => ref.read(sidebarCollapsedProvider.notifier).toggle(),
                      )
                    : null,
                title: Text(smart?.label ?? _titleOf(active.value)),
                actions: [
                  if (smart == null && active.value != null) ...[
                    SortGroupButton(list: active.value!),
                    NewSectionButton(listId: active.value!.id),
                  ],
                  IconButton(
                    key: const Key('searchButton'),
                    tooltip: 'Search',
                    icon: const Icon(Icons.search),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
                  ),
                  const _SyncButton(),
                  const DesktopMenu(),
                  const ThemeMenu(),
                  const _AccountMenu(),
                ],
              ),
        drawer: wide ? null : const Drawer(child: SafeArea(child: ListsSidebar())),
        body: Column(
          children: [
            const _SyncBanner(),
            Expanded(
              child: smart != null
                  ? _SmartBody(smart: smart)
                  : active.when(
                      data: (list) => list == null ? const _NoInbox() : _InboxBody(list: list),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Could not read the local database: $e')),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: selecting ? SelectionBar(onAction: _runBulk) : null,
      ),
    );
    if (!wide) return screen;
    return Row(
      children: [
        if (!collapsed) ...[
          SizedBox(
            width: kSidebarWidth,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const SafeArea(right: false, child: ListsSidebar()),
            ),
          ),
          const VerticalDivider(width: 1),
        ],
        Expanded(child: screen),
        if (selectedTask != null && !selectedTask.deleted) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            key: const Key('taskPane'),
            width: kTaskPaneWidth,
            child: TaskDetailScreen(key: ValueKey(selectedTask.id), task: selectedTask, embedded: true),
          ),
        ],
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
        if (ref.read(backgroundSyncVisibleProvider))
          PopupMenuItem<void>(
            enabled: false,
            child: Consumer(
              builder: (context, ref, _) => Text(
                describeBackgroundSync(ref.watch(backgroundSyncRecordProvider).value, DateTime.now()),
                key: const Key('backgroundSyncStatus'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
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
    final zone = ref.watch(deviceZoneProvider).value;
    final listNames = {
      for (final l in ref.watch(sidebarListsProvider).value ?? const <TaskList>[]) l.id: l.name,
    };
    final selecting = ref.watch(selectingProvider);
    final completedCollapsed = ref.watch(completedCollapsedProvider).value ?? false;
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
                  : DragAutoScroll(
                      builder: (context, controller) => ListView(
                        controller: controller,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: _rows(
                          sortTasks(items, TaskOrder.of(list.orderBy), zone: zone),
                          sections,
                          listId: list.id,
                          manual: TaskOrder.of(list.orderBy) == TaskOrder.manual,
                          group: TaskGroup.of(list.groupBy),
                          zone: zone,
                          listNames: listNames,
                          completedCollapsed: completedCollapsed,
                        ),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not read tasks: $e')),
            ),
          ),
        ),
        // A batch edit has its own bar at the bottom, and the keyboard has no business there.
        if (!selecting) _AddBar(listId: list.id),
      ],
    );
  }
}

/// The heading above a group of tasks, with how many top-level tasks are in it.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: Key('group-$label'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text('$label  $count', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

/// What each smart list says when it has no tasks.
const _smartEmpty = {
  SmartList.today: 'Nothing due today.',
  SmartList.tomorrow: 'Nothing due tomorrow.',
  SmartList.next7Days: 'Nothing due in the next 7 days.',
  SmartList.all: 'No open tasks.',
  SmartList.noDate: 'Every open task has a date.',
  SmartList.completed: 'No completed tasks yet.',
  SmartList.wontDo: "No tasks marked Won't Do.",
  SmartList.trash: 'The Trash is empty.',
};

/// A smart list: tasks from every list, flat, with no add bar. Trash rows carry a Restore button.
class _SmartBody extends ConsumerWidget {
  const _SmartBody({required this.smart});

  final SmartList smart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(smartListRowsProvider(smart));
    final zone = ref.watch(deviceZoneProvider).value;
    return RefreshIndicator(
      onRefresh: () => ref.read(syncControllerProvider.notifier).sync(),
      child: rows.when(
        data: (items) => items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(child: Text(_smartEmpty[smart]!, key: const Key('smartEmpty'))),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (smart == SmartList.today) _OverdueBar(tasks: [for (final t in items) if (isOverdueTask(t, now: DateTime.now(), zone: zone)) t]),
                  for (final t in items)
                    smart == SmartList.trash
                        ? _TrashTile(key: ValueKey(t.id), task: t)
                        : _TaskTile(key: ValueKey(t.id), task: t, menu: false),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not read tasks: $e')),
      ),
    );
  }
}

/// The line at the top of Today that counts the overdue tasks and postpones them all at once. Nothing when none is overdue.
class _OverdueBar extends ConsumerWidget {
  const _OverdueBar({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return ListTile(
      key: const Key('overdueBar'),
      dense: true,
      leading: Icon(Icons.schedule, color: theme.colorScheme.error),
      title: Text('${tasks.length} overdue', style: TextStyle(color: theme.colorScheme.error)),
      trailing: PopupMenuButton<PostponeTarget>(
        key: const Key('postponeOverdue'),
        tooltip: 'Postpone all overdue',
        onSelected: (target) => postponeWithUndo(ref, tasks, target),
        itemBuilder: (_) => [
          const PopupMenuItem(enabled: false, height: 32, child: Text('Postpone all to')),
          for (final t in [PostponeTarget.today, PostponeTarget.tomorrow, PostponeTarget.nextWeek])
            PopupMenuItem(value: t, child: Text(t.label)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text('Postpone all', style: TextStyle(color: theme.colorScheme.primary)),
        ),
      ),
    );
  }
}

/// A task in the Trash: its title, and a button that puts it back.
class _TrashTile extends ConsumerWidget {
  const _TrashTile({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(task.title.isEmpty ? '(untitled)' : task.title),
      trailing: IconButton(
        key: Key('restore-${task.id}'),
        tooltip: 'Restore',
        icon: const Icon(Icons.restore_from_trash_outlined),
        onPressed: () => updateRow(ref, 'tasks', task.id, {'deleted': false}, undo: 'Task restored'),
      ),
    );
  }
}

/// The rows of a list: the tasks outside any section first, then each section's heading and, unless it is
/// folded, its tasks. A subtask is shown under its top-level task, in that task's section.
///
/// Tasks can be dragged; with [manual] (the list is in its own order) one can also be dropped before another. A heading,
/// "No section" above the first heading and the end of the list take a dropped task whatever the order.
List<Widget> _rows(
  List<Task> items,
  List<Section> sections, {
  required String listId,
  bool manual = true,
  TaskGroup group = TaskGroup.none,
  String? zone,
  Map<String, String> listNames = const {},
  bool completedCollapsed = false,
}) {
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
  // A block whose top-level task is completed, subtasks and all, is shown under "Completed" at the foot of the list.
  // A subtask still open under an open task stays with it, checked or not.
  bool isDone(List<({Task item, int depth})> block) => block.first.item.status == TaskStatus.completed.value;
  final open = [for (final b in blocks) if (!isDone(b)) b];
  final done = [for (final b in blocks) if (isDone(b)) b];

  if (group != TaskGroup.none) {
    // Grouped, the list is shown by group instead of by section, and a task has no place to be moved or indented to.
    final groups = groupRows(
      [for (final b in open) ...b],
      group,
      now: DateTime.now(),
      zone: zone,
      listNames: listNames,
    );
    return [
      for (final g in groups) ...[
        _GroupHeader(label: g.label, count: g.rows.where((r) => r.depth == 0).length),
        for (final row in g.rows)
          _TaskTile(key: ValueKey('${g.label}/${row.item.id}'), task: row.item, depth: row.depth, menu: false),
      ],
      ..._completedRows(done, known: known, collapsed: completedCollapsed, menu: false),
    ];
  }
  bool inSection(List<({Task item, int depth})> block, String id) => block.first.item.sectionId == id;

  final shown = <Object>[
    for (final b in open)
      if (!known.contains(b.first.item.sectionId)) ...b,
  ];
  for (final s in sections) {
    shown.add(s);
    if (!s.collapsed) {
      for (final b in open.where((b) => inSection(b, s.id))) {
        shown.addAll(b);
      }
    }
  }

  final widgets = <Widget>[];
  // The task shown just above the next row: indenting a task puts it under that one. A heading breaks the chain.
  String? above;
  // The section the rows are shown in, null above the first heading.
  String? section;
  String? firstIn(String? sectionId) {
    for (final b in blocks) {
      final task = b.first.item;
      if ((known.contains(task.sectionId) ? task.sectionId : null) == sectionId) return task.id;
    }
    return null;
  }

  if (sections.isNotEmpty) {
    // Shown only while a task is dragged: the way out of every section, to the top of the unsectioned tasks.
    widgets.add(
      DropRow(
        key: const Key('dropNoSection'),
        label: 'No section',
        accepts: (_) => true,
        onDrop: (ref, dragged) => moveTaskTo(ref, dragged, listId: listId, beforeId: firstIn(null)),
      ),
    );
  }
  for (final entry in shown) {
    if (entry is Section) {
      above = null;
      section = entry.id;
      final count = open.where((b) => inSection(b, entry.id)).fold(0, (n, b) => n + b.length);
      widgets.add(SectionHeader(section: entry, count: count, firstTaskId: firstIn(entry.id)));
    } else {
      final row = entry as ({Task item, int depth});
      widgets.add(
        TaskDragShell(
          key: ValueKey(row.item.id),
          task: row.item,
          depth: row.depth,
          listId: listId,
          section: section,
          reorder: manual,
          // A top-level row's long press belongs to the drag shell on a touch screen (it drags or it selects).
          child: _TaskTile(task: row.item, depth: row.depth, above: above, section: section, shellHoldsPress: row.depth == 0),
        ),
      );
      above = row.item.id;
    }
  }
  // Shown only while a task is dragged: the end of the last section, or of the list when it has none.
  widgets.add(
    DropRow(
      key: const Key('dropEnd'),
      label: sections.isEmpty ? 'End of the list' : 'End of ${sections.last.name}',
      accepts: (_) => true,
      onDrop: (ref, dragged) =>
          moveTaskTo(ref, dragged, listId: listId, sectionId: sections.isEmpty ? null : sections.last.id),
    ),
  );
  widgets.addAll(_completedRows(done, known: known, collapsed: completedCollapsed));
  return widgets;
}

/// The "Completed" heading at the foot of a list, and under it the completed tasks unless it is folded. A completed task
/// is not dragged: it has no place among the open tasks, so it is brought back by unticking it.
///
/// A task keeps its top-level task's section, so Indent and Outdent in its menu leave it where it was.
List<Widget> _completedRows(
  List<List<({Task item, int depth})>> done, {
  required Set<String> known,
  required bool collapsed,
  bool menu = true,
}) {
  if (done.isEmpty) return const [];
  final widgets = <Widget>[_CompletedHeader(count: done.length, collapsed: collapsed)];
  if (collapsed) return widgets;
  // What a subtask can be indented under is the row above it. The heading breaks the chain.
  String? above;
  for (final block in done) {
    final sectionId = block.first.item.sectionId;
    final section = known.contains(sectionId) ? sectionId : null;
    for (final row in block) {
      widgets.add(
        _TaskTile(
          key: ValueKey('completed/${row.item.id}'),
          task: row.item,
          depth: row.depth,
          above: above,
          section: section,
          menu: menu,
        ),
      );
      above = row.item.id;
    }
  }
  return widgets;
}

/// The heading at the foot of a list over its completed tasks, with how many there are. Tapping it folds or unfolds them,
/// as TickTick does; the choice is kept on this device.
class _CompletedHeader extends ConsumerWidget {
  const _CompletedHeader({required this.count, required this.collapsed});

  /// The number of completed top-level tasks.
  final int count;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      key: const Key('completedHeader'),
      dense: true,
      leading: Icon(collapsed ? Icons.chevron_right : Icons.expand_more),
      title: Text('Completed', style: Theme.of(context).textTheme.titleSmall),
      trailing: Text('$count', key: const Key('completedCount'), style: TextStyle(color: muted)),
      onTap: () => ref.read(completedCollapsedProvider.notifier).toggle(),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    super.key,
    required this.task,
    this.depth = 0,
    this.above,
    this.section,
    this.menu = true,
    this.shellHoldsPress = false,
  });

  final Task task;

  /// Whether a [TaskDragShell] around the row takes its long press on a touch screen. Then the shell starts the
  /// selection (when the finger lifts without dragging), and the row must not compete for the press.
  final bool shellHoldsPress;

  /// False in the smart lists, where a task has no section or place among its siblings to move to.
  final bool menu;

  /// How many levels the task is nested under a top-level task.
  final int depth;

  /// The id of the task shown directly above this one, or null when a heading or the list's start is above it.
  final String? above;

  /// The section the task is shown in, null when it is shown outside any section. A subtask is shown in its
  /// top-level task's section, whatever its own `section_id` says.
  final String? section;

  bool get _done => task.status == TaskStatus.completed.value;

  Future<void> _toggle(WidgetRef ref, bool done) async {
    final zone = await ref.read(deviceZoneProvider.future);
    // Finishing a repeating task also creates its next round, which undoing tombstones again.
    await changeWithUndo<String?>(
      ref,
      done ? 'Task completed' : 'Task reopened',
      [(tab: 'tasks', id: task.id)],
      (writer) =>
          setTaskStatus(writer, task, done ? TaskStatus.completed : TaskStatus.open, now: DateTime.now(), zone: zone),
      created: (next) => [if (next != null) (tab: 'tasks', id: next)],
    );
  }

  /// Makes this task a subtask of [parentId], or back to a top-level task when it is null. Its `section_id` is set to
  /// the section it is shown in, so an outdented task stays where it was rather than following a stale section.
  Future<void> _setParent(WidgetRef ref, String? parentId) async {
    await updateRow(ref, 'tasks', task.id, {'parent_id': parentId, 'section_id': section}, undo: 'Task moved');
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'select':
        ref.read(taskSelectionProvider.notifier).add(task.id);
      case 'section':
        await moveTaskToSection(context, ref, task);
      case 'list':
        await moveTaskToList(context, ref, task);
      case 'indent':
        await _setParent(ref, above);
      case 'outdent':
        await _setParent(ref, null);
      case 'skip':
        await skipTaskOccurrence(context, ref, task);
      default:
        final target = postponeTargetOf(value);
        if (target != null) await postponeWithUndo(ref, [task], target);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // The box is drawn in the priority's colour, as in TickTick; a done task's box keeps the theme's colour.
    final flag = _done ? null : priorityColor(Priority.of(task.priority));
    final tags = parseTags(task.tags);
    final zone = ref.watch(deviceZoneProvider).value;
    final headline = task.dates(zone).headline(DateTime.now());
    final selecting = ref.watch(selectingProvider);
    final picked = ref.watch(taskSelectionProvider.select((s) => s.contains(task.id)));
    final selection = ref.read(taskSelectionProvider.notifier);
    final actions = <PopupMenuEntry<String>>[
      if (canSkipOccurrence(task)) const PopupMenuItem(value: 'skip', child: Text('Skip this occurrence')),
      if (menu) ...[
        // A subtask is filed under its parent's section, so only a top-level task moves on its own.
        if (depth == 0) const PopupMenuItem(value: 'section', child: Text('Move to section')),
        if (depth == 0) const PopupMenuItem(value: 'list', child: Text('Move to list')),
        if (above != null && task.parentId != above) const PopupMenuItem(value: 'indent', child: Text('Indent')),
        if (task.parentId != null) const PopupMenuItem(value: 'outdent', child: Text('Outdent')),
      ],
      ...postponeMenuEntries(task, now: DateTime.now(), zone: zone),
    ];
    // A row with nothing to offer has no menu (a done task in the Completed list); a long press still picks it.
    final menuItems = actions.isEmpty
        ? actions
        : <PopupMenuEntry<String>>[const PopupMenuItem(value: 'select', child: Text('Select')), ...actions];
    // A past due is red until the task is done or dropped.
    final overdue = (headline?.overdue ?? false) && task.status == TaskStatus.open.value;
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(start: 16 + 32.0 * depth, end: 16),
      selected: picked || ref.watch(selectedTaskIdProvider) == task.id,
      selectedTileColor: primary.withValues(alpha: 0.12),
      // While a selection is under way the check box gives way to a tick that says whether the row is picked.
      leading: selecting
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                picked ? Icons.check_circle : Icons.radio_button_unchecked,
                key: Key('taskPick-${task.id}'),
                color: picked ? primary : muted,
              ),
            )
          : Checkbox(
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
      onTap: selecting ? () => selection.toggle(task.id) : () => openTask(context, ref, task),
      // A long press picks the row. Where a drag shell holds the press on a touch screen, it does the picking.
      onLongPress: selecting || (shellHoldsPress && isTouchPlatform(context)) ? null : () => selection.add(task.id),
      trailing: selecting || menuItems.isEmpty
          ? null
          : PopupMenuButton<String>(
              key: Key('taskMenu-${task.id}'),
              tooltip: 'Task options',
              onSelected: (value) => _onMenu(context, ref, value),
              itemBuilder: (_) => menuItems,
            ),
    );
  }
}

class _AddBar extends ConsumerStatefulWidget {
  const _AddBar({required this.listId});

  /// The list on screen: where a task goes when its text names no list.
  final String listId;

  @override
  ConsumerState<_AddBar> createState() => _AddBarState();
}

class _AddBarState extends ConsumerState<_AddBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The preview under the field follows what is typed.
    _controller.addListener(() => setState(() {}));
    // A hotkey request that brought this bar on screen is answered once it is there.
    WidgetsBinding.instance.addPostFrameCallback((_) => _answerFocusRequest());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The quick-add hotkey asks for the keyboard focus (see `openQuickAdd`).
  void _answerFocusRequest() {
    if (mounted && ref.read(quickAddRequestProvider.notifier).take()) _focus.requestFocus();
  }

  QuickAddResult _parse(String text, String? zone) =>
      parseQuickAdd(text, now: TaskDates(zone: zone).wallOf(DateTime.now()), zone: zone);

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // Cleared first so a second tap or Enter cannot add the same task twice while the write is in flight; the
    // text is put back if the write fails, so nothing the user typed is lost.
    _controller.clear();
    String? missingList;
    try {
      final zone = await ref.read(deviceZoneProvider.future);
      final writer = await ref.read(localWriterProvider.future);
      final created = await createQuickAddTask(
        writer,
        _parse(text, zone),
        fallbackListId: widget.listId,
        defaultDay: TaskDates(zone: zone).wallOf(DateTime.now()),
      );
      missingList = created.missingList;
    } catch (e) {
      if (!mounted) return;
      if (_controller.text.isEmpty) _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the task: $e')));
      return;
    }
    ref.read(syncControllerProvider.notifier).requestSoon();
    if (missingList != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('There is no list called "$missingList", so the task was added to this list.')),
      );
    }
  }

  /// What the text will become, in a few words, or null when it is plain text or the device zone is not known yet
  /// (without it "today" could be the wrong day, so no preview is better than a wrong one).
  String? _previewText(String? zone) {
    final text = _controller.text.trim();
    if (text.isEmpty || zone == null) return null;
    final parsed = _parse(text, zone);
    if (!parsed.hasFields) return null;
    final parts = <String>[
      if (!parsed.dates.isEmpty)
        datesSummary(
          context,
          TaskDates(due: parsed.dates.due, allDay: parsed.dates.allDay, zone: zone),
          DateTime.now(),
        ),
      if (parsed.rrule != null) 'repeats',
      for (final tag in parsed.tags) '#$tag',
      if (parsed.listName != null) '^${parsed.listName}',
      if (parsed.priority != null && parsed.priority != 0) '${Priority.of(parsed.priority!).label} priority',
    ];
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(quickAddRequestProvider, (_, _) => WidgetsBinding.instance.addPostFrameCallback((_) => _answerFocusRequest()));
    final zone = ref.watch(deviceZoneProvider).value;
    final preview = _previewText(zone);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  preview,
                  key: const Key('quickAddPreview'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('addTaskField'),
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Add a task: "call Sam fri 3pm #work !high"',
                      border: InputBorder.none,
                    ),
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
          ],
        ),
      ),
    );
  }
}
