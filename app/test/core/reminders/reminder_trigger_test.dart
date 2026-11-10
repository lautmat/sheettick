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
}
