import '../db/database.dart';
import 'priority.dart';
import 'smart_lists.dart';
import 'tags.dart';
import 'task_dates.dart';

/// How a list orders its tasks, stored in `lists.order_by`. An empty or unknown value is [manual].
enum TaskOrder {
  manual('', 'Manual'),
  due('due', 'Due date'),
  priority('priority', 'Priority'),
  created('created', 'Created'),
  title('title', 'Title');

  const TaskOrder(this.value, this.label);

  /// The text stored in the column.
  final String value;
  final String label;

  static TaskOrder of(String? value) => values.firstWhere((o) => o.value == value, orElse: () => manual);
}

/// How a list groups its tasks, stored in `lists.group_by`. An empty or unknown value is [none].
enum TaskGroup {
  none('', 'None'),
  due('due', 'Due date'),
  priority('priority', 'Priority'),
  tag('tag', 'Tag'),
  list('list', 'List');

  const TaskGroup(this.value, this.label);

  /// The text stored in the column.
  final String value;
  final String label;

  static TaskGroup of(String? value) => values.firstWhere((g) => g.value == value, orElse: () => none);
}

/// [tasks] in the order [order] says. The sort is stable, and ties are left in the order given, which is the list's own
/// manual order, so each choice only reorders what it can tell apart. Open tasks always stay ahead of done ones.
///
/// - Due date: earliest first, going by the due and else the start; tasks with no date last.
/// - Priority: high first.
/// - Created: newest first.
/// - Title: A to Z, ignoring case.
List<Task> sortTasks(List<Task> tasks, TaskOrder order, {String? zone}) {
  if (order == TaskOrder.manual) return List.of(tasks);
  final dates = order == TaskOrder.due ? {for (final t in tasks) t.id: smartListDate(t, zone)} : const <String, DateTime?>{};
  int compare(Task a, Task b) {
    final byStatus = _statusRank(a.status).compareTo(_statusRank(b.status));
    if (byStatus != 0) return byStatus;
    return switch (order) {
      TaskOrder.due => _byDate(dates[a.id], dates[b.id]),
      TaskOrder.priority => Priority.of(b.priority).value.compareTo(Priority.of(a.priority).value),
      TaskOrder.created => b.createdAt.compareTo(a.createdAt),
      TaskOrder.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      TaskOrder.manual => 0,
    };
  }

  // List.sort is not stable, so the position in the input breaks ties.
  final indexed = [for (var i = 0; i < tasks.length; i++) (i: i, task: tasks[i])];
  indexed.sort((a, b) {
    final c = compare(a.task, b.task);
    return c != 0 ? c : a.i.compareTo(b.i);
  });
  return [for (final e in indexed) e.task];
}

/// Open tasks first; done and won't-do ones (`status` 2 and -1) after them.
int _statusRank(int status) => status == 0 ? 0 : 1;

int _byDate(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

/// A run of rows shown under one heading.
typedef TaskGroupRows = ({String label, List<({Task item, int depth})> rows});

/// Splits [arranged] (top-level tasks each followed by their subtasks, as `arrangeTree` returns them) into the groups
/// [group] describes. A subtask goes with its top-level task. With [TaskGroup.none] there is one group with no label.
///
/// - Due date: Overdue, Today, Tomorrow, Next 7 Days, Later, No date, in that order; only the ones with tasks.
/// - Priority: High, Medium, Low, None.
/// - Tag: one group per tag, A to Z, then No tag. A task with several tags is in each of them.
/// - List: one group per list name, A to Z. [listNames] maps a list id to its name.
List<TaskGroupRows> groupRows(
  List<({Task item, int depth})> arranged,
  TaskGroup group, {
  required DateTime now,
  String? zone,
  Map<String, String> listNames = const {},
}) {
  if (group == TaskGroup.none) return [(label: '', rows: arranged)];

  final today = TaskDates(zone: zone).wallOf(now);
  final groups = <String, ({int rank, List<({Task item, int depth})> rows})>{};
  // The groups the current top-level task belongs to; its subtasks follow it into each.
  var targets = <List<({Task item, int depth})>>[];

  List<({Task item, int depth})> bucket(String label, int rank) => (groups[label] ??= (rank: rank, rows: [])).rows;

  List<List<({Task item, int depth})>> placesOf(Task t) {
    switch (group) {
      case TaskGroup.due:
        final date = smartListDate(t, zone);
        if (date == null) return [bucket('No date', 5)];
        final days = daysBetween(today, date);
        if (days < 0) return [bucket('Overdue', 0)];
        if (days == 0) return [bucket('Today', 1)];
        if (days == 1) return [bucket('Tomorrow', 2)];
        if (days <= 7) return [bucket('Next 7 Days', 3)];
        return [bucket('Later', 4)];
      case TaskGroup.priority:
        final p = Priority.of(t.priority);
        // `Priority.values` runs none, low, medium, high; the groups run the other way.
        return [bucket(p.label, Priority.values.length - 1 - Priority.values.indexOf(p))];
      case TaskGroup.tag:
        final tags = parseTags(t.tags);
        if (tags.isEmpty) return [bucket('No tag', 1)];
        return [for (final tag in tags) bucket(tag, 0)];
      case TaskGroup.list:
        final name = listNames[t.listId];
        return [bucket(name == null || name.isEmpty ? '(untitled)' : name, 0)];
      case TaskGroup.none:
        return [bucket('', 0)];
    }
  }

  for (final row in arranged) {
    if (row.depth == 0) {
      targets = placesOf(row.item);
    }
    for (final rows in targets) {
      rows.add(row);
    }
  }
  final labels = groups.keys.toList()
    ..sort((a, b) {
      final byRank = groups[a]!.rank.compareTo(groups[b]!.rank);
      return byRank != 0 ? byRank : a.toLowerCase().compareTo(b.toLowerCase());
    });
  return [for (final l in labels) (label: l, rows: groups[l]!.rows)];
}
