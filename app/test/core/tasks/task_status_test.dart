import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/tasks/task_status.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21, 9, 30, 15, 500);

  test('completing sets status 2 and stamps completed_at in the Sheet format', () {
    expect(statusFields(TaskStatus.completed, now), {'status': 2, 'completed_at': '2026-10-21T09:30:15Z'});
  });

  test('completing stamps the same instant whatever the local time zone', () {
    final local = DateTime.parse('2026-10-21T11:30:15+02:00');
    expect(statusFields(TaskStatus.completed, local)['completed_at'], '2026-10-21T09:30:15Z');
  });

  test('reopening sets status 0 and clears completed_at', () {
    expect(statusFields(TaskStatus.open, now), {'status': 0, 'completed_at': null});
  });

  test("won't do sets status -1 and clears completed_at: it was never completed", () {
    expect(statusFields(TaskStatus.wontDo, now), {'status': -1, 'completed_at': null});
  });
}
