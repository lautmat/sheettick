import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/tasks/task_badges.dart';
import '../reminders/reminders_providers.dart';

/// The checklist progress of every task that has items, kept up to date as items change. One query for the whole list,
/// not one for each row.
final checklistProgressProvider = StreamProvider<Map<String, ChecklistProgress>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.checklist)..where((c) => c.deleted.equals(false));
  return query.watch().map(checklistProgress);
});

/// The number of subtasks of every task that has any.
final subtaskCountsProvider = Provider<Map<String, int>>(
  (ref) => subtaskCounts(ref.watch(allTasksProvider).value ?? const []),
);

/// What a task row says under its title, on one line: the date, then the checklist progress, the number of subtasks,
/// marks for a reminder, a repeat and a note, the list (in a smart list) and the tags.
///
/// It is one paragraph, cut short where the line ends, so the tags are the first to go and the date the last, and a
/// row never grows past two lines or overflows however much a task has.
class TaskRowDetails extends StatelessWidget {
  const TaskRowDetails({
    super.key,
    required this.taskId,
    this.date,
    this.dateColor,
    this.checklist,
    this.subtasks = 0,
    this.reminder = false,
    this.repeats = false,
    this.note = false,
    this.listName,
    this.tags = const [],
  });

  final String taskId;

  /// What the row says about the task's dates, or null for an undated task.
  final String? date;

  /// The colour of [date] when it is not the muted one of the rest: red for an overdue task.
  final Color? dateColor;

  final ChecklistProgress? checklist;
  final int subtasks;
  final bool reminder;
  final bool repeats;
  final bool note;
  final String? listName;
  final List<String> tags;

  /// Whether there is nothing to say, so the row should have no second line.
  bool get isEmpty => date == null && !_hasRest;

  bool get _hasRest =>
      checklist != null || subtasks > 0 || reminder || repeats || note || listName != null || tags.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    WidgetSpan mark(IconData icon, String label) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(icon, size: 14, color: muted, semanticLabel: label),
    );
    final parts = <List<InlineSpan>>[
      if (checklist case final c?) [mark(Icons.checklist, 'Checklist'), TextSpan(text: ' ${c.done}/${c.total}')],
      if (subtasks > 0) [mark(Icons.account_tree_outlined, 'Subtasks'), TextSpan(text: ' $subtasks')],
      if (reminder) [mark(Icons.alarm, 'Has a reminder')],
      if (repeats) [mark(Icons.repeat, 'Repeats')],
      if (note) [mark(Icons.notes, 'Has a note')],
      if (listName != null) [TextSpan(text: listName)],
      if (tags.isNotEmpty) [TextSpan(text: tags.map((t) => '#$t').join('  '))],
    ];
    if (date case final text?) {
      // A widget of its own for its colour, inside the paragraph so that a date wider than the row (large text on a
      // narrow phone) is cut short too instead of overflowing.
      parts.insert(0, [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Text(
            text,
            key: Key('taskDue-$taskId'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: dateColor ?? muted),
          ),
        ),
      ]);
    }
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++) ...[if (i > 0) const TextSpan(text: '   '), ...parts[i]],
        ],
      ),
      key: Key('taskDetails-$taskId'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: muted),
    );
  }
}
