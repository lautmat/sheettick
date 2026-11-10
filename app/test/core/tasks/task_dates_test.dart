import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/tasks/task_dates.dart';

/// A wall-clock reading, as the model holds one.
DateTime w(int y, int mo, int d, [int h = 0, int mi = 0]) => DateTime.utc(y, mo, d, h, mi);

void main() {
  group('writing', () {
    test('all-day dates are YYYY-MM-DD with all_day set and no zone', () {
      final dates = TaskDates(start: w(2026, 11, 7), due: w(2026, 11, 9), allDay: true, zone: 'Europe/Paris');
      expect(dates.toFields(), {'start_at': '2026-11-07', 'due_at': '2026-11-09', 'all_day': true, 'tz': null});
    });

    test('an all-day task with only a due leaves the start empty, not blank text', () {
      final fields = TaskDates(due: w(2026, 11, 9), allDay: true).toFields();
      expect(fields['start_at'], isNull);
      expect(fields['due_at'], '2026-11-09');
    });

    test('a timed value carries the offset the zone has on that day, and the zone name', () {
      const zone = 'Europe/Paris';
      expect(TaskDates(due: w(2026, 11, 7, 9), zone: zone).toFields(), {
        'start_at': null,
        'due_at': '2026-11-07T09:00:00+01:00',
        'all_day': false,
        'tz': 'Europe/Paris',
      });
      // Summer time: the same wall clock, a different offset.
      expect(TaskDates(due: w(2026, 7, 7, 9), zone: zone).toFields()['due_at'], '2026-07-07T09:00:00+02:00');
    });

    test('offsets west of UTC and with minutes are written with their sign', () {
      expect(TaskDates(due: w(2026, 11, 7, 9, 30), zone: 'America/New_York').toFields()['due_at'], '2026-11-07T09:30:00-05:00');
      expect(TaskDates(due: w(2026, 11, 7, 9), zone: 'Asia/Kolkata').toFields()['due_at'], '2026-11-07T09:00:00+05:30');
    });

    test('no dates clears the four columns', () {
      expect(const TaskDates(allDay: true).toFields(), {'start_at': null, 'due_at': null, 'all_day': false, 'tz': null});
    });

    test('with no known zone the value is written floating: the platform offset and an empty tz', () {
      final fields = TaskDates(due: w(2026, 11, 7, 9)).toFields();
      expect(fields['tz'], isNull);
      expect(fields['due_at'], matches(RegExp(r'^2026-11-07T09:00:00[+-]\d\d:\d\d$')));
    });

    test('an unknown zone name is not written', () {
      expect(TaskDates(due: w(2026, 11, 7, 9), zone: 'Mars/Olympus').toFields()['tz'], isNull);
    });
  });

  group('reading', () {
    test('an all-day date reads as a day, whatever the device zone', () {
      final d = TaskDates.fromRow(dueAt: '2026-11-07', allDay: true, deviceZone: 'Asia/Tokyo');
      expect(d.due, w(2026, 11, 7));
      expect(d.allDay, isTrue);
      expect(d.start, isNull);
    });

    test('a timed value is shown on the device zone: the instant is kept, the wall clock follows the device', () {
      final d = TaskDates.fromRow(
        dueAt: '2026-11-07T09:00:00+01:00',
        tz: 'Europe/Paris',
        deviceZone: 'America/New_York',
      );
      expect(d.due, w(2026, 11, 7, 3));
      expect(d.zone, 'America/New_York');
      expect(d.allDay, isFalse);
    });

    test('on the zone it was set in, a timed value reads back as set', () {
      const zone = 'Europe/Paris';
      final set = TaskDates(start: w(2026, 7, 7, 9), due: w(2026, 7, 7, 17, 30), zone: zone);
      final back = TaskDates.fromRow(
        startAt: set.toFields()['start_at'] as String?,
        dueAt: set.toFields()['due_at'] as String?,
        tz: set.toFields()['tz'] as String?,
        deviceZone: zone,
      );
      expect(back, set);
    });

    test('all-day dates round trip', () {
      final set = TaskDates(start: w(2026, 11, 7), due: w(2026, 11, 9), allDay: true);
      final f = set.toFields();
      expect(TaskDates.fromRow(startAt: f['start_at'] as String?, dueAt: f['due_at'] as String?, allDay: true), set);
    });

    test('a value with no tz is floating: the wall clock as written, whatever offset it carries', () {
      final d = TaskDates.fromRow(dueAt: '2026-11-07T09:00:00+01:00', deviceZone: 'America/New_York');
      expect(d.due, w(2026, 11, 7, 9));
    });

    test('a value with a tz but no offset is read as that zone\'s wall clock', () {
      final d = TaskDates.fromRow(dueAt: '2026-11-07T09:00:00', tz: 'Europe/Paris', deviceZone: 'America/New_York');
      expect(d.due, w(2026, 11, 7, 3));
    });

    test('an unknown tz is floating', () {
      final d = TaskDates.fromRow(dueAt: '2026-11-07T09:00:00+01:00', tz: 'Mars/Olympus', deviceZone: 'Asia/Tokyo');
      expect(d.due, w(2026, 11, 7, 9));
    });

    test('Z, +0100 and +01 offsets, a space for the T and fractional seconds are read', () {
      const zone = 'Europe/Paris';
      DateTime? due(String text) => TaskDates.fromRow(dueAt: text, tz: zone, deviceZone: zone).due;
      expect(due('2026-11-07T08:00:00Z'), w(2026, 11, 7, 9));
      expect(due('2026-11-07T09:00:00+0100'), w(2026, 11, 7, 9));
      expect(due('2026-11-07T09:00+01'), w(2026, 11, 7, 9));
      expect(due('2026-11-07 09:00:00+01:00'), w(2026, 11, 7, 9));
      expect(due('2026-11-07T09:00:00.000+01:00'), w(2026, 11, 7, 9));
    });

    test('a date with no time in a row that says timed is an all-day date', () {
      final d = TaskDates.fromRow(dueAt: '2026-11-07', allDay: false, tz: 'Europe/Paris', deviceZone: 'Asia/Tokyo');
      expect(d.allDay, isTrue);
      expect(d.due, w(2026, 11, 7));
    });

    test('a time in a row that says all-day keeps the day only', () {
      final d = TaskDates.fromRow(dueAt: '2026-11-07T23:30:00+01:00', allDay: true);
      expect(d.due, w(2026, 11, 7));
      expect(d.allDay, isTrue);
    });

    test('text that is not a date reads as no date and never throws', () {
      for (final text in ['', '   ', 'tomorrow', '2026-13-01', '2026-02-30', '2026-11-07T25:00:00Z', '11/07/2026', '46000']) {
        final d = TaskDates.fromRow(dueAt: text, startAt: text);
        expect(d.isEmpty, isTrue, reason: '"$text"');
      }
      expect(TaskDates.fromRow().isEmpty, isTrue);
    });
  });

  group('editing', () {
    test('a due before the new start moves to the start, and a start after the new due moves to the due', () {
      final base = TaskDates(start: w(2026, 11, 7), due: w(2026, 11, 9), allDay: true);
      expect(base.withStart(w(2026, 11, 12)).due, w(2026, 11, 12));
      expect(base.withStart(w(2026, 11, 8)).due, w(2026, 11, 9));
      expect(base.withDue(w(2026, 11, 5)).start, w(2026, 11, 5));
      expect(base.withDue(w(2026, 11, 20)).start, w(2026, 11, 7));
    });

    test('clearing one side leaves the other', () {
      final base = TaskDates(start: w(2026, 11, 7), due: w(2026, 11, 9), allDay: true);
      expect(base.withStart(null).due, w(2026, 11, 9));
      expect(base.withDue(null).start, w(2026, 11, 7));
    });

    test('all-day off gives each date 09:00, and on again drops the time', () {
      final timed = TaskDates(start: w(2026, 11, 7), due: w(2026, 11, 9), allDay: true).withAllDay(false);
      expect(timed.allDay, isFalse);
      expect(timed.start, w(2026, 11, 7, 9));
      expect(timed.due, w(2026, 11, 9, 9));
      final back = TaskDates(due: w(2026, 11, 9, 17, 45)).withAllDay(true);
      expect(back.due, w(2026, 11, 9));
    });
  });

  group('headline', () {
    // 2026-11-07 10:30 in Paris is 09:30Z.
    final now = DateTime.utc(2026, 11, 7, 9, 30);
    const zone = 'Europe/Paris';

    test('is the due, else the start, else nothing', () {
      expect(TaskDates(start: w(2026, 11, 8), due: w(2026, 11, 9), allDay: true, zone: zone).headline(now)!.wall, w(2026, 11, 9));
      final startOnly = TaskDates(start: w(2026, 11, 8), allDay: true, zone: zone).headline(now)!;
      expect(startOnly.wall, w(2026, 11, 8));
      expect(startOnly.isDue, isFalse);
      expect(const TaskDates().headline(now), isNull);
    });

    test('counts calendar days from today in the device zone', () {
      int days(DateTime due) => TaskDates(due: due, allDay: true, zone: zone).headline(now)!.days;
      expect(days(w(2026, 11, 7)), 0);
      expect(days(w(2026, 11, 8)), 1);
      expect(days(w(2026, 11, 6)), -1);
    });

    test('today is the device\'s day: late evening UTC is already tomorrow in Tokyo', () {
      final lateUtc = DateTime.utc(2026, 11, 7, 20);
      expect(TaskDates(due: w(2026, 11, 8), allDay: true, zone: 'Asia/Tokyo').headline(lateUtc)!.days, 0);
      expect(TaskDates(due: w(2026, 11, 8), allDay: true, zone: 'America/New_York').headline(lateUtc)!.days, 1);
    });

    test('an all-day due is overdue the day after, not on the day', () {
      expect(TaskDates(due: w(2026, 11, 7), allDay: true, zone: zone).headline(now)!.overdue, isFalse);
      expect(TaskDates(due: w(2026, 11, 6), allDay: true, zone: zone).headline(now)!.overdue, isTrue);
    });

    test('a timed due is overdue once its time has passed', () {
      expect(TaskDates(due: w(2026, 11, 7, 10, 29), zone: zone).headline(now)!.overdue, isTrue);
      expect(TaskDates(due: w(2026, 11, 7, 10, 31), zone: zone).headline(now)!.overdue, isFalse);
    });

    test('a start in the past is not overdue', () {
      expect(TaskDates(start: w(2026, 11, 1), allDay: true, zone: zone).headline(now)!.overdue, isFalse);
    });
  });
}
