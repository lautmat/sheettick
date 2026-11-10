import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/task_status.dart';
import '../lists/lists_providers.dart';
import '../reminders/reminders_providers.dart';
import '../tasks/task_detail_screen.dart';

/// Live tasks whose title or notes match [text], best match first. Run again whenever a task changes, so a result
/// edited on the task page or by a sync is never stale.
final searchResultsProvider = FutureProvider.autoDispose.family<List<Task>, String>((ref, text) async {
  ref.watch(allTasksProvider);
  return ref.watch(appDatabaseProvider).searchTasks(text);
});

/// Search over the title and notes of every task, with the results updating as the user types.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(sidebarListsProvider).value ?? const <TaskList>[];
    final listNames = {for (final l in lists) l.id: l.name.isEmpty ? '(untitled)' : l.name};
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('searchField'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Search tasks and notes', border: InputBorder.none),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              key: const Key('clearSearch'),
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_controller.clear),
            ),
        ],
      ),
      body: _Results(text: _controller.text.trim(), listNames: listNames),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.text, required this.listNames});

  final String text;
  final Map<String, String> listNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (text.isEmpty) return const _Message('Type to search the titles and notes of your tasks.');
    final results = ref.watch(searchResultsProvider(text));
    final tasks = results.value;
    if (tasks == null) {
      // The local index answers within a frame, so a spinner on every keystroke would only flicker.
      return results.hasError ? _Message('Could not search: ${results.error}') : const SizedBox.shrink();
    }
    if (tasks.isEmpty) return _Message('No tasks match "$text".', key: const Key('searchEmpty'));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      children: [
        for (final t in tasks)
          ListTile(
            key: Key('result-${t.id}'),
            title: Text(
              t.title.isEmpty ? '(untitled)' : t.title,
              style: t.status == TaskStatus.open.value
                  ? null
                  : TextStyle(decoration: TextDecoration.lineThrough, color: muted),
            ),
            subtitle: Text(listNames[t.listId] ?? '', key: Key('resultList-${t.id}'), style: TextStyle(color: muted)),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(task: t))),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center)));
}
