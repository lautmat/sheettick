import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/tasks/recurrence.dart';
import 'package:sheettick/core/tasks/task_dates.dart';

DateTime w(int y, int m, int d, [int h = 0, int mi = 0]) => DateTime.utc(y, m, d, h, mi);

/// An all-day task due on [due].
TaskDates dayTask(DateTime due) => TaskDates(due: due, allDay: true);

NextOccurrence? next(
  String? rrule,
  TaskDates dates, {
  required DateTime completed,
  RepeatFrom from = RepeatFrom.due,
  String? exDates,
}) => nextOccurrence(rrule: rrule, repeatFrom: from, exDates: exDates, dates: dates, completedWall: completed);

void main() {
  group('repeat from the due date', () {
    test('daily: the next day', () {
      final n = next('RRULE:FREQ=DAILY', dayTask(w(2026, 11, 7)), completed: w(2026, 11, 7, 15))!;
      expect(n.dates.due, w(2026, 11, 8));
      expect(n.dates.allDay, isTrue);
      expect(n.rrule, 'RRULE:FREQ=DAILY');
    });

    test('daily, finished late: the next one is not already in the past', () {
      final n = next('RRULE:FREQ=DAILY', dayTask(w(2026, 11, 7)), completed: w(2026, 11, 10, 8))!;
      expect(n.dates.due, w(2026, 11, 11));
    });

    test('daily, finished early: the day after its own date, not after today', () {
      final n = next('RRULE:FREQ=DAILY', dayTask(w(2026, 11, 7)), completed: w(2026, 11, 5, 8))!;
      expect(n.dates.due, w(2026, 11, 8));
    });

    test('weekly on Monday and Thursday: the next of those days', () {
      const rule = 'RRULE:FREQ=WEEKLY;BYDAY=MO,TH';
      // Mon 9th finished on the day -> Thu 12th, then Mon 16th.
      var n = next(rule, dayTask(w(2026, 11, 9)), completed: w(2026, 11, 9, 9))!;
      expect(n.dates.due, w(2026, 11, 12));
      n = next(rule, dayTask(w(2026, 11, 12)), completed: w(2026, 11, 12, 9))!;
      expect(n.dates.due, w(2026, 11, 16));
    });

    test('weekly, finished late on a Tuesday: the following Monday or Thursday', () {
      final n = next('RRULE:FREQ=WEEKLY;BYDAY=MO,TH', dayTask(w(2026, 11, 9)), completed: w(2026, 11, 10, 9))!;
      expect(n.dates.due, w(2026, 11, 12));
    });

    test('every 2 weeks keeps its rhythm even when finished a few days late', () {
      const rule = 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO';
      final n = next(rule, dayTask(w(2026, 11, 9)), completed: w(2026, 11, 12, 9))!;
      expect(n.dates.due, w(2026, 11, 23));
    });

    test('monthly on the 15th', () {
      final n = next('RRULE:FREQ=MONTHLY;BYMONTHDAY=15', dayTask(w(2026, 11, 15)), completed: w(2026, 11, 15, 9))!;
      expect(n.dates.due, w(2026, 12, 15));
    });

    test('yearly', () {
      final n = next('RRULE:FREQ=YEARLY', dayTask(w(2026, 11, 15)), completed: w(2026, 11, 15, 9))!;
      expect(n.dates.due, w(2027, 11, 15));
    });

    test('a timed task keeps its time of day, and its start keeps its distance from the due', () {
      final dates = TaskDates(start: w(2026, 11, 7, 8), due: w(2026, 11, 7, 9, 30), zone: 'Europe/Paris');
      final n = next('RRULE:FREQ=DAILY', dates, completed: w(2026, 11, 7, 9, 45))!;
      expect(n.dates.due, w(2026, 11, 8, 9, 30));
      expect(n.dates.start, w(2026, 11, 8, 8));
      expect(n.dates.allDay, isFalse);
      expect(n.dates.zone, 'Europe/Paris');
    });

    test('a task with only a start repeats from the start', () {
      final n = next('RRULE:FREQ=DAILY', TaskDates(start: w(2026, 11, 7), allDay: true), completed: w(2026, 11, 7, 9))!;
      expect(n.dates.start, w(2026, 11, 8));
      expect(n.dates.due, isNull);
    });

    test('the rule can be written without the RRULE: label, in any case', () {
      final n = next('freq=daily;interval=2', dayTask(w(2026, 11, 7)), completed: w(2026, 11, 7, 9))!;
      expect(n.dates.due, w(2026, 11, 9));
    });
  });

  group('repeat from completion', () {
    test('every 3 days counts from the day it was finished', () {
      final n = next(
        'RRULE:FREQ=DAILY;INTERVAL=3',
        dayTask(w(2026, 11, 7)),
        completed: w(2026, 11, 10, 8),
        from: RepeatFrom.completion,
      )!;
      expect(n.dates.due, w(2026, 11, 13));
    });

    test('weekly on Monday, finished on a Wednesday: the next Monday', () {
      final n = next(
        'RRULE:FREQ=WEEKLY;BYDAY=MO',
        dayTask(w(2026, 11, 9)),
        completed: w(2026, 11, 11, 8),
        from: RepeatFrom.completion,
      )!;
      expect(n.dates.due, w(2026, 11, 16));
    });

    test('a timed task keeps its time of day on the new day', () {
      final dates = TaskDates(due: w(2026, 11, 7, 9), zone: 'Europe/Paris');
      final n = next('RRULE:FREQ=DAILY;INTERVAL=2', dates, completed: w(2026, 11, 10, 15), from: RepeatFrom.completion)!;
      expect(n.dates.due, w(2026, 11, 12, 9));
    });

    test('repeat_from reads DUE, COMPLETION, and anything else as DUE', () {
      expect(RepeatFrom.parse('COMPLETION'), RepeatFrom.completion);
      expect(RepeatFrom.parse(' completion '), RepeatFrom.completion);
      expect(RepeatFrom.parse('DUE'), RepeatFrom.due);
      expect(RepeatFrom.parse(null), RepeatFrom.due);
      expect(RepeatFrom.parse('later'), RepeatFrom.due);
      expect(RepeatFrom.completion.value, 'COMPLETION');
    });
  });

  group('ex_dates', () {
    test('a skipped day is passed over', () {
      final n = next(
        'RRULE:FREQ=DAILY',
        dayTask(w(2026, 11, 7)),
        completed: w(2026, 11, 7, 9),
        exDates: '["2026-11-08"]',
      )!;
      expect(n.dates.due, w(2026, 11, 9));
    });

    test('several skipped days, in date or date-time form, are all passed over', () {
      final n = next(
        'RRULE:FREQ=DAILY',
        dayTask(w(2026, 11, 7)),
        completed: w(2026, 11, 7, 9),
        exDates: '["2026-11-08","2026-11-09T09:00:00+01:00","2026-11-10"]',
      )!;
      expect(n.dates.due, w(2026, 11, 11));
    });

    test('unreadable ex_dates skip nothing', () {
      for (final text in [null, '', 'nope', '{"a":1}', '[1,2]']) {
        final n = next('RRULE:FREQ=DAILY', dayTask(w(2026, 11, 7)), completed: w(2026, 11, 7, 9), exDates: text)!;
        expect(n.dates.due, w(2026, 11, 8), reason: '$text');
      }
    });

    test('exDays reads the days of an ex_dates cell', () {
      expect(exDays('["2026-11-08","2026-11-09T09:00:00Z","x"]'), {'2026-11-08', '2026-11-09'});
    });
  });

  group('the end of a series', () {
    test('COUNT counts down: the next task has one fewer left', () {
      final n = next('RRULE:FREQ=DAILY;COUNT=3', dayTask(w(2026, 11, 7)), completed: w(2026, 11, 7, 9))!;
      expect(n.rrule, 'RRULE:FREQ=DAILY;COUNT=2');
      final last = next(n.rrule, n.dates, completed: w(2026, 11, 8, 9))!;
      expect(last.rrule, 'RRULE:FREQ=DAILY;COUNT=1');
      expect(next(last.rrule, last.dates, completed: w(2026, 11, 9, 9)), isNull);
    });

    test('UNTIL stops the series', () {
      const rule = 'RRULE:FREQ=DAILY;UNTIL=20261108T000000Z';
      expect(next(rule, dayTask(w(2026, 11, 7)), completed: w(2026, 11, 7, 9))!.dates.due, w(2026, 11, 8));
      expect(next(rule, dayTask(w(2026, 11, 8)), completed: w(2026, 11, 8, 9)), isNull);
    });

    test('no rule, an unreadable rule, or no date means no next one', () {
      expect(next(null, dayTask(w(2026, 11, 7)), completed: w(2026, 11, 7, 9)), isNull);
      expect(next('', dayTask(w(2026, 11, 7)), completed: w(2026, 11, 7, 9)), isNull);
      expect(next('RRULE:FREQ=SOMETIMES', dayTask(w(2026, 11, 7)), completed: w(2026, 11, 7, 9)), isNull);
      expect(next('not a rule', dayTask(w(2026, 11, 7)), completed: w(2026, 11, 7, 9)), isNull);
      expect(next('RRULE:FREQ=DAILY', const TaskDates(), completed: w(2026, 11, 7, 9)), isNull);
    });

    test('a rule whose every day is skipped gives up instead of looping', () {
      final days = [for (var i = 0; i < 2500; i++) '"${w(2026, 11, 8).add(Duration(days: i)).toIso8601String().substring(0, 10)}"'];
      final n = next(
        'RRULE:FREQ=DAILY',
        dayTask(w(2026, 11, 7)),
        completed: w(2026, 11, 7, 9),
        exDates: '[${days.join(',')}]',
      );
      expect(n, isNull);
    });
  });
}
