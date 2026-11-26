import '../tasks/recurrence.dart';
import '../tasks/task_dates.dart';

/// What a line of quick-add text means: a title and the fields found in it. Understands English and French at once.
///
/// What it recognises, anywhere in the text:
/// - `#tag`, `^list` (or `^"a list"`) and `!priority` (`!high`, `!medium`, `!low`, `!1` high, `!2` medium, `!3` low;
///   French `!haute`, `!moyenne`, `!basse`).
/// - A day: `today`, `tomorrow`, `fri`, `next friday`, `in 3 days`, `next week`, `nov 12`, `12 nov 2027`, `2026-11-12`;
///   `aujourd'hui`, `demain`, `après-demain`, `vendredi`, `dans 3 jours`, `semaine prochaine`, `12 novembre`.
/// - A time: `3pm`, `3:30pm`, `15:00`, `at 15h`, `15h30`, `noon`, `midi`, or a delay (`in 30 min`, `dans 2 heures`).
/// - How it repeats: `every day`, `every 2 weeks`, `every monday and thursday`, `every weekday`, `monthly`;
///   `tous les jours`, `toutes les 2 semaines`, `chaque lundi`, `tous les mois`.
///
/// Whatever it does not recognise stays in the title, in the words and spelling that were typed.
class QuickAddResult {
  const QuickAddResult({
    required this.title,
    this.dates = const TaskDates(),
    this.rrule,
    this.tags = const [],
    this.listName,
    this.priority,
    this.spans = const {},
  });

  /// Where in the input each recognised part was found, so a caller can replace or remove one of them without guessing
  /// what the parser would have taken. Each list is in text order, and a part that was not found has no entry.
  final Map<QuickAddPart, List<QuickAddSpan>> spans;

  /// The text left once the recognised parts are taken out.
  final String title;

  /// The due date (all-day, or timed when a time was given); empty when there was none.
  final TaskDates dates;

  /// The `RRULE:` text, or null when the task does not repeat.
  final String? rrule;

  /// Tag names, without `#`, each once whatever its case.
  final List<String> tags;

  /// The list named with `^`, or null.
  final String? listName;

  /// A `priority` column value (`1` low, `3` medium, `5` high; `0` for `!none`), or null when none was given.
  final int? priority;

  bool get hasFields => !dates.isEmpty || rrule != null || tags.isNotEmpty || listName != null || priority != null;
}

/// The kinds of part [parseQuickAdd] recognises. The date is split in two: the day (`fri`, `next week`, `nov 12`) and
/// the time (`3pm`).
enum QuickAddPart { tag, list, priority, repeat, day, time }

/// The characters `[start, end)` of the input that a part was read from.
typedef QuickAddSpan = ({int start, int end});

/// Parses [text] as quick-add input.
///
/// [now] is the current wall-clock reading where the dates are shown (see [TaskDates.wallOf]); [zone] is the device's
/// IANA zone, which timed dates are set in. If nothing is left once the recognised parts are removed, the text is kept
/// whole as the title and nothing is parsed from it, unless [allowEmptyTitle] asks for the parts anyway (the editing
/// helpers use that, to find a token typed before the title; it is never right for making a task, which needs a title).
QuickAddResult parseQuickAdd(String input, {required DateTime now, String? zone, bool allowEmptyTitle = false}) {
  // The mark for a taken-out part must not come from the input (pasted text can hold any character).
  final text = input.replaceAll(_gone, ' ');
  final parser = _Parser(text, now, zone);
  final result = parser.run();
  if (result.title.isEmpty && !allowEmptyTitle) return QuickAddResult(title: text.trim());
  return result;
}

// ---------------------------------------------------------------------------------------------------------------------
// Vocabulary. Matched on lower-case text with accents removed.

const _weekdayNames = {
  'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 7, //
  'lundi': 1, 'mardi': 2, 'mercredi': 3, 'jeudi': 4, 'vendredi': 5, 'samedi': 6, 'dimanche': 7,
};

const _weekdayAbbreviations = {
  'mon': 1, 'tue': 2, 'tues': 2, 'wed': 3, 'thu': 4, 'thur': 4, 'thurs': 4, 'fri': 5, 'sat': 6, 'sun': 7, //
  'lun': 1, 'mar': 2, 'mer': 3, 'jeu': 4, 'ven': 5, 'sam': 6, 'dim': 7,
};

const _months = {
  'january': 1, 'jan': 1, 'janvier': 1, 'janv': 1, //
  'february': 2, 'feb': 2, 'fevrier': 2, 'fev': 2, 'fevr': 2, //
  'march': 3, 'mar': 3, 'mars': 3, //
  'april': 4, 'apr': 4, 'avril': 4, 'avr': 4, //
  'may': 5, 'mai': 5, //
  'june': 6, 'jun': 6, 'juin': 6, //
  'july': 7, 'jul': 7, 'juillet': 7, 'juil': 7, //
  'august': 8, 'aug': 8, 'aout': 8, //
  'september': 9, 'sept': 9, 'sep': 9, 'septembre': 9, //
  'october': 10, 'oct': 10, 'octobre': 10, //
  'november': 11, 'nov': 11, 'novembre': 11, //
  'december': 12, 'dec': 12, 'decembre': 12,
};

const _numberWords = {'one': 1, 'two': 2, 'three': 3, 'un': 1, 'une': 1, 'deux': 2, 'trois': 3, 'other': 2};

String _alternation(Iterable<String> words) {
  final sorted = words.toList()..sort((a, b) => b.length.compareTo(a.length));
  return sorted.join('|');
}

final _weekdayWords = _alternation(_weekdayNames.keys);
final _weekdayAbbrWords = _alternation(_weekdayAbbreviations.keys);
final _monthWords = _alternation(_months.keys);

/// Lower-case [s] and take the accents off, one character for one character so positions line up with the original.
String _fold(String s) {
  assert(_foldFrom.length == _foldTo.length, 'each accented letter needs exactly one plain letter');
  final b = StringBuffer();
  // One UTF-16 unit in, one out, so positions in the folded text are positions in the original. A unit whose lower
  // case is not one unit long is kept as it is.
  for (final ch in s.split('')) {
    final lower = ch.toLowerCase();
    final c = lower.length == 1 ? lower : ch;
    final i = _foldFrom.indexOf(c);
    b.write(i >= 0 ? _foldTo[i] : c);
  }
  return b.toString();
}

const _foldFrom = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœ';
const _foldTo = 'aaaaaaceeeeiiiinooooouuuuyyo';

/// A mark that replaces a part already taken out of the text, so later patterns cannot use it again.
const _gone = '\u0001';

class _Parser {
  _Parser(this.original, this.now, this.zone) {
    final folded = _fold(original);
    assert(folded.length == original.length, 'folding must keep every position');
    _view = folded.split('');
    _taken = List.filled(original.length, false);
  }

  final String original;
  final DateTime now;
  final String? zone;

  late List<String> _view;
  late List<bool> _taken;

  /// The part being read, so [_take] can say what each taken-out stretch was.
  var _part = QuickAddPart.tag;
  final _spans = <QuickAddPart, List<QuickAddSpan>>{};

  String get _text => _view.join();

  DateTime get _today => DateTime.utc(now.year, now.month, now.day);

  /// Takes [start, end) out of the text.
  void _take(int start, int end) {
    for (var i = start; i < end; i++) {
      _view[i] = _gone;
      _taken[i] = true;
    }
    (_spans[_part] ??= []).add((start: start, end: end));
  }

  /// The first match of [pattern]; takes it out when [take] and returns the match.
  RegExpMatch? _find(RegExp pattern, {bool take = true, bool Function(RegExpMatch)? where}) {
    for (final m in pattern.allMatches(_text)) {
      if (where != null && !where(m)) continue;
      if (take) _take(m.start, m.end);
      return m;
    }
    return null;
  }

  // ------------------------------------------------------------------------------------------------------------- run

  QuickAddResult run() {
    final tags = <String>[];
    String? listName;
    int? priority;

    // #tag
    _part = QuickAddPart.tag;
    final tagPattern = RegExp(r'(?<=^|\s)#([\p{L}\p{N}_\-]+)', unicode: true);
    while (true) {
      final m = _find(tagPattern);
      if (m == null) break;
      final name = original.substring(m.start + 1, m.end);
      if (!tags.any((t) => t.toLowerCase() == name.toLowerCase())) tags.add(name);
    }

    // ^list or ^"a list"
    _part = QuickAddPart.list;
    final listPattern = RegExp(r'(?<=^|\s)\^(?:"([^"]+)"|([\p{L}\p{N}_\-]+))', unicode: true);
    final lm = _find(listPattern);
    if (lm != null) {
      final raw = lm.group(1) != null
          ? original.substring(lm.start + 2, lm.end - 1)
          : original.substring(lm.start + 1, lm.end);
      listName = raw.trim().isEmpty ? null : raw.trim();
    }

    // !priority
    _part = QuickAddPart.priority;
    final pm =_find(RegExp(r'(?<=^|\s)!(high|medium|med|low|none|haute|haut|moyenne|moyen|basse|bas|faible|[0-3hml])(?=\s|$)'));
    if (pm != null) priority = _priorityOf(pm.group(1)!);

    final recurrence = _readRecurrence();
    final when = _readWhen(recurrence);

    var dates = when.dates;
    String? rrule;
    if (recurrence != null) {
      final plan = _plan(recurrence, when);
      rrule = plan.rrule;
      dates = plan.dates;
    }

    return QuickAddResult(
      title: _title(),
      dates: dates,
      rrule: rrule,
      tags: tags,
      listName: listName,
      priority: priority,
      spans: {
        for (final e in _spans.entries) e.key: [...e.value]..sort((a, b) => a.start.compareTo(b.start)),
      },
    );
  }

  static int _priorityOf(String word) => switch (word) {
    'high' || 'haute' || 'haut' || 'h' || '1' => 5,
    'medium' || 'med' || 'moyenne' || 'moyen' || 'm' || '2' => 3,
    'low' || 'basse' || 'bas' || 'faible' || 'l' || '3' => 1,
    _ => 0,
  };

  /// What is left of the original text: the characters not taken out, with the gaps closed.
  String _title() {
    final b = StringBuffer();
    for (var i = 0; i < original.length; i++) {
      b.write(_taken[i] ? ' ' : original[i]);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ------------------------------------------------------------------------------------------------------ recurrence

  _Recurrence? _readRecurrence() {
    _part = QuickAddPart.repeat;
    // Every weekday / en semaine / jours ouvres.
    var m = _find(RegExp(
      r'\b(?:(?:every|each|tous les|chaque)\s+(?:week\s?days?|work\s?days?|business days?|jours? ouvres?|jours? ouvrables?)|weekdays|en semaine)\b',
    ));
    if (m != null) return const _Recurrence.days([1, 2, 3, 4, 5]);

    // Every monday, every mon and thu, tous les lundis, chaque lundi.
    final dayList = '(?:$_weekdayWords|$_weekdayAbbrWords)s?';
    m = _find(RegExp(r'\b(?:every|each|tous les|toutes les|chaque)\s+(' '$dayList' r'(?:\s*(?:,|and|et|&)\s*' '$dayList' r')*)\b'));
    if (m != null) {
      final days = <int>{};
      for (final w in RegExp('$_weekdayWords|$_weekdayAbbrWords').allMatches(m.group(1)!)) {
        final word = w.group(0)!;
        days.add(_weekdayNames[word] ?? _weekdayAbbreviations[word]!);
      }
      return _Recurrence.days(days.toList()..sort());
    }

    // Every day / week / month / year, every 2 weeks, every other week, tous les 3 jours.
    m = _find(RegExp(
      r'\b(?:every|each|tous les|toutes les|chaque)\s+(?:(\d+|other|one|two|three|un|une|deux|trois)\s+)?(days?|weeks?|months?|years?|jours?|semaines?|mois|ans?|annees?)\b',
    ));
    if (m != null) {
      final count = m.group(1);
      final interval = count == null ? 1 : (int.tryParse(count) ?? _numberWords[count] ?? 1);
      return _Recurrence.every(_unitOf(m.group(2)!), interval < 1 ? 1 : interval);
    }

    // daily, weekly, ...
    m = _find(RegExp(r'\b(daily|weekly|monthly|yearly|annually|quotidien|quotidienne|hebdomadaire|mensuel|mensuelle|annuel|annuelle)\b'));
    if (m != null) {
      return _Recurrence.every(switch (m.group(1)!) {
        'daily' || 'quotidien' || 'quotidienne' => _Unit.day,
        'weekly' || 'hebdomadaire' => _Unit.week,
        'monthly' || 'mensuel' || 'mensuelle' => _Unit.month,
        _ => _Unit.year,
      }, 1);
    }
    return null;
  }

  static _Unit _unitOf(String word) {
    if (word.startsWith('day') || word.startsWith('jour')) return _Unit.day;
    if (word.startsWith('week') || word.startsWith('semaine')) return _Unit.week;
    if (word.startsWith('month') || word == 'mois') return _Unit.month;
    return _Unit.year;
  }

  // -------------------------------------------------------------------------------------------------------------- when

  /// The date and time in the text.
  _When _readWhen(_Recurrence? recurrence) {
    _part = QuickAddPart.day;
    DateTime? day;
    var dayWasGiven = false;
    ({int hour, int minute})? time;
    DateTime? exact; // a delay such as "in 30 minutes": an exact moment, with its own time

    // In 30 minutes / dans 2 heures / in 3 days / dans 2 semaines.
    var m = _find(RegExp(r'\b(?:in|dans)\s+(\d+)\s*(mins?|minutes?|h|hrs?|hours?|heures?|days?|jours?|weeks?|semaines?|months?|mois|years?|ans?)\b'));
    if (m != null) {
      final n = int.parse(m.group(1)!);
      final unit = m.group(2)!;
      if (unit.startsWith('min')) {
        exact = now.add(Duration(minutes: n));
      } else if (unit == 'h' || unit.startsWith('hr') || unit.startsWith('hour') || unit.startsWith('heure')) {
        exact = now.add(Duration(hours: n));
      } else if (unit.startsWith('day') || unit.startsWith('jour')) {
        day = _today.add(Duration(days: n));
      } else if (unit.startsWith('week') || unit.startsWith('semaine')) {
        day = _today.add(Duration(days: 7 * n));
      } else if (unit.startsWith('month') || unit == 'mois') {
        day = _addMonths(_today, n);
      } else {
        day = DateTime.utc(_today.year + n, _today.month, _today.day);
      }
      dayWasGiven = true;
    }

    if (day == null && exact == null) {
      // next week / semaine prochaine
      m = _find(RegExp(r'\b(?:next\s+(week|month|year)|(?:la\s+|le\s+)?(semaine|mois|annee)\s+prochaine?)\b'));
      if (m != null) {
        final unit = m.group(1) ?? m.group(2)!;
        day = switch (unit) {
          'week' || 'semaine' => _today.add(const Duration(days: 7)),
          'month' || 'mois' => _addMonths(_today, 1),
          _ => DateTime.utc(_today.year + 1, _today.month, _today.day),
        };
        dayWasGiven = true;
      }
    }

    if (day == null && exact == null) {
      // The day after tomorrow / apres-demain, then tomorrow, today.
      m = _find(RegExp(r"\b(?:(?:the )?day after tomorrow|apres[- ]?demain)\b"));
      if (m != null) {
        day = _today.add(const Duration(days: 2));
        dayWasGiven = true;
      }
    }
    if (day == null && exact == null) {
      m = _find(RegExp(r"\b(?:(?:on|for|pour)\s+)?(tomorrow|tmrw|tmr|demain|today|tonight|aujourd['’]?hui|ce soir)\b"));
      if (m != null) {
        final word = m.group(1)!;
        day = (word == 'tomorrow' || word == 'tmrw' || word == 'tmr' || word == 'demain')
            ? _today.add(const Duration(days: 1))
            : _today;
        dayWasGiven = true;
        if (word == 'tonight' || word == 'ce soir') time = (hour: 20, minute: 0);
      }
    }

    if (day == null && exact == null) {
      day = _readCalendarDate();
      dayWasGiven = day != null;
    }

    if (day == null && exact == null) {
      // With a rule, "every week on friday" still names the day the series starts on.
      final weekday = _readWeekday();
      if (weekday != null) {
        day = weekday;
        dayWasGiven = true;
      }
    }

    _part = QuickAddPart.time;
    if (exact == null) time ??= _readTime(followsDate: dayWasGiven);

    if (exact != null) {
      return _When(
        dates: TaskDates(due: DateTime.utc(exact.year, exact.month, exact.day, exact.hour, exact.minute), zone: zone),
        day: null,
        time: null,
        given: true,
      );
    }
    if (day == null && time == null) return const _When(dates: TaskDates(), day: null, time: null, given: false);

    var base = day;
    if (base == null) {
      // Only a time: today, or tomorrow when it has already gone by (unless it repeats, which decides the day itself).
      base = _today;
      if (recurrence == null) {
        final at = DateTime.utc(base.year, base.month, base.day, time!.hour, time.minute);
        if (!at.isAfter(now)) base = base.add(const Duration(days: 1));
      }
    }
    final due = time == null
        ? base
        : DateTime.utc(base.year, base.month, base.day, time.hour, time.minute);
    return _When(
      dates: TaskDates(due: due, allDay: time == null, zone: time == null ? null : zone),
      day: day,
      time: time,
      given: true,
    );
  }

  /// `nov 12`, `12th of november 2027`, `le 12 novembre`, `2026-11-12`. The next such day when no year was given.
  DateTime? _readCalendarDate() {
    final iso = _find(RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b'), where: (m) => _real(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)));
    if (iso != null) return DateTime.utc(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));

    // The day number must not be the hour of a time ("mar 15h", "nov 12 3pm" is fine: 12 is followed by a space).
    const notATime = r'(?!\d|h\b|:|\s*(?:am|pm)\b)';
    final monthFirst = RegExp(
      r'\b(?:(?:on|le)\s+)?(' '$_monthWords' r')\.?\s+(\d{1,2})(?:st|nd|rd|th)?' '$notATime' r'(?:,?\s+(\d{4})\b)?',
    );
    final dayFirst = RegExp(
      r'\b(?:(?:on|le)\s+)?(\d{1,2})(?:st|nd|rd|th|er)?\s+(?:of\s+|de\s+)?(' '$_monthWords' r')\b\.?(?:,?\s+(\d{4})\b)?',
    );
    for (final entry in [(monthFirst, true), (dayFirst, false)]) {
      final (pattern, monthIsFirst) = entry;
      final m = _find(pattern, take: false, where: (m) {
        final month = _months[monthIsFirst ? m.group(1)! : m.group(2)!]!;
        final dayNumber = int.parse(monthIsFirst ? m.group(2)! : m.group(1)!);
        final year = m.group(3) == null ? _today.year : int.parse(m.group(3)!);
        return _real(year, month, dayNumber);
      });
      if (m == null) continue;
      _take(m.start, m.end);
      final month = _months[monthIsFirst ? m.group(1)! : m.group(2)!]!;
      final dayNumber = int.parse(monthIsFirst ? m.group(2)! : m.group(1)!);
      if (m.group(3) != null) return DateTime.utc(int.parse(m.group(3)!), month, dayNumber);
      var date = DateTime.utc(_today.year, month, dayNumber);
      if (date.isBefore(_today)) date = DateTime.utc(_today.year + 1, month, dayNumber);
      return date;
    }
    return null;
  }

  static bool _real(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return false;
    final date = DateTime.utc(y, m, d);
    return date.month == m && date.day == d;
  }

  /// A weekday name: the next such day after today. A three-letter abbreviation counts only after a preposition or
  /// before a time, so "sat" or "mar" in a title is left alone.
  DateTime? _readWeekday() {
    final prefix = r'(?:(?:on|next|this|by|le|ce|jusqu a|jusqu au|before|avant)\s+)?';
    final suffix = r'(?:\s+(?:next|prochain|prochaine))?';
    var m = _find(RegExp(r'\b' '$prefix' r'(' '$_weekdayWords' r')\b' '$suffix'));
    String? word = m?.group(1);
    if (m == null) {
      m = _find(RegExp(r'\b(?:(?:on|next|this|by|le|ce|before|avant)\s+)(' '$_weekdayAbbrWords' r')\b\.?' '$suffix'));
      word = m?.group(1);
    }
    if (m == null) {
      m = _find(RegExp(r'\b(' '$_weekdayAbbrWords' r')\b\.?(?=\s*(?:at |a |vers )?\d{1,2}(?::\d{2}|h|\s*(?:am|pm)\b))' '$suffix'));
      word = m?.group(1);
    }
    if (m == null || word == null) return null;
    final target = _weekdayNames[word] ?? _weekdayAbbreviations[word]!;
    var ahead = (target - _today.weekday) % 7;
    if (ahead == 0) ahead = 7;
    return _today.add(Duration(days: ahead));
  }

  /// `3pm`, `3:30 pm`, `15:00`, `15h`, `15h30`, `noon`, `midi`, `midnight`, `minuit`.
  ({int hour, int minute})? _readTime({required bool followsDate}) {
    final word = _find(RegExp(r'\b(?:(?:at|a|vers|around)\s+)?(noon|midi|midnight|minuit)\b'));
    if (word != null) return (hour: (word.group(1) == 'noon' || word.group(1) == 'midi') ? 12 : 0, minute: 0);

    final ampm = _find(
      RegExp(r'\b(?:(?:at|a|vers|around|by)\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b'),
      where: (m) {
        final h = int.parse(m.group(1)!);
        return h >= 1 && h <= 12 && (m.group(2) == null || int.parse(m.group(2)!) < 60);
      },
    );
    if (ampm != null) {
      var hour = int.parse(ampm.group(1)!) % 12;
      if (ampm.group(3) == 'pm') hour += 12;
      return (hour: hour, minute: int.tryParse(ampm.group(2) ?? '0') ?? 0);
    }

    final clock = _find(
      RegExp(r'\b(?:(?:at|a|vers|around|by)\s+)?([01]?\d|2[0-3]):([0-5]\d)\b'),
    );
    if (clock != null) return (hour: int.parse(clock.group(1)!), minute: int.parse(clock.group(2)!));

    // 15h, 15h30. "2h" alone is as likely a length of time, so a bare hour needs a preposition, a date before it, or
    // to be 12 or later.
    final h = _find(
      RegExp(r'\b((?:at|a|vers|around|by)\s+)?([01]?\d|2[0-3])h([0-5]\d)?\b'),
      where: (m) {
        final hour = int.parse(m.group(2)!);
        return m.group(1) != null || m.group(3) != null || hour >= 12 || followsDate;
      },
    );
    if (h != null) return (hour: int.parse(h.group(2)!), minute: int.tryParse(h.group(3) ?? '0') ?? 0);
    return null;
  }

  static DateTime _addMonths(DateTime d, int n) {
    final index = d.month - 1 + n;
    final year = d.year + index ~/ 12;
    final month = index % 12 + 1;
    final last = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(year, month, d.day > last ? last : d.day);
  }

  // ---------------------------------------------------------------------------------------------------- the rule

  /// The rule and the first due, from what was read: the day the text gave, else the first day the rule falls on.
  ({String rrule, TaskDates dates}) _plan(_Recurrence r, _When when) {
    final time = when.time;
    final timed = time != null;
    final explicit = when.day;
    DateTime at(DateTime day) =>
        timed ? DateTime.utc(day.year, day.month, day.day, time.hour, time.minute) : DateTime.utc(day.year, day.month, day.day);

    // The day the series starts from, before the rule has a say.
    final start = explicit ?? _today;
    final String text;
    switch (r) {
      case _Days(:final days):
        text = 'RRULE:FREQ=WEEKLY;BYDAY=${days.map(_byDay).join(',')}';
      case _Every(:final unit, :final interval):
        final every = interval > 1 ? ';INTERVAL=$interval' : '';
        text = switch (unit) {
          _Unit.day => 'RRULE:FREQ=DAILY$every',
          _Unit.week => 'RRULE:FREQ=WEEKLY$every;BYDAY=${_byDay(start.weekday)}',
          _Unit.month => 'RRULE:FREQ=MONTHLY$every;BYMONTHDAY=${start.day}',
          _Unit.year => 'RRULE:FREQ=YEARLY$every',
        };
    }

    // With no day in the text, the first due is the first day the rule falls on from now.
    DateTime due;
    if (explicit != null) {
      due = at(explicit);
    } else {
      final rule = parseRrule(text);
      final from = DateTime.utc(_today.year, _today.month, _today.day);
      due = at(from);
      if (rule != null) {
        // The rule counts from today at the given time; the first instance not before now (today's, if its time has
        // not passed). The rule library needs `after` to be no earlier than the start.
        final begin = at(from);
        final passed = timed && !now.isBefore(begin);
        for (final candidate in rule.getInstances(
          start: begin,
          after: passed ? now : begin,
          includeAfter: !passed,
        )) {
          due = candidate;
          break;
        }
      }
    }
    return (rrule: text, dates: TaskDates(due: due, allDay: !timed, zone: timed ? zone : null));
  }

  static String _byDay(int weekday) => const ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'][weekday - 1];
}

enum _Unit { day, week, month, year }

sealed class _Recurrence {
  const _Recurrence();
  const factory _Recurrence.days(List<int> days) = _Days;
  const factory _Recurrence.every(_Unit unit, int interval) = _Every;
}

class _Days extends _Recurrence {
  const _Days(this.days);

  final List<int> days;
}

class _Every extends _Recurrence {
  const _Every(this.unit, this.interval);

  final _Unit unit;
  final int interval;
}

class _When {
  const _When({required this.dates, required this.day, required this.time, required this.given});

  /// The due as read, ready to use when the task does not repeat.
  final TaskDates dates;

  /// The day the text named, if it named one.
  final DateTime? day;
  final ({int hour, int minute})? time;
  final bool given;
}
