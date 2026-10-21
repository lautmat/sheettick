import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import '../common/local_edit.dart';
import '../common/name_dialog.dart';
import '../common/pick_dialog.dart';
import 'sections_providers.dart';

/// Adds a section to the list on screen.
class NewSectionButton extends ConsumerWidget {
  const NewSectionButton({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const Key('newSection'),
      tooltip: 'New section',
      icon: const Icon(Icons.playlist_add),
      onPressed: () => _newSection(context, ref, listId),
    );
  }
}

Future<void> _newSection(BuildContext context, WidgetRef ref, String listId) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const NameDialog(title: 'New section'),
  );
  if (name == null || name.trim().isEmpty) return;
  final sections = await ref.read(sectionsProvider(listId).future);
  final writer = await ref.read(localWriterProvider.future);
  await writer.insert('sections', {
    'list_id': listId,
    'name': name.trim(),
    'sort_order': nextSortOrder(sections.map((s) => s.sortOrder)),
  });
  ref.read(syncControllerProvider.notifier).requestSoon();
}

/// A section's heading in its list. Tapping it folds the section; its menu renames it. [count] is the number of
/// tasks in it.
class SectionHeader extends ConsumerWidget {
  const SectionHeader({super.key, required this.section, required this.count});

  final Section section;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      key: Key('section-${section.id}'),
      dense: true,
      leading: Icon(section.collapsed ? Icons.chevron_right : Icons.expand_more),
      title: Text(
        section.name.isEmpty ? '(untitled section)' : section.name,
        style: Theme.of(context).textTheme.titleSmall,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count', style: TextStyle(color: muted)),
          PopupMenuButton<String>(
            key: Key('sectionMenu-${section.id}'),
            tooltip: 'Section options',
            onSelected: (_) => _renameSection(context, ref, section),
            itemBuilder: (_) => const [PopupMenuItem(value: 'rename', child: Text('Rename'))],
          ),
        ],
      ),
      onTap: () => updateRow(ref, 'sections', section.id, {'collapsed': !section.collapsed}),
    );
  }
}

Future<void> _renameSection(BuildContext context, WidgetRef ref, Section section) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => NameDialog(title: 'Rename section', initial: section.name),
  );
  if (name == null || name.trim().isEmpty || name.trim() == section.name) return;
  await updateRow(ref, 'sections', section.id, {'name': name.trim()});
}

/// Asks which section a task belongs to, and moves it there. The task stays in its list.
Future<void> moveTaskToSection(BuildContext context, WidgetRef ref, Task task) async {
  final listId = task.listId;
  if (listId == null) return;
  final sections = await ref.read(sectionsProvider(listId).future);
  if (!context.mounted) return;
  // '' means "no section"; null means the dialog was cancelled.
  final picked = await showDialog<String>(
    context: context,
    builder: (_) => PickDialog(
      title: 'Move to section',
      noneLabel: 'No section',
      options: [for (final s in sections) (id: s.id, name: s.name)],
      current: task.sectionId,
    ),
  );
  if (picked == null) return;
  await updateRow(ref, 'tasks', task.id, {'section_id': picked.isEmpty ? null : picked});
}
