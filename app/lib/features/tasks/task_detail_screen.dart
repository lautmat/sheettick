import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/tasks/task_status.dart';
import '../common/local_edit.dart';
import 'task_providers.dart';

/// One task on its own page: its title and Markdown notes, its status, and Delete.
///
/// Edits are saved when the page closes and before a status change, not on every keystroke. A field the user did
/// not change is never written, so a change that came from the Sheet while the page was open is not overwritten.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.task});

  /// The task as the page opened. Its title and notes are the first saved baseline.
  final Task task;

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

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Writes the fields the user changed. A blank title is not saved, so the last real title stays.
  Future<void> _saveEdits() async {
    // A task deleted elsewhere (by sync) stays deleted: nothing is written back to it.
    if (ref.read(taskProvider(_id)).value?.deleted ?? false) return;
    final title = _title.text.trim();
    final notes = _notes.text;
    final changes = <String, Object?>{
      if (title.isNotEmpty && title != _savedTitle) 'title': title,
      if (notes != _savedNotes) 'content': notes,
    };
    if (changes.isEmpty) return;
    await updateRow(ref, 'tasks', _id, changes);
    _savedTitle = title.isEmpty ? _savedTitle : title;
    _savedNotes = notes;
  }

  /// Saves the edits, then leaves the page. Pass [save] false to drop them, as after a delete.
  Future<void> _close({bool save = true}) async {
    if (save) await _saveEdits();
    if (mounted) Navigator.of(context).pop();
  }

  /// Saves the edits first, so none are lost, then sets the status. The page stays open to show the change.
  Future<void> _setStatus(TaskStatus status) async {
    await _saveEdits();
    await updateRow(ref, 'tasks', _id, statusFields(status, DateTime.now()));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move this task to Trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Move to Trash')),
        ],
      ),
    );
    if (confirmed != true) return;
    final writer = await ref.read(localWriterProvider.future);
    await writer.delete('tasks', _id);
    ref.read(syncControllerProvider.notifier).requestSoon();
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
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
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
                _ => _delete(),
              },
              itemBuilder: (_) => [
                if (wontDo)
                  const PopupMenuItem(value: 'reopen', child: Text('Reopen'))
                else
                  const PopupMenuItem(value: 'wontDo', child: Text("Won't do")),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
            const Divider(height: 32),
            TextField(
              key: const Key('taskNotesField'),
              controller: _notes,
              minLines: 6,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Notes (Markdown)',
                border: InputBorder.none,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
