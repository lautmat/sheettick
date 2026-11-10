import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/parse/quick_add.dart';

/// Wednesday 11 November 2026, 10:00, where the dates are shown.
final now = DateTime.utc(2026, 11, 11, 10);

DateTime w(int y, int m, int d, [int h = 0, int mi = 0]) => DateTime.utc(y, m, d, h, mi);

QuickAddResult parse(String text) => parseQuickAdd(text, now: now, zone: 'Europe/Paris');

void main() {
  group('tags, list and priority', () {
    test('#tags and ^list come out of the title', () {
      final r = parse('Pay rent #home #bills ^Finance');
      expect(r.title, 'Pay rent');
      expect(r.tags, ['home', 'bills']);
      expect(r.listName, 'Finance');
      expect(r.dates.isEmpty, isTrue);
    });

    test('a list with spaces is quoted', () {
      final r = parse('Plan the trip ^"Home projects"');
      expect(r.title, 'Plan the trip');
      expect(r.listName, 'Home projects');
    });

    test('tags keep their letters and accents, and a tag is kept once whatever its case', () {
      final r = parse('Bain #été #Été #sport');
      expect(r.tags, ['été', 'sport']);
      expect(r.title, 'Bain');
    });

    test('priority in words and numbers, English and French', () {
      expect(parse('Task !high').priority, 5);
      expect(parse('Task !medium').priority, 3);
      expect(parse('Task !low').priority, 1);
      expect(parse('Task !none').priority, 0);
      expect(parse('Task !1').priority, 5);
      expect(parse('Task !2').priority, 3);
      expect(parse('Task !3').priority, 1);
      expect(parse('Tâche !haute').priority, 5);
      expect(parse('Tâche !moyenne').priority, 3);
      expect(parse('Tâche !basse').priority, 1);
      expect(parse('Task !high').title, 'Task');
    });

    test('a # or ! inside a word is not a token', () {
      expect(parse('Learn C# today').tags, isEmpty);
      expect(parse('Learn C# today').title, 'Learn C#');
      expect(parse('Say hello! now').priority, isNull);
      expect(parse('Say hello! now').title, 'Say hello! now');
      expect(parse('Open https://example.com/#top').tags, isEmpty);
    });

    test('an unknown !word stays in the title', () {
      final r = parse('Do it !urgentissimo');
      expect(r.priority, isNull);
      expect(r.title, 'Do it !urgentissimo');
    });

    test('tokens can come first, last or between the words', () {
      final r = parse('#work Write ^Office the !2 report');
      expect(r.title, 'Write the report');
      expect(r.tags, ['work']);
      expect(r.listName, 'Office');
      expect(r.priority, 3);
    });
  });

  group('dates in English', () {
    test('today and tomorrow are all-day', () {
      var r = parse('Buy milk tomorrow');
      expect(r.title, 'Buy milk');
      expect(r.dates.due, w(2026, 11, 12));
      expect(r.dates.allDay, isTrue);
      expect(r.dates.zone, isNull);
      r = parse('Buy milk today');
      expect(r.dates.due, w(2026, 11, 11));
      expect(parse('tmr call Sam').dates.due, w(2026, 11, 12));
      expect(parse('Call the day after tomorrow').dates.due, w(2026, 11, 13));
    });

    test('a weekday is the next such day after today', () {
      expect(parse('Gym monday').dates.due, w(2026, 11, 16));
      expect(parse('Gym on friday').dates.due, w(2026, 11, 13));
      expect(parse('Gym next friday').dates.due, w(2026, 11, 13));
      // Today is a Wednesday: "wednesday" means the next one.
      expect(parse('Gym wednesday').dates.due, w(2026, 11, 18));
      expect(parse('Gym wednesday').title, 'Gym');
    });

    test('an abbreviation counts after a preposition or before a time', () {
      expect(parse('Report fri 3pm').dates.due, w(2026, 11, 13, 15));
      expect(parse('Report fri 3pm').title, 'Report');
      expect(parse('Report on fri').dates.due, w(2026, 11, 13));
      expect(parse('Report by thu').dates.due, w(2026, 11, 12));
    });

    test('a bare abbreviation or a word that looks like one stays in the title', () {
      for (final text in ['Meet sat', 'Watch the sun', 'Email Mar about it', 'Mon amie', 'Read sat news']) {
        final r = parse(text);
        expect(r.dates.isEmpty, isTrue, reason: text);
        expect(r.title, text, reason: text);
      }
    });

    test('in N days, weeks, months', () {
      expect(parse('Pay in 3 days').dates.due, w(2026, 11, 14));
      expect(parse('Pay in 3 days').title, 'Pay');
      expect(parse('Review in 2 weeks').dates.due, w(2026, 11, 25));
      expect(parse('Renew in 1 month').dates.due, w(2026, 12, 11));
      expect(parse('Renew in 3 months').dates.due, w(2027, 2, 11));
    });

    test('next week, next month, next year', () {
      expect(parse('Plan next week').dates.due, w(2026, 11, 18));
      expect(parse('Plan next month').dates.due, w(2026, 12, 11));
      expect(parse('Plan next year').dates.due, w(2027, 11, 11));
    });

    test('a calendar date, with or without a year, and in the next year when it has passed', () {
      expect(parse('Party nov 20').dates.due, w(2026, 11, 20));
      expect(parse('Party nov 20th').dates.due, w(2026, 11, 20));
      expect(parse('Party 20 nov').dates.due, w(2026, 11, 20));
      expect(parse('Party 20th of november').dates.due, w(2026, 11, 20));
      expect(parse('Party on december 5').dates.due, w(2026, 12, 5));
      expect(parse('Party jan 5').dates.due, w(2027, 1, 5));
      expect(parse('Party nov 5').dates.due, w(2027, 11, 5));
      expect(parse('Party nov 11').dates.due, w(2026, 11, 11), reason: 'today is not past');
      expect(parse('Party mar 3 2028').dates.due, w(2028, 3, 3));
      expect(parse('Party nov 20').title, 'Party');
    });

    test('an ISO date', () {
      final r = parse('Deadline 2026-12-25');
      expect(r.dates.due, w(2026, 12, 25));
      expect(r.title, 'Deadline');
    });

    test('a day that does not exist is left alone', () {
      final r = parse('Party feb 30');
      expect(r.dates.isEmpty, isTrue);
      expect(r.title, 'Party feb 30');
    });
  });

  group('dates in French', () {
    test('aujourd\'hui, demain, après-demain', () {
      expect(parse('Acheter du pain demain').dates.due, w(2026, 11, 12));
      expect(parse('Acheter du pain demain').title, 'Acheter du pain');
      expect(parse('Appeler aujourd\'hui').dates.due, w(2026, 11, 11));
      expect(parse('Appeler après-demain').dates.due, w(2026, 11, 13));
      expect(parse('Appeler apres demain').dates.due, w(2026, 11, 13));
    });

    test('a weekday, with or without an accent-free spelling, and le', () {
      expect(parse('Sport vendredi').dates.due, w(2026, 11, 13));
      expect(parse('Sport le vendredi').dates.due, w(2026, 11, 13));
      expect(parse('Sport lundi prochain').dates.due, w(2026, 11, 16));
      expect(parse('Sport lundi prochain').title, 'Sport');
      expect(parse('Réunion mercredi').dates.due, w(2026, 11, 18));
    });

    test('dans N jours, semaines, mois', () {
      expect(parse('Payer dans 3 jours').dates.due, w(2026, 11, 14));
      expect(parse('Payer dans 3 jours').title, 'Payer');
      expect(parse('Revoir dans 2 semaines').dates.due, w(2026, 11, 25));
      expect(parse('Renouveler dans 1 mois').dates.due, w(2026, 12, 11));
    });

    test('la semaine prochaine, le mois prochain', () {
      expect(parse('Planifier la semaine prochaine').dates.due, w(2026, 11, 18));
      expect(parse('Planifier le mois prochain').dates.due, w(2026, 12, 11));
    });

    test('a calendar date with the month in letters', () {
      expect(parse('Fête le 20 novembre').dates.due, w(2026, 11, 20));
      expect(parse('Fête le 20 novembre').title, 'Fête');
      expect(parse('Fête 5 décembre').dates.due, w(2026, 12, 5));
      expect(parse('Fête 3 mars 2027').dates.due, w(2027, 3, 3));
      expect(parse('Fête 1er janvier').dates.due, w(2027, 1, 1));
      expect(parse('Voyage 12 août').dates.due, w(2027, 8, 12));
      expect(parse('Voyage 12 fév').dates.due, w(2027, 2, 12));
      expect(parse('Voyage 12 févr. 2028').dates.due, w(2028, 2, 12));
    });
  });

  group('times', () {
    test('a day and a time make a timed due on the device zone', () {
      final r = parse('Dentist tomorrow at 3pm');
      expect(r.title, 'Dentist');
      expect(r.dates.due, w(2026, 11, 12, 15));
      expect(r.dates.allDay, isFalse);
      expect(r.dates.zone, 'Europe/Paris');
      expect(r.dates.toFields()['tz'], 'Europe/Paris');
    });

    test('3pm, 3:30pm, 12am, 12pm, 15:00, 15h, 15h30, à 8h', () {
      DateTime? due(String text) => parse('X tomorrow $text').dates.due;
      expect(due('3pm'), w(2026, 11, 12, 15));
      expect(due('3:30pm'), w(2026, 11, 12, 15, 30));
      expect(due('3:30 PM'), w(2026, 11, 12, 15, 30));
      expect(due('12am'), w(2026, 11, 12, 0));
      expect(due('12pm'), w(2026, 11, 12, 12));
      expect(due('15:00'), w(2026, 11, 12, 15));
      expect(due('9:05'), w(2026, 11, 12, 9, 5));
      expect(due('15h'), w(2026, 11, 12, 15));
      expect(due('15h30'), w(2026, 11, 12, 15, 30));
      expect(due('à 8h'), w(2026, 11, 12, 8));
      expect(due('vers 8h'), w(2026, 11, 12, 8));
    });

    test('noon, midnight, midi, minuit', () {
      expect(parse('X tomorrow noon').dates.due, w(2026, 11, 12, 12));
      expect(parse('X tomorrow midnight').dates.due, w(2026, 11, 12, 0));
      expect(parse('X demain midi').dates.due, w(2026, 11, 12, 12));
      expect(parse('X demain à minuit').dates.due, w(2026, 11, 12, 0));
    });

    test('the examples of the issue', () {
      expect(parse('Report fri 3pm').dates.due, w(2026, 11, 13, 15));
      expect(parse('Rapport vendredi 15h').dates.due, w(2026, 11, 13, 15));
      expect(parse('Rapport vendredi 15h').title, 'Rapport');
    });

    test('only a time: today, or tomorrow when it has already passed', () {
      expect(parse('Call at 3pm').dates.due, w(2026, 11, 11, 15));
      expect(parse('Call at 3pm').title, 'Call');
      expect(parse('Call at 9am').dates.due, w(2026, 11, 12, 9));
      expect(parse('Appeler à 15h').dates.due, w(2026, 11, 11, 15));
      expect(parse('Appeler midi').dates.due, w(2026, 11, 11, 12));
    });

    test('tonight is today at 20:00', () {
      expect(parse('Dinner tonight').dates.due, w(2026, 11, 11, 20));
      expect(parse('Dîner ce soir').dates.due, w(2026, 11, 11, 20));
    });

    test('a delay is an exact moment from now', () {
      expect(parse('Tea in 30 min').dates.due, w(2026, 11, 11, 10, 30));
      expect(parse('Tea in 30 min').dates.allDay, isFalse);
      expect(parse('Tea in 30 min').title, 'Tea');
      expect(parse('Thé dans 2 heures').dates.due, w(2026, 11, 11, 12));
      expect(parse('Tea in 90 minutes').dates.due, w(2026, 11, 11, 11, 30));
    });

    test('a number that is not a time stays in the title', () {
      for (final text in ['Buy 3 apples', 'Meeting 2h', 'Réunion de 2h', 'Release v1.2', 'Call 555-1234', 'Chapter 12']) {
        final r = parse(text);
        expect(r.dates.isEmpty, isTrue, reason: text);
        expect(r.title, text, reason: text);
      }
    });

    test('a month name followed by an hour is a weekday and a time, not a date', () {
      final r = parse('Réunion mar 15h');
      expect(r.dates.due, w(2026, 11, 17, 15));
      expect(r.title, 'Réunion');
    });

    test('case does not matter', () {
      expect(parse('CALL TOMORROW AT 3PM').dates.due, w(2026, 11, 12, 15));
      expect(parse('Appeler DEMAIN À 15H').dates.due, w(2026, 11, 12, 15));
    });
  });

  group('repeating', () {
    test('every day, with the first due today', () {
      final r = parse('Water the plants every day');
      expect(r.title, 'Water the plants');
      expect(r.rrule, 'RRULE:FREQ=DAILY');
      expect(r.dates.due, w(2026, 11, 11));
      expect(r.dates.allDay, isTrue);
    });

    test('every N days, every other week, every 2 weeks', () {
      expect(parse('X every 3 days').rrule, 'RRULE:FREQ=DAILY;INTERVAL=3');
      expect(parse('X every 2 weeks').rrule, 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=WE');
      expect(parse('X every other week').rrule, 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=WE');
      expect(parse('X every 2 weeks').title, 'X');
      expect(parse('X every 2 weeks').dates.due, w(2026, 11, 11));
    });

    test('every week, month, year take the day from the date', () {
      expect(parse('X every week').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=WE');
      expect(parse('X every month').rrule, 'RRULE:FREQ=MONTHLY;BYMONTHDAY=11');
      expect(parse('X every year').rrule, 'RRULE:FREQ=YEARLY');
      expect(parse('X every month from nov 20').rrule, 'RRULE:FREQ=MONTHLY;BYMONTHDAY=20');
      expect(parse('X every month from nov 20').dates.due, w(2026, 11, 20));
    });

    test('daily, weekly, monthly, yearly', () {
      expect(parse('X daily').rrule, 'RRULE:FREQ=DAILY');
      expect(parse('X weekly').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=WE');
      expect(parse('X monthly').rrule, 'RRULE:FREQ=MONTHLY;BYMONTHDAY=11');
      expect(parse('X yearly').rrule, 'RRULE:FREQ=YEARLY');
    });

    test('every monday and thursday: the first due is the next of those days', () {
      final r = parse('Gym every monday and thursday');
      expect(r.title, 'Gym');
      expect(r.rrule, 'RRULE:FREQ=WEEKLY;BYDAY=MO,TH');
      expect(r.dates.due, w(2026, 11, 12));
      expect(parse('Gym every mon, wed, fri').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR');
      expect(parse('Gym every mon, wed, fri').dates.due, w(2026, 11, 11), reason: 'today is a Wednesday');
    });

    test('every weekday', () {
      expect(parse('Standup every weekday').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
      expect(parse('Standup every weekday').dates.due, w(2026, 11, 11));
      expect(parse('Standup weekdays').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
    });

    test('a time on a repeating task: today, or the next day when it has passed', () {
      final later = parse('Pills every day at 3pm');
      expect(later.dates.due, w(2026, 11, 11, 15));
      expect(later.dates.allDay, isFalse);
      expect(later.rrule, 'RRULE:FREQ=DAILY');
      final earlier = parse('Pills every day at 9am');
      expect(earlier.dates.due, w(2026, 11, 12, 9));
    });

    test('every friday at 5pm', () {
      final r = parse('Wrap up every friday at 5pm');
      expect(r.rrule, 'RRULE:FREQ=WEEKLY;BYDAY=FR');
      expect(r.dates.due, w(2026, 11, 13, 17));
      expect(r.title, 'Wrap up');
    });

    test('in French', () {
      expect(parse('Arroser tous les jours').rrule, 'RRULE:FREQ=DAILY');
      expect(parse('Arroser tous les jours').title, 'Arroser');
      expect(parse('Arroser chaque jour').rrule, 'RRULE:FREQ=DAILY');
      expect(parse('Arroser tous les 3 jours').rrule, 'RRULE:FREQ=DAILY;INTERVAL=3');
      expect(parse('Ménage toutes les 2 semaines').rrule, 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=WE');
      expect(parse('Ménage toutes les deux semaines').rrule, 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=WE');
      expect(parse('Ménage chaque semaine').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=WE');
      expect(parse('Loyer tous les mois').rrule, 'RRULE:FREQ=MONTHLY;BYMONTHDAY=11');
      expect(parse('Impôts tous les ans').rrule, 'RRULE:FREQ=YEARLY');
      expect(parse('Sport chaque lundi').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=MO');
      expect(parse('Sport chaque lundi').dates.due, w(2026, 11, 16));
      expect(parse('Sport tous les lundis et jeudis').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=MO,TH');
      expect(parse('Réunion tous les jours ouvrés').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
      expect(parse('Réunion en semaine à 9h').rrule, 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
      expect(parse('Réunion en semaine à 9h').dates.due, w(2026, 11, 12, 9));
    });

    test('a repeating task\'s rule can be read back by the recurrence code', () {
      for (final text in ['X every day', 'X every 2 weeks', 'X every month', 'X every monday and thursday', 'X every year']) {
        expect(parse(text).rrule, startsWith('RRULE:'), reason: text);
      }
    });
  });

  group('everything together', () {
    test('a full line', () {
      final r = parse('Send the invoice tomorrow 3pm #work ^Finance !high');
      expect(r.title, 'Send the invoice');
      expect(r.dates.due, w(2026, 11, 12, 15));
      expect(r.tags, ['work']);
      expect(r.listName, 'Finance');
      expect(r.priority, 5);
      expect(r.hasFields, isTrue);
    });

    test('a full line in French', () {
      final r = parse('Envoyer la facture vendredi 15h #travail ^Finance !haute');
      expect(r.title, 'Envoyer la facture');
      expect(r.dates.due, w(2026, 11, 13, 15));
      expect(r.tags, ['travail']);
      expect(r.listName, 'Finance');
      expect(r.priority, 5);
    });

    test('plain text is just a title', () {
      final r = parse('Buy milk and eggs');
      expect(r.title, 'Buy milk and eggs');
      expect(r.hasFields, isFalse);
    });

    test('text it cannot parse keeps its spelling', () {
      final r = parse('Réunion avec Zoë  #équipe demain');
      expect(r.title, 'Réunion avec Zoë');
      expect(r.tags, ['équipe']);
    });

    test('when nothing but fields is typed, the text is kept whole as the title', () {
      for (final text in ['tomorrow', 'demain 15h', '#work', '!high', 'every day']) {
        final r = parse(text);
        expect(r.title, text);
        expect(r.hasFields, isFalse, reason: text);
      }
    });

    test('empty and blank text', () {
      expect(parse('').title, '');
      expect(parse('   ').title, '');
      expect(parse('').hasFields, isFalse);
    });
  });
}
