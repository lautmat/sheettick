import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/sync/local_writer.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/tasks/priority.dart';
import '../../core/tasks/tags.dart';
import '../common/local_edit.dart';
import '../reminders/task_reminders.dart';
import 'task_dates_dialog.dart';

/// The names in the `tags` tab that are not deleted, in their order, each name once whatever its case.
final tagNamesProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.tags)
    ..where((t) => t.deleted.equals(false))
    ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.name)]);
  return query.watch().map((rows) => parseTags(formatTags(rows.map((r) => r.name))));
});

/// The colour that marks [priority]: red for high, orange for medium, blue for low, as in TickTick. Null for none.
Color? priorityColor(Priority priority) => switch (priority) {
  Priority.high => Colors.red.shade600,
  Priority.medium => Colors.orange.shade700,
  Priority.low => Colors.blue.shade600,
  Priority.none => null,
};

/// A task's dates, priority and tags on its page. Each change is written at once.
class TaskAttributes extends ConsumerStatefulWidget {
  const TaskAttributes({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<TaskAttributes> createState() => _TaskAttributesState();
}

class _TaskAttributesState extends ConsumerState<TaskAttributes> {
  final _tagField = TextEditingController();
  final _tagFocus = FocusNode();

  /// The last tag write queued. Each reads the `tags` value the one before it left, so two quick adds both land.
  Future<void> _queued = Future<void>.value();

  @override
  void dispose() {
    _tagField.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  /// Queues [write] after the tag writes before it. Everything it needs is taken now, while the widget is mounted.
  void _queue(Future<void> Function(LocalWriter writer) write) {
    final sync = ref.read(syncControllerProvider.notifier);
    final writerFuture = ref.read(localWriterProvider.future);
    _queued = _queued.then((_) async {
      try {
        await write(await writerFuture);
        sync.requestSoon();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the tag: $e')));
      }
    });
  }

  void _addTag(String raw) {
    _tagField.clear();
    if (cleanTagName(raw) == null) return;
    final id = widget.task.id;
    _queue((writer) => addTaskTag(writer, id, raw));
  }

  void _removeTag(String name) {
    final id = widget.task.id;
    _queue((writer) => removeTaskTag(writer, id, name));
  }

  @override
  Widget build(BuildContext context) {
    final priority = Priority.of(widget.task.priority);
    final tags = parseTags(widget.task.tags);
    final known = ref.watch(tagNamesProvider).value ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TaskDatesChip(task: widget.task),
          TaskRemindersChip(task: widget.task),
          PopupMenuButton<Priority>(
            key: const Key('taskPriority'),
            tooltip: 'Priority',
            initialValue: priority,
            onSelected: (p) => updateRow(ref, 'tasks', widget.task.id, {'priority': p.value}),
            itemBuilder: (_) => [
              for (final p in Priority.values.reversed)
                PopupMenuItem(
                  key: Key('priority-${p.name}'),
                  value: p,
                  child: Row(
                    children: [
                      Icon(p == Priority.none ? Icons.outlined_flag : Icons.flag, color: priorityColor(p)),
                      const SizedBox(width: 12),
                      Text(p.label),
                    ],
                  ),
                ),
            ],
            child: Chip(
              avatar: Icon(
                priority == Priority.none ? Icons.outlined_flag : Icons.flag,
                color: priorityColor(priority),
                size: 18,
              ),
              label: Text(priority == Priority.none ? 'Priority' : priority.label),
            ),
          ),
          for (final tag in tags)
            InputChip(
              key: Key('tag-$tag'),
              label: Text('#$tag'),
              deleteButtonTooltipMessage: 'Remove tag',
              onDeleted: () => _removeTag(tag),
            ),
          SizedBox(
            width: 160,
            child: RawAutocomplete<String>(
              textEditingController: _tagField,
              focusNode: _tagFocus,
              optionsBuilder: (value) {
                final typed = value.text.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase();
                if (typed.isEmpty) return const [];
                return known.where((n) => indexOfTag(tags, n) < 0 && n.toLowerCase().contains(typed));
              },
              onSelected: _addTag,
              fieldViewBuilder: (context, controller, focusNode, _) => TextField(
                key: const Key('addTagField'),
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Add a tag', isDense: true, border: InputBorder.none),
                // Enter adds what was typed, as typed: picking an offered tag is a tap, so a new tag that starts like
                // an old one can still be made.
                onSubmitted: (text) {
                  _addTag(text);
                  focusNode.requestFocus();
                },
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: AlignmentDirectional.topStart,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240, maxWidth: 240),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final name in options)
                          ListTile(
                            key: Key('tagOption-$name'),
                            dense: true,
                            title: Text('#$name'),
                            onTap: () => onSelected(name),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
