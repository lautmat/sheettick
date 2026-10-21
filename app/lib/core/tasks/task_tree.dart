/// Puts a list's tasks in the order the list shows them: each top-level task, then its subtasks, depth first.
///
/// [items] keeps the order it was given, which is the list's own order, so siblings keep their place. A task whose
/// parent is not among [items] (deleted, won't do, or in another list) is shown at the top level, so nothing
/// disappears. A cycle of parents, which only a conflicting edit on two devices can make, is broken at its first task.
List<({T item, int depth})> arrangeTree<T>(
  List<T> items, {
  required String Function(T) idOf,
  required String? Function(T) parentOf,
}) {
  final ids = {for (final item in items) idOf(item)};
  final children = <String, List<T>>{};
  final roots = <T>[];
  for (final item in items) {
    final parent = parentOf(item);
    if (parent != null && parent != idOf(item) && ids.contains(parent)) {
      (children[parent] ??= []).add(item);
    } else {
      roots.add(item);
    }
  }

  final arranged = <({T item, int depth})>[];
  final placed = <String>{};
  void place(T item, int depth) {
    if (!placed.add(idOf(item))) return;
    arranged.add((item: item, depth: depth));
    for (final child in children[idOf(item)] ?? <T>[]) {
      place(child, depth + 1);
    }
  }

  for (final root in roots) {
    place(root, 0);
  }
  // Whatever is still unplaced is in a cycle: show it at the top level.
  for (final item in items) {
    place(item, 0);
  }
  return arranged;
}
