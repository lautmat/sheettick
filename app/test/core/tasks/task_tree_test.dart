import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/tasks/task_tree.dart';

typedef _Node = ({String id, String? parent});

/// The order as "id:depth" strings, so a failure reads at a glance.
List<String> _order(List<_Node> nodes) {
  final rows = arrangeTree(nodes, idOf: (n) => n.id, parentOf: (n) => n.parent);
  return [for (final r in rows) '${r.item.id}:${r.depth}'];
}

void main() {
  test('each top-level task is followed by its subtasks, and siblings keep their order', () {
    expect(_order([(id: 'a', parent: null), (id: 'b', parent: 'a'), (id: 'c', parent: null), (id: 'd', parent: 'a')]), [
      'a:0',
      'b:1',
      'd:1',
      'c:0',
    ]);
  });

  test('a subtask of a subtask is one level deeper again', () {
    expect(_order([(id: 'a', parent: null), (id: 'b', parent: 'a'), (id: 'e', parent: 'b')]), ['a:0', 'b:1', 'e:2']);
  });

  test('a task whose parent is not in the list is shown at the top level, so it does not disappear', () {
    expect(_order([(id: 'x', parent: 'deleted-or-elsewhere'), (id: 'y', parent: null)]), ['x:0', 'y:0']);
  });

  test('a task that is its own parent is shown at the top level', () {
    expect(_order([(id: 'self', parent: 'self')]), ['self:0']);
  });

  test('a cycle of parents shows each task once and does not loop', () {
    expect(_order([(id: 'p', parent: 'q'), (id: 'q', parent: 'p')]), ['p:0', 'q:1']);
  });
}
