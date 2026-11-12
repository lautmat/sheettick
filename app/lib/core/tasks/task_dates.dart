// latest_all, not latest: `latest` leaves out the link names (Africa/Kampala, Asia/Calcutta, Europe/Kiev), which tasks
// and phones do carry, and a zone that is not found reads as the platform's zone without a word.
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tzdb;

var _zonesLoaded = false;

/// The zone called [name], an IANA name such as `Europe/Paris`, or null when [name] is empty or not a known zone.
/// The zone database is loaded on first use.
tzdb.Location? locationOf(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (!_zonesLoaded) {
    tzdata.initializeTimeZones();
    _zonesLoaded = true;
  }
  try {
    return tzdb.getLocation(trimmed);
  } on tzdb.LocationNotFoundException {
    return null;
  }
}

/// The calendar day of [wall] with no time, held as UTC midnight so that counting days is never shifted by a DST
/// change.
DateTime dayOf(DateTime wall) => DateTime.utc(wall.year, wall.month, wall.day);

/// Whole calendar days from the day of [from] to the day of [to]; negative when [to] is earlier.
int daysBetween(DateTime from, DateTime to) => dayOf(to).difference(dayOf(from)).inDays;

/// What a list says about when a task is due: the date it shows and how it stands against now.
class DateHeadline {
  const DateHeadline({
    required this.wall,
    required this.today,
    required this.timed,
    required this.isDue,
    required this.days,
    required this.overdue,
  });

  /// The due moment, or the start when the task has no due.
  final DateTime wall;

  /// Today's wall-clock reading where the dates are shown.
  final DateTime today;

  /// False for an all-day task: only the day of [wall] is meaningful.
  final bool timed;

  /// False when [wall] is the start because the task has no due.
  final bool isDue;

  /// Calendar days from today to [wall]: 0 is today, -1 yesterday.
  final int days;

  /// A due day that has gone by, or a due time that has passed. Never true for a start.
  final bool overdue;
}

/// A task's start and due, as the `start_at`, `due_at`, `all_day` and `tz` columns hold them (see
/// `docs/sheet-schema.md`).
///
/// A moment is a wall-clock reading, the year to the minute, held in a UTC [DateTime] only as a container: its
/// `isUtc` flag means nothing. Start and due share `all_day` and `tz`, as the columns do, so both are all-day dates or
/// both are timed. An all-day value is a calendar day and has no zone. A timed value is stored with its offset and the
/// IANA zone it was set in, so its instant is exact, and it is read back in [zone], the zone of the device showing
/// it. A timed value with no `tz` is floating: it reads the same on every device, whatever offset was written.
///
/// Reading never throws. Text that is not a date reads as no date, and the cell is left alone until the user edits it.
class TaskDates {
  const TaskDates({this.start, this.due, this.allDay = false, this.zone});

  /// Reads the columns of a task row. [deviceZone] is the IANA name of the zone to show times in; null shows them in
  /// the zone the platform reports.
  factory TaskDates.fromRow({String? startAt, String? dueAt, bool allDay = false, String? tz, String? deviceZone}) {
    final start = _parse(startAt);
    final due = _parse(dueAt);
    // A date with no time in a row that says timed is an all-day date: the text is what the user can see in the Sheet.
    final allDayRow = allDay || (start?.dateOnly ?? false) || (due?.dateOnly ?? false);
    if (allDayRow) {
      // The days have no zone of their own, but "today" is read where the device is, so the zone is kept for that.
      return TaskDates(
        start: start == null ? null : dayOf(start.wall),
        due: due == null ? null : dayOf(due.wall),
        allDay: true,
        zone: locationOf(deviceZone)?.name,
      );
    }
    final writer = locationOf(tz);
    final shown = locationOf(deviceZone);
    return TaskDates(
      start: start == null ? null : _shown(start, writer, shown),
      due: due == null ? null : _shown(due, writer, shown),
      zone: shown?.name,
    );
  }

  /// The start, or null.
  final DateTime? start;

  /// The due, or null.
  final DateTime? due;

  /// Both moments are calendar days with no time.
  final bool allDay;

  /// The IANA zone the times are in, or for all-day dates the zone "today" is read in; null when the device's zone is
  /// not known.
  final String? zone;

  bool get isEmpty => start == null && due == null;

  /// This with [start] set. A due that would fall before it moves to it, so the two never run backwards.
  TaskDates withStart(DateTime? start) {
    final due = this.due;
    return TaskDates(
      start: start,
      due: start != null && due != null && due.isBefore(start) ? start : due,
      allDay: allDay,
      zone: zone,
    );
  }

  /// This with [due] set. A start that would fall after it moves to it.
  TaskDates withDue(DateTime? due) {
    final start = this.start;
    return TaskDates(
      start: due != null && start != null && start.isAfter(due) ? due : start,
      due: due,
      allDay: allDay,
      zone: zone,
    );
  }

  /// This as all-day dates (the time of day dropped) or as timed ones (a moment with no time gets [defaultHour]:00).
  TaskDates withAllDay(bool allDay, {int defaultHour = 9}) {
    if (allDay == this.allDay) return this;
    DateTime? convert(DateTime? m) {
      if (m == null) return null;
      return allDay ? dayOf(m) : DateTime.utc(m.year, m.month, m.day, defaultHour);
    }

    return TaskDates(start: convert(start), due: convert(due), allDay: allDay, zone: zone);
  }

  /// The values to write to the row. No dates at all clears the four columns.
  ///
  /// All-day dates are written as `YYYY-MM-DD` with `all_day` true and no `tz`. Timed ones are written as ISO 8601
  /// with the offset [zone] has at that moment, and `tz` is [zone]. With no known zone the offset is the platform's and
  /// `tz` is empty, which makes the value floating.
  Map<String, Object?> toFields() {
    if (isEmpty) return {'start_at': null, 'due_at': null, 'all_day': false, 'tz': null};
    if (allDay) {
      return {
        'start_at': start == null ? null : _dayText(start!),
        'due_at': due == null ? null : _dayText(due!),
        'all_day': true,
        'tz': null,
      };
    }
    final location = locationOf(zone);
    return {
      'start_at': _timed(start, location),
      'due_at': _timed(due, location),
      'all_day': false,
      'tz': location?.name,
    };
  }

  /// The wall-clock reading of the instant [now] where these dates are shown.
  DateTime wallOf(DateTime now) => _wall(now.toUtc(), locationOf(zone));

  /// The date a list row shows for [now]: the due, else the start. Null when there is neither.
  DateHeadline? headline(DateTime now) {
    final isDue = due != null;
    final wall = due ?? start;
    if (wall == null) return null;
    final today = wallOf(now);
    final days = daysBetween(today, wall);
    final overdue = isDue && (allDay ? days < 0 : wall.isBefore(today));
    return DateHeadline(wall: wall, today: today, timed: !allDay, isDue: isDue, days: days, overdue: overdue);
  }

  @override
  bool operator ==(Object other) =>
      other is TaskDates &&
      other.start == start &&
      other.due == due &&
      other.allDay == allDay &&
      other.zone == zone;

  @override
  int get hashCode => Object.hash(start, due, allDay, zone);

  @override
  String toString() => 'TaskDates(start: $start, due: $due, allDay: $allDay, zone: $zone)';
}

/// A cell read as a date: its wall-clock fields, the offset it was written with, and whether it had no time.
typedef _Parsed = ({DateTime wall, int? offsetMinutes, bool dateOnly});

final _dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _dateTime = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?\s*(Z|[+-]\d{2}(?::?\d{2})?)?$',
);

/// Reads the text of a `start_at` or `due_at` cell. Null for a blank cell and for text that is not a real date.
_Parsed? _parse(String? text) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) return null;
  final day = _dateOnly.firstMatch(value);
  if (day != null) {
    final wall = _wallOrNull(day.group(1)!, day.group(2)!, day.group(3)!, '0', '0');
    return wall == null ? null : (wall: wall, offsetMinutes: null, dateOnly: true);
  }
  final m = _dateTime.firstMatch(value);
  if (m == null) return null;
  final wall = _wallOrNull(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!, m.group(5)!, m.group(6));
  if (wall == null) return null;
  return (wall: wall, offsetMinutes: _offset(m.group(7)), dateOnly: false);
}

/// The wall clock for the digits given, or null when they are not a real moment (month 13, 30 February, hour 25,
/// second 99). The seconds are checked but not kept: a moment is held to the minute.
DateTime? _wallOrNull(String y, String mo, String d, String h, String mi, [String? s]) {
  final year = int.parse(y), month = int.parse(mo), dayOfMonth = int.parse(d);
  final hour = int.parse(h), minute = int.parse(mi), second = s == null ? 0 : int.parse(s);
  final wall = DateTime.utc(year, month, dayOfMonth, hour, minute);
  final real =
      wall.year == year && wall.month == month && wall.day == dayOfMonth && hour < 24 && minute < 60 && second < 60;
  return real ? wall : null;
}

/// Minutes east of UTC for `Z`, `+01:00`, `+0100` or `+01`; null when the text has no offset.
int? _offset(String? text) {
  if (text == null) return null;
  if (text == 'Z') return 0;
  final sign = text.startsWith('-') ? -1 : 1;
  final digits = text.substring(1).replaceAll(':', '');
  final hours = int.parse(digits.substring(0, 2));
  final minutes = digits.length >= 4 ? int.parse(digits.substring(2, 4)) : 0;
  return sign * (hours * 60 + minutes);
}

/// [p] as a wall clock in [shown], given that it was written in [writer]. Floating (no writer zone) is the wall clock
/// as written.
DateTime _shown(_Parsed p, tzdb.Location? writer, tzdb.Location? shown) {
  if (writer == null) return p.wall;
  final instant = p.offsetMinutes != null
      ? p.wall.subtract(Duration(minutes: p.offsetMinutes!))
      : tzdb.TZDateTime(writer, p.wall.year, p.wall.month, p.wall.day, p.wall.hour, p.wall.minute).toUtc();
  return _wall(instant, shown);
}

/// The wall clock of [instant] in [zone], or in the platform's zone when [zone] is null.
DateTime _wall(DateTime instant, tzdb.Location? zone) {
  final local = zone == null ? instant.toLocal() : tzdb.TZDateTime.from(instant, zone);
  return DateTime.utc(local.year, local.month, local.day, local.hour, local.minute);
}

String _two(int n) => n.toString().padLeft(2, '0');

String _dayText(DateTime wall) => '${wall.year.toString().padLeft(4, '0')}-${_two(wall.month)}-${_two(wall.day)}';

/// [wall] as `YYYY-MM-DDTHH:MM:00+HH:MM`, the offset being the one [zone] has at that moment. Null for no moment.
String? _timed(DateTime? wall, tzdb.Location? zone) {
  if (wall == null) return null;
  final Duration offset = zone == null
      ? DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute).timeZoneOffset
      : tzdb.TZDateTime(zone, wall.year, wall.month, wall.day, wall.hour, wall.minute).timeZoneOffset;
  final minutes = offset.inMinutes;
  final sign = minutes < 0 ? '-' : '+';
  final abs = minutes.abs();
  return '${_dayText(wall)}T${_two(wall.hour)}:${_two(wall.minute)}:00$sign${_two(abs ~/ 60)}:${_two(abs % 60)}';
}
