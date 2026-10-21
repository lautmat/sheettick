import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/tasks/checklist.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21, 9, 30, 15);

  test('ticking an item sets status 2 and stamps completed_at in the Sheet format', () {
    expect(checklistItemFields(done: true, now: now), {'status': 2, 'completed_at': '2026-10-21T09:30:15Z'});
  });

  test('unticking an item sets status 0 and clears completed_at', () {
    expect(checklistItemFields(done: false, now: now), {'status': 0, 'completed_at': null});
  });

  group('checklistOrderAfterMove', () {
    test('the first item dropped at the end goes last', () {
      expect(checklistOrderAfterMove(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    });

    test('the last item dropped at the top goes first', () {
      expect(checklistOrderAfterMove(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });

    test('an item moved down one place swaps with the next', () {
      expect(checklistOrderAfterMove(['a', 'b', 'c'], 0, 1), ['b', 'a', 'c']);
    });

    test('an item dropped where it already is changes nothing', () {
      expect(checklistOrderAfterMove(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
    });
  });
}
