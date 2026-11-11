import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/tasks/task_reorder.dart';

void main() {
  Placed p(String id, double order) => (id: id, order: order);

  group('placeBefore', () {
    final shown = [p('a', 1), p('b', 2), p('c', 3)];

    test('between two neighbours the task gets a number between theirs, and nothing else is written', () {
      expect(placeBefore(shown, p('c', 3), 'b'), {'c': 1.5});
      expect(placeBefore(shown, p('a', 1), 'c'), {'a': 2.5});
    });

    test('at the start it goes below the first, at the end above the last', () {
      expect(placeBefore(shown, p('c', 3), 'a'), {'c': 0});
      expect(placeBefore(shown, p('a', 1), null), {'a': 4});
    });

    test('dropped where it already is, nothing changes', () {
      expect(placeBefore(shown, p('b', 2), 'c'), isEmpty);
      expect(placeBefore(shown, p('c', 3), null), isEmpty);
      expect(placeBefore(shown, p('a', 1), 'b'), isEmpty);
    });

    test('into a place it is not in yet', () {
      expect(placeBefore(shown, p('x', 0), 'b'), {'x': 1.5});
      expect(placeBefore(const [], p('x', 0), null), {'x': 1});
    });

    test('an unknown id means the end', () {
      expect(placeBefore(shown, p('a', 1), 'gone'), {'a': 4});
    });

    test('tasks that share a number are renumbered, and only those that changed are written', () {
      // New tasks are written with sort_order 0, so a fresh list is all ties.
      final ties = [p('a', 0), p('b', 0), p('c', 0), p('d', 0)];
      expect(placeBefore(ties, p('d', 0), 'b'), {'a': 1, 'd': 2, 'b': 3, 'c': 4});
      // Already numbered right after the move: only the others shift.
      final mixed = [p('a', 1), p('b', 1), p('c', 5)];
      expect(placeBefore(mixed, p('c', 5), 'b'), {'b': 3, 'c': 2});
    });

    test('numbers that are too close for another to fit between them are renumbered', () {
      final close = [p('a', 1), p('b', 1.0000000000000002), p('c', 3)];
      expect(placeBefore(close, p('c', 3), 'b'), {'c': 2, 'b': 3});
    });

    test('neighbours shown out of order (a done task last, with a lower number) are renumbered into the order shown', () {
      final out = [p('open', 5), p('done', 1)];
      expect(placeBefore(out, p('x', 0), 'done'), {'open': 1, 'x': 2, 'done': 3});
    });
  });
}
