import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/task_bulk.dart';
import '../../core/tasks/task_completion.dart';
import '../../core/tasks/task_postpone.dart';
import '../../core/tasks/task_skip.dart';
import '../../core/tasks/task_status.dart';
import '../common/local_edit.dart';
import '../common/undo.dart';
import 'checklist_section.dart';
import 'notes_field.dart';
import 'postpone_action.dart';
import 'skip_action.dart';
import 'task_attributes.dart';
import 'task_pane_providers.dart';
import 'task_providers.dart';

/// One task on its own page: its title and Markdown notes, its priority and tags, its status, and Delete.
///
/// Title and notes are saved when the page closes and before a status change, not on every keystroke; priority and
/// tags are saved as they change. A field the user did
/// not change is never written, so a change that came from the Sheet while the page was open is not overwritten.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.task, this.embedded = false});

  /// The task as the page opened. Its title and notes are the first saved baseline.
  final Task task;

  /// True when shown in the pane beside the list: closing clears the selection instead of popping a route.
  final bool embedded;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _notes = TextEditingController(text: widget.task.content);

  // What is stored as of the last save: an edit is a difference from these.
  late var _savedTitle = widget.task.title;
  late var _savedNotes = widget.task.content;

  String get _id => widget.task.id;

  late final Future<void> Function() _flushHook = _saveEdits;
  TaskPaneFlush? _flush;

  @override
  void initState() {
    super.initState();
    if (widget.embedded) {
      final flush = ref.read(taskPaneFlushProvider);
      flush.run = _flushHook;
      _flush = flush;
    }
  }

  @override
  void dispose() {
    // The pane that replaces this one has registered itself by now; only clear our own hook.
    if (_flush != null && identical(_flush!.run, _flushHook)) _flush!.run = null;
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Writes the fields the user changed. A blank title is not saved, so the last real title stays.
  Future<void> _saveEdits() async {
    // Nothing is written until the row has loaded, and never to a task that sync has deleted.
    final taskAsync = ref.read(taskProvider(_id));
    if (taskAsync.isLoading || (taskAsync.value?.deleted ?? false)) return;
    final title = _title.text.trim();
    final notes = _notes.text;
    final changes = <String, Object?>{
      if (title.isNotEmpty && title != _savedTitle) 'title': title,
      if (notes != _savedNotes) 'content': notes,
    };
    if (changes.isEmpty) return;
    await updateRow(ref, 'tasks', _id, changes, undo: 'Task edited');
    _savedTitle = title.isEmpty ? _savedTitle : title;
    _savedNotes = notes;
  }

  /// Saves the edits, then leaves the page. Pass [save] false to drop them, as after a delete.
  Future<void> _close({bool save = true}) async {
    if (save) await _saveEdits();
    if (!mounted) return;
    if (widget.embedded) {
      ref.read(selectedTaskIdProvider.notifier).select(null);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Saves the edits first, so none are lost, then sets the status. The page stays open to show the change.
  Future<void> _setStatus(TaskStatus status) async {
    await _saveEdits();
    final task = ref.read(taskProvider(_id)).value ?? widget.task;
    final zone = await ref.read(deviceZoneProvider.future);
    // Finishing a repeating task also creates its next round, which undoing tombstones again.
    await changeWithUndo<String?>(
      ref,
      switch (status) {
        TaskStatus.completed => 'Task completed',
        TaskStatus.wontDo => "Marked Won't Do",
        TaskStatus.open => 'Task reopened',
      },
      [(tab: 'tasks', id: task.id)],
      (writer) => setTaskStatus(writer, task, status, now: DateTime.now(), zone: zone),
      created: (next) => [if (next != null) (tab: 'tasks', id: next)],
    );
  }

  /// Saves the edits first, then moves a repeating task to its next occurrence.
  Future<void> _skip() async {
    await _saveEdits();
    final task = ref.read(taskProvider(_id)).value ?? widget.task;
    if (!mounted) return;
    await skipTaskOccurrence(context, ref, task);
  }

  /// Saves the edits first, then postpones the task.
  Future<void> _postpone(PostponeTarget target) async {
    await _saveEdits();
    final task = ref.read(taskProvider(_id)).value ?? widget.task;
    await postponeWithUndo(ref, [task], target);
  }

  /// Moves the task to the Trash, and its subtasks with it: left behind they would show up as tasks of their own.
  Future<void> _delete() async {
    final writer = await ref.read(localWriterProvider.future);
    final ids = await withSubtasks(writer, [_id]);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ids.length > 1 ? 'Move this task and its subtasks to Trash?' : 'Move this task to Trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Move to Trash')),
        ],
      ),
    );
    if (confirmed != true) return;
    await changeWithUndo<int>(
      ref,
      'Task moved to Trash',
      [for (final id in ids) (tab: 'tasks', id: id)],
      (writer) => trashTasks(writer, [_id]),
    );
    await _close(save: false);
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(taskProvider(_id)).value ?? widget.task;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final done = task.status == TaskStatus.completed.value;
    final wontDo = task.status == TaskStatus.wontDo.value;

    return PopScope(
      canPop: widget.embedded,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _close();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          actions: [
            if (widget.embedded)
              IconButton(
                key: const Key('taskPaneClose'),
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: _close,
              ),
            IconButton(
              key: const Key('taskCompleteToggle'),
              tooltip: done ? 'Reopen' : 'Complete',
              icon: Icon(done ? Icons.check_circle : Icons.check_circle_outline),
              onPressed: () => _setStatus(done ? TaskStatus.open : TaskStatus.completed),
            ),
            PopupMenuButton<String>(
              key: const Key('taskMenu'),
              tooltip: 'Task options',
              onSelected: (value) => switch (value) {
                'wontDo' => _setStatus(TaskStatus.wontDo),
                'reopen' => _setStatus(TaskStatus.open),
                'skip' => _skip(),
                _ when postponeTargetOf(value) != null => _postpone(postponeTargetOf(value)!),
                _ => _delete(),
              },
              itemBuilder: (_) => [
                if (canSkipOccurrence(task)) const PopupMenuItem(value: 'skip', child: Text('Skip this occurrence')),
                if (wontDo)
                  const PopupMenuItem(value: 'reopen', child: Text('Reopen'))
                else
                  const PopupMenuItem(value: 'wontDo', child: Text("Won't do")),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ...postponeMenuEntries(task, now: DateTime.now(), zone: ref.watch(deviceZoneProvider).value),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('taskTitleField'),
              controller: _title,
              maxLines: 1,
              style: theme.textTheme.titleLarge,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
            ),
            if (done || wontDo)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(done ? 'Completed' : "Won't do", style: TextStyle(color: muted)),
              ),
            TaskAttributes(task: task),
            ChecklistSection(task: task),
            const Divider(height: 32),
            TaskNotesField(controller: _notes),
          ],
        ),
      ),
    );
  }
}
