import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/smart_lists.dart';
import '../../core/sync/sync_controller.dart';
import '../common/local_edit.dart';
import '../common/name_dialog.dart';
import '../common/pick_dialog.dart';
import '../tasks/task_drag.dart';
import 'lists_providers.dart';

/// Screens at least this wide keep the sidebar beside the list; narrower ones put it in a drawer.
const kSidebarBreakpoint = 720.0;
const kSidebarWidth = 280.0;

/// The colours a list can take, stored as `#RRGGBB` in `lists.color`.
const kListColours = ['#E53935', '#FB8C00', '#FDD835', '#43A047', '#00897B', '#1E88E5', '#8E24AA', '#6D4C41'];

/// Folders with their lists, the Archived lists, and buttons to add a list or a folder.
class ListsSidebar extends ConsumerWidget {
  const ListsSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(sidebarListsProvider).value ?? const <TaskList>[];
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final folderIds = {for (final f in folders) f.id};
    // A list whose folder was deleted shows at the top level.
    bool inFolder(TaskList l) => !l.isInbox && l.folderId != null && folderIds.contains(l.folderId);
    final live = lists.where((l) => !l.archived).toList();
    final archived = lists.where((l) => l.archived && !l.isInbox).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final s in SmartList.values.where((s) => s.index < SmartList.completed.index)) _SmartTile(smart: s),
        const Divider(),
        for (final l in live.where((l) => !inFolder(l))) _ListTile(list: l),
        for (final f in folders) ...[
          _FolderHeader(folder: f),
          for (final l in live.where((l) => l.folderId == f.id && !l.isInbox)) _ListTile(list: l, indented: true),
        ],
        if (archived.isNotEmpty) _ArchivedSection(lists: archived),
        const Divider(),
        for (final s in SmartList.values.where((s) => s.index >= SmartList.completed.index)) _SmartTile(smart: s),
        const Divider(),
        ListTile(
          key: const Key('newList'),
          leading: const Icon(Icons.add),
          title: const Text('New list'),
          onTap: () => _newList(context, ref),
        ),
        ListTile(
          key: const Key('newFolder'),
          leading: const Icon(Icons.create_new_folder_outlined),
          title: const Text('New folder'),
          onTap: () => _newFolder(context, ref),
        ),
      ],
    );
  }
}

// ---- Lists ------------------------------------------------------------------------------------------------------

const _smartIcons = {
  SmartList.today: Icons.today_outlined,
  SmartList.tomorrow: Icons.event_outlined,
  SmartList.next7Days: Icons.date_range_outlined,
  SmartList.all: Icons.all_inbox_outlined,
  SmartList.completed: Icons.check_circle_outline,
  SmartList.wontDo: Icons.block_outlined,
  SmartList.trash: Icons.delete_outline,
};

/// One of the built-in lists that show tasks from every list.
class _SmartTile extends ConsumerWidget {
  const _SmartTile({required this.smart});

  final SmartList smart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: Key('smart-${smart.name}'),
      selected: ref.watch(selectedSmartListProvider) == smart,
      leading: Icon(_smartIcons[smart]),
      title: Text(smart.label),
      onTap: () {
        ref.read(selectedSmartListProvider.notifier).select(smart);
        Scaffold.maybeOf(context)?.closeDrawer();
      },
    );
  }
}

class _ListTile extends ConsumerWidget {
  const _ListTile({required this.list, this.indented = false});

  final TaskList list;
  final bool indented;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inSmart = ref.watch(selectedSmartListProvider) != null;
    final activeId = inSmart ? null : ref.watch(activeListProvider).value?.id;
    final scheme = Theme.of(context).colorScheme;
    // A task dropped on a list goes to the end of it, outside any section.
    return TaskDropTarget(
      accepts: (dragged) => dragged.listId != list.id && !list.archived,
      onDrop: (dragged) => moveTaskTo(ref, dragged, listId: list.id, label: 'Moved to ${list.name}'),
      child: _tile(context, ref, scheme, activeId),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, ColorScheme scheme, String? activeId) {
    return ListTile(
      key: Key('list-${list.id}'),
      contentPadding: EdgeInsets.only(left: indented ? 32 : 16, right: list.isInbox ? 16 : 0),
      selected: activeId == list.id,
      leading: list.isInbox
          ? const Icon(Icons.inbox_outlined)
          : Icon(Icons.circle, size: 12, color: _parseColour(list.color) ?? scheme.outlineVariant),
      title: Text(list.name.isEmpty ? '(untitled)' : list.name, overflow: TextOverflow.ellipsis),
      trailing: list.isInbox ? null : _ListMenu(list: list),
      onTap: () {
        openList(ref, list.id);
        Scaffold.maybeOf(context)?.closeDrawer();
      },
    );
  }
}

enum _ListAction { rename, colour, move, archive }

class _ListMenu extends ConsumerWidget {
  const _ListMenu({required this.list});

  final TaskList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ListAction>(
      key: Key('listMenu-${list.id}'),
      tooltip: 'List options',
      onSelected: (action) {
        switch (action) {
          case _ListAction.rename:
            _renameList(context, ref, list);
          case _ListAction.colour:
            _colourList(context, ref, list);
          case _ListAction.move:
            _moveList(context, ref, list);
          case _ListAction.archive:
            // Leave the list on screen if it was the one open; the Inbox takes its place.
            if (ref.read(selectedListIdProvider) == list.id) ref.read(selectedListIdProvider.notifier).select(null);
            updateRow(ref, 'lists', list.id, {'archived': true});
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: _ListAction.rename, child: Text('Rename')),
        PopupMenuItem(value: _ListAction.colour, child: Text('Colour')),
        PopupMenuItem(value: _ListAction.move, child: Text('Move to folder')),
        PopupMenuItem(value: _ListAction.archive, child: Text('Archive')),
      ],
    );
  }
}

class _ArchivedSection extends ConsumerWidget {
  const _ArchivedSection({required this.lists});

  final List<TaskList> lists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      key: const Key('archived'),
      leading: const Icon(Icons.archive_outlined),
      title: Text('Archived (${lists.length})'),
      children: [
        for (final l in lists)
          ListTile(
            key: Key('archived-${l.id}'),
            contentPadding: const EdgeInsets.only(left: 32, right: 8),
            title: Text(l.name.isEmpty ? '(untitled)' : l.name, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Restore',
              icon: const Icon(Icons.unarchive_outlined),
              onPressed: () => updateRow(ref, 'lists', l.id, {'archived': false}),
            ),
          ),
      ],
    );
  }
}

Future<void> _newList(BuildContext context, WidgetRef ref) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const NameDialog(title: 'New list'),
  );
  if (name == null || name.trim().isEmpty) return;
  // Read the lists when the name is in, not when the sidebar was built: the snapshot may still be loading.
  final lists = await ref.read(sidebarListsProvider.future);
  final writer = await ref.read(localWriterProvider.future);
  final id = await writer.insert('lists', {
    'name': name.trim(),
    'sort_order': nextSortOrder(lists.map((l) => l.sortOrder)),
  });
  openList(ref, id);
  ref.read(syncControllerProvider.notifier).requestSoon();
}

Future<void> _renameList(BuildContext context, WidgetRef ref, TaskList list) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => NameDialog(title: 'Rename list', initial: list.name),
  );
  if (name == null || name.trim().isEmpty || name.trim() == list.name) return;
  await updateRow(ref, 'lists', list.id, {'name': name.trim()});
}

Future<void> _colourList(BuildContext context, WidgetRef ref, TaskList list) async {
  // '' means "no colour"; null means the dialog was cancelled.
  final picked = await showDialog<String>(
    context: context,
    builder: (_) => _ColourDialog(current: list.color),
  );
  if (picked == null) return;
  await updateRow(ref, 'lists', list.id, {'color': picked.isEmpty ? null : picked});
}

Future<void> _moveList(BuildContext context, WidgetRef ref, TaskList list) async {
  // Wait for the first emission, so the dialog never opens with the folders missing.
  final folders = await ref.read(foldersProvider.future);
  if (!context.mounted) return;
  // '' means "no folder"; null means the dialog was cancelled.
  final picked = await showDialog<String>(
    context: context,
    builder: (_) => PickDialog(
      title: 'Move to folder',
      noneLabel: 'No folder',
      options: [for (final f in folders) (id: f.id, name: f.name)],
      current: list.folderId,
    ),
  );
  if (picked == null) return;
  await updateRow(ref, 'lists', list.id, {'folder_id': picked.isEmpty ? null : picked});
}

// ---- Folders ----------------------------------------------------------------------------------------------------

enum _FolderAction { rename, delete }

class _FolderHeader extends ConsumerWidget {
  const _FolderHeader({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: Key('folder-${folder.id}'),
      dense: true,
      leading: const Icon(Icons.folder_outlined),
      title: Text(
        folder.name.isEmpty ? '(untitled)' : folder.name,
        style: Theme.of(context).textTheme.titleSmall,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<_FolderAction>(
        key: Key('folderMenu-${folder.id}'),
        tooltip: 'Folder options',
        onSelected: (action) {
          switch (action) {
            case _FolderAction.rename:
              _renameFolder(context, ref, folder);
            case _FolderAction.delete:
              _deleteFolder(context, ref, folder);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: _FolderAction.rename, child: Text('Rename')),
          PopupMenuItem(value: _FolderAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }
}

Future<void> _newFolder(BuildContext context, WidgetRef ref) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const NameDialog(title: 'New folder'),
  );
  if (name == null || name.trim().isEmpty) return;
  final folders = await ref.read(foldersProvider.future);
  final writer = await ref.read(localWriterProvider.future);
  await writer.insert('folders', {'name': name.trim(), 'sort_order': nextSortOrder(folders.map((f) => f.sortOrder))});
  ref.read(syncControllerProvider.notifier).requestSoon();
}

Future<void> _renameFolder(BuildContext context, WidgetRef ref, Folder folder) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => NameDialog(title: 'Rename folder', initial: folder.name),
  );
  if (name == null || name.trim().isEmpty || name.trim() == folder.name) return;
  await updateRow(ref, 'folders', folder.id, {'name': name.trim()});
}

Future<void> _deleteFolder(BuildContext context, WidgetRef ref, Folder folder) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete folder?'),
      content: Text('"${folder.name}" is removed. Its lists stay and move to the top level.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed != true) return;
  final writer = await ref.read(localWriterProvider.future);
  await writer.delete('folders', folder.id);
  ref.read(syncControllerProvider.notifier).requestSoon();
}

// ---- Dialogs ----------------------------------------------------------------------------------------------------

class _ColourDialog extends StatelessWidget {
  const _ColourDialog({required this.current});

  final String? current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Colour'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final hex in kListColours)
            InkWell(
              key: Key('colour-$hex'),
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(context, hex),
              child: CircleAvatar(
                backgroundColor: _parseColour(hex),
                radius: 18,
                child: hex == current ? const Icon(Icons.check, color: Colors.white) : null,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          key: const Key('noColour'),
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('No colour'),
        ),
      ],
    );
  }
}

// ---- Helpers ----------------------------------------------------------------------------------------------------

/// `#RRGGBB` as a colour. Null for no colour, or for a value a hand edit in the Sheet left unreadable.
Color? _parseColour(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
