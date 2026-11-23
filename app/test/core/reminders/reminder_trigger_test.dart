import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/reminders/reminder_trigger.dart';

void main() {
  group('ReminderTrigger.parse', () {
    test('reads the durations the Sheet holds, with or without the TRIGGER prefix', () {
      expect(ReminderTrigger.parse('TRIGGER:-PT15M'), const ReminderTrigger(seconds: -900));
      expect(ReminderTrigger.parse('-PT15M'), const ReminderTrigger(seconds: -900));
      expect(ReminderTrigger.parse('TRIGGER:PT0S'), const ReminderTrigger());
      expect(ReminderTrigger.parse('trigger:-pt1h'), const ReminderTrigger(seconds: -3600));
      expect(ReminderTrigger.parse(' TRIGGER:PT30M '), const ReminderTrigger(seconds: 1800));
    });

    test('splits whole days from the rest, and a sign applies to both', () {
      expect(ReminderTrigger.parse('-P1D'), const ReminderTrigger(days: -1));
      expect(ReminderTrigger.parse('-P1DT15H'), const ReminderTrigger(days: -1, seconds: -54000));
      expect(ReminderTrigger.parse('P1W'), const ReminderTrigger(days: 7));
      expect(ReminderTrigger.parse('PT1H30M15S'), const ReminderTrigger(seconds: 5415));
    });

    test('reads the way TickTick writes an all-day reminder', () {
      expect(ReminderTrigger.parse('TRIGGER:P0DT9H0M0S'), const ReminderTrigger(seconds: 32400));
    });

    test('reads a parameter before the colon', () {
      expect(ReminderTrigger.parse('TRIGGER;RELATED=START:-PT5M'), const ReminderTrigger(seconds: -300));
    });

    test('text that is not a duration is null', () {
      for (final text in ['', 'P', 'PT', 'TRIGGER:', '15 minutes', 'PT15', '2026-11-07T09:00:00Z', 'PT-5M']) {
        expect(ReminderTrigger.parse(text), isNull, reason: '"$text"');
      }
    });
  });

  group('ReminderTrigger.format', () {
    test('writes TRIGGER and a duration that parses back to the same trigger', () {
      for (final text in ['TRIGGER:PT0S', 'TRIGGER:-PT5M', 'TRIGGER:-PT1H', 'TRIGGER:-P1D', 'TRIGGER:PT9H', 'TRIGGER:-P1DT15H']) {
        expect(ReminderTrigger.parse(text)!.format(), text);
      }
      expect(const ReminderTrigger(seconds: 5415).format(), 'TRIGGER:PT1H30M15S');
    });

    test('days and seconds that point opposite ways cannot be built, so format never changes a trigger', () {
      int days = -1, seconds = 3600; // not const: the check runs at run time
      expect(() => ReminderTrigger(days: days, seconds: seconds), throwsAssertionError);
      days = 1;
      seconds = -3600;
      expect(() => ReminderTrigger(days: days, seconds: seconds), throwsAssertionError);
    });

    test('-P1D and -PT24H are kept apart and ordered the same way every time', () {
      final triggers = parseReminders('["TRIGGER:-PT24H","TRIGGER:-P1D","TRIGGER:-PT24H"]');
      expect(triggers, [const ReminderTrigger(days: -1), const ReminderTrigger(seconds: -86400)]);
      expect(parseReminders('["TRIGGER:-P1D","TRIGGER:-PT24H"]'), triggers);
    });

    test('every preset round-trips', () {
      for (final p in [...timedReminderPresets, ...allDayReminderPresets]) {
        expect(ReminderTrigger.parse(p.trigger.format()), p.trigger, reason: p.label);
      }
    });
  });

  group('the reminders cell', () {
    test('reads a JSON array, earliest first, each trigger once', () {
      final triggers = parseReminders('["TRIGGER:PT0S","TRIGGER:-PT15M","TRIGGER:-PT15M","TRIGGER:-P1D"]');
      expect(triggers, [
        const ReminderTrigger(days: -1),
        const ReminderTrigger(seconds: -900),
        const ReminderTrigger(),
      ]);
    });

    test('leaves out what is unreadable and never throws', () {
      expect(parseReminders('["TRIGGER:-PT5M", 7, "soon", null]'), [const ReminderTrigger(seconds: -300)]);
      for (final text in [null, '', '  ', 'not json', '{"a":1}', '"TRIGGER:PT0S"', '[']) {
        expect(parseReminders(text), isEmpty, reason: '"$text"');
      }
    });

    test('writes a JSON array, or null for none', () {
      expect(encodeReminders(const []), isNull);
      expect(
        encodeReminders([const ReminderTrigger(), const ReminderTrigger(seconds: -900)]),
        '["TRIGGER:-PT15M","TRIGGER:PT0S"]',
      );
    });
  });

  group('custom reminders', () {
    test('on a timed task: minutes and hours are exact, days are calendar days', () {
      expect(timedReminderBefore(45, ReminderUnit.minutes).format(), 'TRIGGER:-PT45M');
      expect(timedReminderBefore(2, ReminderUnit.hours).format(), 'TRIGGER:-PT2H');
      expect(timedReminderBefore(3, ReminderUnit.days).format(), 'TRIGGER:-P3D');
    });

    test('on an all-day task: the same triggers as the presets, in the way TickTick writes them', () {
      for (final (days, preset) in [(0, allDayReminderPresets[0]), (1, allDayReminderPresets[1]), (2, allDayReminderPresets[2])]) {
        expect(allDayReminderAt(daysBefore: days, hour: 9, minute: 0), preset.trigger, reason: preset.label);
      }
      expect(allDayReminderAt(daysBefore: 0, hour: 14, minute: 45).format(), 'TRIGGER:PT14H45M');
      expect(allDayReminderAt(daysBefore: 3, hour: 7, minute: 30).format(), 'TRIGGER:-P2DT16H30M');
      expect(allDayReminderAt(daysBefore: 2, hour: 0, minute: 0).format(), 'TRIGGER:-P2D');
      expect(allDayReminderAt(daysBefore: 0, hour: 0, minute: 0).format(), 'TRIGGER:PT0S');
    });

    test('every preset is described by its own label', () {
      for (final p in timedReminderPresets) {
        expect(describeReminder(p.trigger, allDay: false), p.label);
      }
      for (final p in allDayReminderPresets) {
        expect(describeReminder(p.trigger, allDay: true), p.label);
      }
    });

    test('other triggers are put into words', () {
      String timed(String text) => describeReminder(ReminderTrigger.parse(text)!, allDay: false);
      String allDay(String text) => describeReminder(ReminderTrigger.parse(text)!, allDay: true);
      expect(timed('-PT2H'), '2 hours before');
      expect(timed('-PT1H30M'), '1 hour 30 minutes before');
      expect(timed('-P2DT1H'), '2 days 1 hour before');
      expect(timed('-PT24H'), '24 hours before');
      expect(timed('PT10M'), '10 minutes after');
      expect(allDay('PT14H45M'), 'On the day, 14:45');
      expect(allDay('-P2DT16H30M'), '3 days before, 7:30');
      expect(allDay('-P2D'), '2 days before, 0:00');
      expect(allDay('P1DT9H'), '1 day after, 9:00');
    });
  });
}
