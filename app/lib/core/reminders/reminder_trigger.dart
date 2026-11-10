import 'dart:convert';

/// One reminder of a task: an iCal duration from the task's anchor moment (see `docs/sheet-schema.md`, "Reminders").
///
/// The duration is split the way a person reads it. [days] are calendar days, so "1 day before" stays at the same
/// clock time across a daylight-saving change; [seconds] is the rest, an exact length of time. Both are negative for a
/// reminder before the anchor. `PT0S` (both zero) fires at the anchor itself.
///
/// An iCal duration has one sign for the whole value, so [days] and [seconds] never point opposite ways; [parse] always
/// gives that, and the assert keeps hand-built triggers to it. That is what lets [format] write the sign once.
class ReminderTrigger {
  const ReminderTrigger({this.days = 0, this.seconds = 0})
    : assert(days == 0 || seconds == 0 || (days < 0) == (seconds < 0), 'days and seconds must share a sign');

  final int days;
  final int seconds;

  static final _pattern = RegExp(
    r'^(?:TRIGGER(?:;[^:]*)?:)?([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
    caseSensitive: false,
  );

  /// Reads `TRIGGER:-PT15M`, `-PT15M` or `P0DT9H0M0S`. Null for text that is not a duration.
  static ReminderTrigger? parse(String text) {
    final trimmed = text.trim();
    final m = _pattern.firstMatch(trimmed);
    if (m == null) return null;
    // "P" and "PT" alone have no component and are not durations.
    if (List.generate(5, (i) => m.group(i + 2)).every((g) => g == null)) return null;
    int n(int group) => int.tryParse(m.group(group) ?? '0') ?? 0;
    final sign = m.group(1) == '-' ? -1 : 1;
    return ReminderTrigger(days: sign * (n(2) * 7 + n(3)), seconds: sign * (n(4) * 3600 + n(5) * 60 + n(6)));
  }

  /// The text stored in the Sheet: `TRIGGER:-PT15M`.
  String format() {
    final negative = days < 0 || seconds < 0;
    final d = days.abs(), s = seconds.abs();
    final h = s ~/ 3600, mi = s % 3600 ~/ 60, sec = s % 60;
    final b = StringBuffer('TRIGGER:')
      ..write(negative ? '-' : '')
      ..write('P');
    if (d > 0) b.write('${d}D');
    if (s > 0 || d == 0) {
      b.write('T');
      if (h > 0) b.write('${h}H');
      if (mi > 0) b.write('${mi}M');
      if (sec > 0 || (h == 0 && mi == 0)) b.write('${sec}S');
    }
    return b.toString();
  }

  @override
  bool operator ==(Object other) => other is ReminderTrigger && other.days == days && other.seconds == seconds;

  @override
  int get hashCode => Object.hash(days, seconds);

  @override
  String toString() => format();
}

/// The triggers in a task's `reminders` cell (a JSON array of strings). Anything unreadable is left out, and the
/// result has each trigger once, earliest reminder first.
List<ReminderTrigger> parseReminders(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  final triggers = <ReminderTrigger>{
    for (final item in decoded)
      if (item is String) ?ReminderTrigger.parse(item),
  };
  return _sorted(triggers);
}

/// The `reminders` cell for [triggers]: a JSON array, or null for none.
String? encodeReminders(Iterable<ReminderTrigger> triggers) {
  final list = _sorted(triggers.toSet());
  if (list.isEmpty) return null;
  return jsonEncode([for (final t in list) t.format()]);
}

List<ReminderTrigger> _sorted(Set<ReminderTrigger> triggers) {
  // `-P1D` and `-PT24H` are different triggers (across a daylight-saving change) with the same length, so the text
  // breaks the tie and the order is the same on every device.
  return triggers.toList()
    ..sort((a, b) {
      final byLength = (a.days * 86400 + a.seconds).compareTo(b.days * 86400 + b.seconds);
      return byLength != 0 ? byLength : a.format().compareTo(b.format());
    });
}

/// A reminder the picker offers.
class ReminderPreset {
  const ReminderPreset(this.label, this.trigger);

  final String label;
  final ReminderTrigger trigger;
}

/// For a task with a time: relative to that moment.
const timedReminderPresets = [
  ReminderPreset('At the time', ReminderTrigger()),
  ReminderPreset('5 minutes before', ReminderTrigger(seconds: -300)),
  ReminderPreset('15 minutes before', ReminderTrigger(seconds: -900)),
  ReminderPreset('30 minutes before', ReminderTrigger(seconds: -1800)),
  ReminderPreset('1 hour before', ReminderTrigger(seconds: -3600)),
  ReminderPreset('1 day before', ReminderTrigger(days: -1)),
];

/// For an all-day task, whose anchor is midnight at the start of the day: the trigger holds the time of day, as in
/// TickTick (`PT9H` is 9:00 that day, `-PT15H` is 9:00 the day before).
const allDayReminderPresets = [
  ReminderPreset('On the day, 9:00', ReminderTrigger(seconds: 9 * 3600)),
  ReminderPreset('1 day before, 9:00', ReminderTrigger(seconds: -15 * 3600)),
  ReminderPreset('2 days before, 9:00', ReminderTrigger(days: -1, seconds: -15 * 3600)),
];
