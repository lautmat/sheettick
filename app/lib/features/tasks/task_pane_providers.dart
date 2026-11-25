import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import 'task_detail_screen.dart';

/// Windows at least this wide show an opened task beside the list, as TickTick does; narrower ones open it as a page.
const kSplitBreakpoint = 1000.0;

/// The width of the task pane beside the list.
const kTaskPaneWidth = 420.0;

/// The task open in the pane beside the list, or null when none is.
class SelectedTaskId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedTaskIdProvider = NotifierProvider<SelectedTaskId, String?>(SelectedTaskId.new);

/// Whether the lists sidebar is folded away on a wide window. Kept for the session only.
class SidebarCollapsed extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsed, bool>(SidebarCollapsed.new);

/// How the open pane saves its pending title and notes edits, so a switch to another task loses nothing.
class TaskPaneFlush {
  Future<void> Function()? run;
}

final taskPaneFlushProvider = Provider<TaskPaneFlush>((ref) => TaskPaneFlush());

/// Opens [task]: beside the list when the window is wide enough, else as a page on top of it.
Future<void> openTask(BuildContext context, WidgetRef ref, Task task) async {
  if (MediaQuery.sizeOf(context).width >= kSplitBreakpoint) {
    if (ref.read(selectedTaskIdProvider) != task.id) await ref.read(taskPaneFlushProvider).run?.call();
    ref.read(selectedTaskIdProvider.notifier).select(task.id);
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(task: task)));
}
