import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/tasks/recurrence.dart';
import 'package:sheettick/core/tasks/repeat_spec.dart';
import 'package:sheettick/core/tasks/task_dates.dart';

void main() {
  hashTests();
  final monday = DateTime.utc(2026, 11, 16, 9);

  group('format', () {
    test('every N days, weeks, months, years', () {
      expect(RepeatSpec(unit: RepeatUnit.day, interval: 6).format(monday), 'RRULE:FREQ=DAILY;INTERVAL=6');
      expect(RepeatSpec(unit: RepeatUnit.year).format(monday), 'RRULE:FREQ=YEARLY');
      expect(RepeatSpec(unit: RepeatUnit.month, interval: 3, monthDay: 27).format(monday), 'RRULE:FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=27');
    });

    test('an open weekday or month day comes from the task date', () {
      expect(RepeatSpec(unit: RepeatUnit.week).format(monday), 'RRULE:FREQ=WEEKLY;BYDAY=MO');
      expect(RepeatSpec(unit: RepeatUnit.month).format(monday), 'RRULE:FREQ=MONTHLY;BYMONTHDAY=16');
    });

    test('weekdays are sorted and the last day of the month is -1', () {
      expect(RepeatSpec(unit: RepeatUnit.week, weekdays: {5, 1, 3}).format(monday), 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR');
      expect(RepeatSpec(unit: RepeatUnit.month, monthDay: -1).format(monday), 'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1');
    });

    test('ends', () {
      expect(RepeatSpec(unit: RepeatUnit.day, end: RepeatCount(10)).format(monday), 'RRULE:FREQ=DAILY;COUNT=10');
      expect(RepeatSpec(unit: RepeatUnit.day, end: RepeatUntil(DateTime(2027, 3, 5))).format(monday), 'RRULE:FREQ=DAILY;UNTIL=20270305T235959Z');
    });
  });

  group('parse', () {
    test('round trips what the editor writes', () {
      final specs = [
        RepeatSpec(unit: RepeatUnit.day, interval: 6),
        RepeatSpec(unit: RepeatUnit.week, interval: 2, weekdays: {1, 4}, end: RepeatCount(8)),
        RepeatSpec(unit: RepeatUnit.month, interval: 3, monthDay: 27, end: RepeatUntil(DateTime(2028, 1, 31))),
        RepeatSpec(unit: RepeatUnit.month, monthDay: -1),
        RepeatSpec(unit: RepeatUnit.year),
      ];
      for (final s in specs) {
        expect(RepeatSpec.parse(s.format(monday)), s, reason: s.format(monday));
      }
    });

    test('reads rules from the Sheet or TickTick: no label, lower case, WKST=MO, date-only UNTIL', () {
      expect(RepeatSpec.parse('freq=daily;interval=2'), RepeatSpec(unit: RepeatUnit.day, interval: 2));
      expect(RepeatSpec.parse('RRULE:FREQ=WEEKLY;WKST=MO;INTERVAL=1;BYDAY=FR'), RepeatSpec(unit: RepeatUnit.week, weekdays: {5}));
      expect(RepeatSpec.parse('FREQ=DAILY;UNTIL=20270305'), RepeatSpec(unit: RepeatUnit.day, end: RepeatUntil(DateTime(2027, 3, 5))));
    });

    test('the rules in the TickTick import all open in the editor', () {
      for (final r in [
        'RRULE:FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=27',
        'RRULE:FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=1',
        'RRULE:FREQ=MONTHLY;BYMONTHDAY=3',
        'RRULE:FREQ=DAILY;INTERVAL=2',
        'RRULE:FREQ=WEEKLY;WKST=MO;INTERVAL=1;BYDAY=FR',
      ]) {
        expect(RepeatSpec.parse(r), isNotNull, reason: r);
      }
    });

    test('rules the editor cannot show exactly are not parsed', () {
      for (final r in [
        'FREQ=MONTHLY;INTERVAL=3;BYDAY=2TU',
        'FREQ=MONTHLY;BYSETPOS=-1;BYDAY=MO,TU,WE,TH,FR',
        'FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=5',
        'FREQ=MONTHLY;BYMONTHDAY=1,15',
        'FREQ=WEEKLY;WKST=SU',
        'FREQ=DAILY;BYDAY=MO',
        'FREQ=DAILY;COUNT=3;UNTIL=20270101',
        'FREQ=HOURLY',
        'FREQ=DAILY;INTERVAL=0',
        'FREQ=DAILY;INTERVAL=x',
        'FREQ=MONTHLY;BYMONTHDAY=0',
        'FREQ=DAILY;UNTIL=20271340',
        'nonsense',
        '',
      ]) {
        expect(RepeatSpec.parse(r), isNull, reason: r);
      }
      expect(RepeatSpec.parse(null), isNull);
    });
  });

  group('describeRepeat', () {
    test('words', () {
      expect(describeRepeat('RRULE:FREQ=DAILY'), 'Every day');
      expect(describeRepeat('FREQ=DAILY;INTERVAL=6'), 'Every 6 days');
      expect(describeRepeat('FREQ=WEEKLY;BYDAY=MO,TH'), 'Every week on Monday and Thursday');
      expect(describeRepeat('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR'), 'Every 2 weeks on Monday, Wednesday and Friday');
      expect(describeRepeat('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'), 'Every week on weekdays');
      expect(describeRepeat('FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=27'), 'Every 3 months on day 27');
      expect(describeRepeat('FREQ=MONTHLY;BYMONTHDAY=-1'), 'Every month on the last day');
      expect(describeRepeat('FREQ=YEARLY'), 'Every year');
      expect(describeRepeat('FREQ=DAILY;COUNT=10'), 'Every day, 10 times');
      expect(describeRepeat('FREQ=DAILY;COUNT=1'), 'Every day, once');
      expect(describeRepeat('FREQ=DAILY;UNTIL=20270305T235959Z'), 'Every day, until 5 March 2027');
    });

    test('rules the editor cannot show are still put into words', () {
      expect(describeRepeat('FREQ=MONTHLY;INTERVAL=3;BYDAY=2TU'), 'Every 3 months on 2nd Tuesday');
      expect(describeRepeat('FREQ=MONTHLY;BYDAY=-1FR'), 'Every month on last Friday');
      expect(describeRepeat('FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=5'), 'Every year on day 5 in March');
      expect(describeRepeat('FREQ=MONTHLY;BYMONTHDAY=1,15'), 'Every month on day 1 and 15');
    });

    test('nothing to say about text that is not a rule', () {
      expect(describeRepeat('nonsense'), isNull);
      expect(describeRepeat(''), isNull);
      expect(describeRepeat(null), isNull);
      expect(describeRepeat('FREQ=HOURLY'), isNull);
    });
  });

  test('what the editor writes is a rule the recurrence code understands', () {
    for (final s in [
      RepeatSpec(unit: RepeatUnit.month, interval: 3, monthDay: 27, end: RepeatUntil(DateTime(2028, 1, 31))),
      RepeatSpec(unit: RepeatUnit.week, weekdays: {1, 4}, end: RepeatCount(3)),
    ]) {
      expect(parseRrule(s.format(monday)), isNotNull);
    }
  });

  group('in the recurrence engine', () {
    NextOccurrence? next(String rrule, TaskDates dates, DateTime done) =>
        nextOccurrence(rrule: rrule, repeatFrom: RepeatFrom.due, dates: dates, completedWall: done);

    test('the last day of the month', () {
      final rule = RepeatSpec(unit: RepeatUnit.month, monthDay: -1).format(monday);
      final n = next(rule, TaskDates(due: DateTime.utc(2027, 1, 31), allDay: true), DateTime.utc(2027, 1, 31));
      expect(n!.dates.due, DateTime.utc(2027, 2, 28));
    });

    test('UNTIL includes its last day for a timed task and for an all-day task', () {
      final rule = RepeatSpec(unit: RepeatUnit.day, end: RepeatUntil(DateTime(2027, 3, 5))).format(monday);
      final timed = next(rule, TaskDates(due: DateTime.utc(2027, 3, 4, 9, 30)), DateTime.utc(2027, 3, 4, 9, 30));
      expect(timed!.dates.due, DateTime.utc(2027, 3, 5, 9, 30));
      expect(next(rule, TaskDates(due: DateTime.utc(2027, 3, 5, 9, 30)), DateTime.utc(2027, 3, 5, 9, 30)), isNull);
      final allDay = next(rule, TaskDates(due: DateTime.utc(2027, 3, 4), allDay: true), DateTime.utc(2027, 3, 4));
      expect(allDay!.dates.due, DateTime.utc(2027, 3, 5));
      expect(next(rule, TaskDates(due: DateTime.utc(2027, 3, 5), allDay: true), DateTime.utc(2027, 3, 5)), isNull);
    });

    test('every 3 months on the 27th, and COUNT counts down', () {
      final rule = RepeatSpec(unit: RepeatUnit.month, interval: 3, monthDay: 27, end: RepeatCount(3)).format(monday);
      final n = next(rule, TaskDates(due: DateTime.utc(2027, 2, 27), allDay: true), DateTime.utc(2027, 2, 27));
      expect(n!.dates.due, DateTime.utc(2027, 5, 27));
      expect(n.rrule, contains('COUNT=2'));
    });
  });
}

void hashTests() {
  test('specs with the same weekdays hash alike, and different ones differ', () {
    final a = RepeatSpec(unit: RepeatUnit.week, weekdays: {1, 3});
    final b = RepeatSpec(unit: RepeatUnit.week, weekdays: {3, 1});
    final c = RepeatSpec(unit: RepeatUnit.week, weekdays: {2, 4});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect({a, b, c}, hasLength(2));
  });
  test('long dates are unambiguous', () => expect(longRepeatDate(DateTime.utc(2027, 3, 5)), '5 March 2027'));
}
