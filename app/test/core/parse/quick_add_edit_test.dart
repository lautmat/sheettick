import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/parse/quick_add.dart';
import 'package:sheettick/core/parse/quick_add_edit.dart';

/// Wednesday 11 November 2026, 10:00, where the dates are shown.
final now = DateTime.utc(2026, 11, 11, 10);
const zone = 'Europe/Paris';

String day(String text, String? word) => setQuickAddDay(text, word, now: now, zone: zone);
String priority(String text, int? p) => setQuickAddPriority(text, p, now: now, zone: zone);
String list(String text, String? name) => setQuickAddList(text, name, now: now, zone: zone);
String tag(String text, String name) => toggleQuickAddTag(text, name, now: now, zone: zone);

QuickAddResult parse(String text) => parseQuickAdd(text, now: now, zone: zone);

void main() {
  group('where the parser found each part', () {
    test('every kind has its stretch of the input, in text order', () {
      const text = 'Call Ana #work ^"Home projects" !high next friday 3pm every week #bills';
      final spans = parse(text).spans;
      String of(QuickAddPart p) => [for (final s in spans[p]!) text.substring(s.start, s.end)].join('|');
      expect(of(QuickAddPart.tag), '#work|#bills');
      expect(of(QuickAddPart.list), '^"Home projects"');
      expect(of(QuickAddPart.priority), '!high');
      expect(of(QuickAddPart.day), 'next friday');
      expect(of(QuickAddPart.time), '3pm');
      expect(of(QuickAddPart.repeat), 'every week');
    });

    test('text with nothing recognised has no spans, and a bare token has none either unless asked for', () {
      expect(parse('Buy milk').spans, isEmpty);
      expect(parse('tomorrow').title, 'tomorrow', reason: 'a lone date word is the title');
      expect(parse('tomorrow').spans, isEmpty);
      final asked = parseQuickAdd('tomorrow', now: now, zone: zone, allowEmptyTitle: true);
      expect(asked.title, isEmpty);
      expect(asked.spans[QuickAddPart.day], [(start: 0, end: 8)]);
    });
  });

  group('day', () {
    test('a day word is added at the end, and the time already typed stays', () {
      expect(day('Call Ana', 'today'), 'Call Ana today');
      final r = parse(day('Call Ana 3pm', 'tomorrow'));
      expect(r.title, 'Call Ana');
      expect(r.dates.due, DateTime.utc(2026, 11, 12, 15));
    });

    test('it replaces the day the text names, whatever way it was written', () {
      expect(day('Call Ana fri 3pm', 'today'), 'Call Ana today 3pm');
      expect(day('Call Ana next friday', 'tomorrow'), 'Call Ana tomorrow');
      expect(day('Pay rent nov 20 #home', 'today'), 'Pay rent today #home');
      expect(day('today Call Ana', 'tomorrow'), 'tomorrow Call Ana');
    });

    test('a null word takes the day out and closes the gap', () {
      expect(day('Call Ana today', null), 'Call Ana');
      expect(day('today Call Ana', null), 'Call Ana');
      expect(day('Call today Ana #home', null), 'Call Ana #home');
      expect(day('Call Ana', null), 'Call Ana');
    });

    test('on an empty field the word is followed by a space, so the title can be typed next', () {
      expect(day('', 'today'), 'today ');
      expect(day('   ', 'tomorrow'), 'tomorrow ');
      expect(day('today ', null), '', reason: 'a lone token is found without a title and can be toggled off');
    });
  });

  group('priority', () {
    test('adds or replaces the token; anything but 5, 3 and 1 takes it out', () {
      expect(priority('Call Ana', 5), 'Call Ana !high');
      expect(priority('Call Ana !low', 3), 'Call Ana !medium');
      expect(priority('Call !1 Ana', 1), 'Call !low Ana');
      expect(priority('Call Ana !high', 0), 'Call Ana');
      expect(priority('Call Ana !high', null), 'Call Ana');
      expect(priority('Call Ana', null), 'Call Ana');
      expect(parse(priority('Call Ana', 5)).priority, 5);
    });
  });

  group('list', () {
    test('a bare name or a quoted one; replaces the list named; null takes it out', () {
      expect(list('Call Ana', 'Work'), 'Call Ana ^Work');
      expect(list('Call Ana', 'Home projects'), 'Call Ana ^"Home projects"');
      expect(list('Call Ana ^Work', 'Home projects'), 'Call Ana ^"Home projects"');
      expect(list('Call ^"Home projects" Ana', 'Work'), 'Call ^Work Ana');
      expect(list('Call Ana ^Work', null), 'Call Ana');
      expect(parse(list('Call Ana', 'Home projects')).listName, 'Home projects');
    });

    test('a name that cannot be written leaves the text alone', () {
      expect(quickAddListToken('Say "hi"'), isNull);
      expect(quickAddListToken('  '), isNull);
      expect(list('Call Ana', 'Say "hi"'), 'Call Ana');
      expect(quickAddListToken('Été'), '^Été');
    });
  });

  group('tag', () {
    test('adds a tag, and the same tag again in any case takes it out', () {
      final one = tag('Call Ana', 'work');
      expect(one, 'Call Ana #work');
      expect(tag(one, 'Work'), 'Call Ana');
      expect(tag('Call #work Ana #bills', 'bills'), 'Call #work Ana');
      expect(parse(tag('Call Ana #home', 'work')).tags, ['home', 'work']);
    });

    test('a tag with a space cannot be written, so the text is left alone', () {
      expect(quickAddTagToken('deep focus'), isNull);
      expect(tag('Call Ana', 'deep focus'), 'Call Ana');
      expect(quickAddTagToken('été'), '#été');
    });
  });

  test('the title and its spacing are left exactly as typed', () {
    expect(day('Call   Ana,  re: "Q4"  friday', 'today'), 'Call   Ana,  re: "Q4"  today');
  });
}
