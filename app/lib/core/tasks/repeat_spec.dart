/// How often a task repeats, in the terms the custom repeat editor offers, and the words for any repeat rule.
///
/// [RepeatSpec.parse] reads only the rules the editor can show and write back exactly; anything else (an ordinal
/// weekday such as `BYDAY=2TU`, `BYSETPOS`, `BYMONTH`, several month days, ...) reads as null, and the caller keeps the
/// rule text untouched. [describeRepeat] puts any rule into words, for the chip and the dialog.
library;

enum RepeatUnit {
  day('DAILY', 'day'),
  week('WEEKLY', 'week'),
  month('MONTHLY', 'month'),
  year('YEARLY', 'year');

  const RepeatUnit(this.freq, this.noun);

  final String freq;
  final String noun;
}

/// Where a repeat ends.
sealed class RepeatEnd {
  const RepeatEnd();
}

class RepeatNever extends RepeatEnd {
  const RepeatNever();
  @override
  bool operator ==(Object other) => other is RepeatNever;
  @override
  int get hashCode => 0;
}

/// Ends on [day] (a calendar day, inclusive): `UNTIL`.
class RepeatUntil extends RepeatEnd {
  RepeatUntil(DateTime day) : day = DateTime.utc(day.year, day.month, day.day);
  final DateTime day;
  @override
  bool operator ==(Object other) => other is RepeatUntil && other.day == day;
  @override
  int get hashCode => day.hashCode;
}

/// Ends after [times] occurrences: `COUNT`.
class RepeatCount extends RepeatEnd {
  const RepeatCount(this.times);
  final int times;
  @override
  bool operator ==(Object other) => other is RepeatCount && other.times == times;
  @override
  int get hashCode => times.hashCode;
}

const _byDay = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December',
];

class RepeatSpec {
  RepeatSpec({
    required this.unit,
    this.interval = 1,
    Set<int> weekdays = const {},
    this.monthDay,
    this.end = const RepeatNever(),
  }) : weekdays = Set.unmodifiable(weekdays);

  final RepeatUnit unit;

  /// Every [interval] days, weeks, months or years; at least 1.
  final int interval;

  /// For weekly rules: the weekdays, 1 (Monday) to 7 (Sunday). Empty means the weekday of the task's date.
  final Set<int> weekdays;

  /// For monthly rules: 1 to 31, or -1 for the last day. Null means the day of the task's date.
  final int? monthDay;

  final RepeatEnd end;

  /// A spec for a task dated [anchor], with the weekday or day of month filled in from it.
  factory RepeatSpec.starting(RepeatUnit unit, DateTime anchor) => switch (unit) {
    RepeatUnit.week => RepeatSpec(unit: unit, weekdays: {anchor.weekday}),
    RepeatUnit.month => RepeatSpec(unit: unit, monthDay: anchor.day),
    _ => RepeatSpec(unit: unit),
  };

  RepeatSpec copyWith({RepeatUnit? unit, int? interval, Set<int>? weekdays, int? monthDay, bool clearMonthDay = false, RepeatEnd? end}) =>
      RepeatSpec(
        unit: unit ?? this.unit,
        interval: interval ?? this.interval,
        weekdays: weekdays ?? this.weekdays,
        monthDay: clearMonthDay ? null : (monthDay ?? this.monthDay),
        end: end ?? this.end,
      );

  /// The RFC 5545 rule. [anchor] fills in the weekday or month day the spec leaves open.
  String format(DateTime anchor) {
    final b = StringBuffer('RRULE:FREQ=${unit.freq}');
    if (interval > 1) b.write(';INTERVAL=$interval');
    if (unit == RepeatUnit.week) {
      final days = (weekdays.isEmpty ? {anchor.weekday} : weekdays).toList()..sort();
      b.write(';BYDAY=${days.map((d) => _byDay[d - 1]).join(',')}');
    }
    if (unit == RepeatUnit.month) b.write(';BYMONTHDAY=${monthDay ?? anchor.day}');
    switch (end) {
      case RepeatUntil(:final day):
        // End of that day, so a timed task on the last day still repeats; the same text reads for an all-day task.
        b.write(';UNTIL=${_ymd(day)}T235959Z');
      case RepeatCount(:final times):
        b.write(';COUNT=$times');
      case RepeatNever():
        break;
    }
    return b.toString();
  }

  /// The spec for [rrule], or null when the editor cannot show it exactly.
  static RepeatSpec? parse(String? rrule) {
    final parts = _parts(rrule);
    if (parts == null) return null;
    final allowed = {'FREQ', 'INTERVAL', 'BYDAY', 'BYMONTHDAY', 'UNTIL', 'COUNT', 'WKST'};
    if (!parts.keys.every(allowed.contains)) return null;
    if ((parts['WKST'] ?? 'MO') != 'MO') return null;
    final unit = RepeatUnit.values.where((u) => u.freq == parts['FREQ']).firstOrNull;
    if (unit == null) return null;
    final interval = parts.containsKey('INTERVAL') ? int.tryParse(parts['INTERVAL']!) : 1;
    if (interval == null || interval < 1) return null;

    var weekdays = <int>{};
    if (parts.containsKey('BYDAY')) {
      if (unit != RepeatUnit.week) return null;
      for (final d in parts['BYDAY']!.split(',')) {
        final i = _byDay.indexOf(d);
        if (i < 0) return null;
        weekdays.add(i + 1);
      }
    }
    int? monthDay;
    if (parts.containsKey('BYMONTHDAY')) {
      if (unit != RepeatUnit.month) return null;
      monthDay = int.tryParse(parts['BYMONTHDAY']!);
      if (monthDay == null || monthDay == 0 || monthDay > 31 || monthDay < -1) return null;
    }
    if (parts.containsKey('UNTIL') && parts.containsKey('COUNT')) return null;
    RepeatEnd end = const RepeatNever();
    if (parts.containsKey('UNTIL')) {
      final day = _untilDay(parts['UNTIL']!);
      if (day == null) return null;
      end = RepeatUntil(day);
    }
    if (parts.containsKey('COUNT')) {
      final n = int.tryParse(parts['COUNT']!);
      if (n == null || n < 1) return null;
      end = RepeatCount(n);
    }
    return RepeatSpec(unit: unit, interval: interval, weekdays: weekdays, monthDay: monthDay, end: end);
  }

  /// This spec in words, for a task dated [anchor].
  String describe(DateTime anchor) => describeRepeat(format(anchor)) ?? format(anchor);

  @override
  bool operator ==(Object other) =>
      other is RepeatSpec &&
      other.unit == unit &&
      other.interval == interval &&
      other.monthDay == monthDay &&
      other.end == end &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hash(unit, interval, monthDay, end, Object.hashAll(weekdays.toList()..sort()));
}

String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

DateTime? _untilDay(String text) {
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(text);
  if (m == null) return null;
  final d = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return (d.month == int.parse(m[2]!) && d.day == int.parse(m[3]!)) ? d : null;
}

/// The `KEY=value` parts of [rrule] (label optional, any case), or null when it is empty or malformed.
Map<String, String>? _parts(String? rrule) {
  final text = (rrule ?? '').trim().replaceFirst(RegExp('^RRULE:', caseSensitive: false), '');
  if (text.isEmpty) return null;
  final out = <String, String>{};
  for (final piece in text.split(';')) {
    final eq = piece.indexOf('=');
    if (eq <= 0 || eq == piece.length - 1) return null;
    final key = piece.substring(0, eq).trim().toUpperCase();
    if (out.containsKey(key)) return null;
    out[key] = piece.substring(eq + 1).trim().toUpperCase();
  }
  return out.containsKey('FREQ') ? out : null;
}

String _ordinal(int n) {
  if (n == -1) return 'last';
  final abs = n.abs();
  final suffix = (abs % 100 >= 11 && abs % 100 <= 13) ? 'th' : switch (abs % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
  return n < 0 ? '$abs$suffix from last' : '$n$suffix';
}

String _dayList(List<String> names) =>
    names.length <= 1 ? names.join() : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

/// A day written so that no locale can misread it: `5 March 2027`.
String longRepeatDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

/// A rule in words ("Every 3 months on day 27", "Every week on Monday and Thursday, 10 times"), or null when [rrule]
/// has no readable `FREQ`. It copes with rules the editor cannot show, such as `BYDAY=2TU`; parts it does not know are
/// left out of the sentence.
String? describeRepeat(String? rrule) {
  final parts = _parts(rrule);
  if (parts == null) return null;
  final unit = RepeatUnit.values.where((u) => u.freq == parts['FREQ']).firstOrNull;
  if (unit == null) return null;
  final n = int.tryParse(parts['INTERVAL'] ?? '') ?? 1;
  final b = StringBuffer(n > 1 ? 'Every $n ${unit.noun}s' : switch (unit) {
    RepeatUnit.day => 'Every day',
    RepeatUnit.week => 'Every week',
    RepeatUnit.month => 'Every month',
    RepeatUnit.year => 'Every year',
  });

  final byDay = parts['BYDAY']?.split(',').map((d) => RegExp(r'^([+-]?\d+)?(MO|TU|WE|TH|FR|SA|SU)$').firstMatch(d)).toList();
  if (byDay != null && byDay.every((m) => m != null)) {
    final plainDays = byDay.every((m) => m![1] == null);
    final names = [
      for (final m in byDay)
        '${m![1] == null ? '' : '${_ordinal(int.parse(m[1]!))} '}${_dayNames[_byDay.indexOf(m[2]!)]}',
    ];
    if (plainDays && names.length == 5 && parts['BYDAY'] == 'MO,TU,WE,TH,FR' && unit == RepeatUnit.week) {
      b.write(' on weekdays');
    } else if (names.isNotEmpty) {
      b.write(' on ${_dayList(names)}');
    }
  }
  final monthDays = parts['BYMONTHDAY']?.split(',').map(int.tryParse).toList();
  if (monthDays != null && monthDays.every((d) => d != null)) {
    b.write(monthDays.length == 1 && monthDays.single == -1
        ? ' on the last day'
        : ' on day ${_dayList([for (final d in monthDays) d! < 0 ? _ordinal(d) : '$d'])}');
  }
  final months = parts['BYMONTH']?.split(',').map(int.tryParse).toList();
  if (months != null && months.every((m) => m != null && m >= 1 && m <= 12)) {
    b.write(' in ${_dayList([for (final m in months) _monthNames[m! - 1]])}');
  }
  final until = parts.containsKey('UNTIL') ? _untilDay(parts['UNTIL']!) : null;
  if (until != null) b.write(', until ${longRepeatDate(until)}');
  final count = int.tryParse(parts['COUNT'] ?? '');
  if (count != null) b.write(count == 1 ? ', once' : ', $count times');
  return b.toString();
}
