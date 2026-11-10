import 'dart:convert';

import 'package:rrule/rrule.dart';

import 'task_dates.dart';

/// Which moment a repeating task counts from (`repeat_from` in `docs/sheet-schema.md`).
enum RepeatFrom {
  /// The next one follows the schedule: the next occurrence of the rule after the task's own date.
  due('DUE'),

  /// The next one follows the day it was finished: "every 3 days" means 3 days after completing it.
  completion('COMPLETION');

  const RepeatFrom(this.value);

  /// The value stored in the `repeat_from` cell.
  final String value;

  /// A blank or unknown cell counts as [due].
  static RepeatFrom parse(String? text) =>
      text?.trim().toUpperCase() == completion.value ? RepeatFrom.completion : RepeatFrom.due;
}

/// A repeating task's next round: its dates, and the rule it carries on with.
class NextOccurrence {
  const NextOccurrence({required this.dates, required this.rrule});

  final TaskDates dates;

  /// The rule text for the new task. A rule with `COUNT` has one fewer left.
  final String rrule;
}

/// The rule in [text] (an RFC 5545 `RRULE`, with or without the `RRULE:` label, in any case), or null when it cannot be
/// read.
RecurrenceRule? parseRrule(String? text) {
  final trimmed = (text?.trim() ?? '').toUpperCase();
  if (trimmed.isEmpty) return null;
  try {
    return RecurrenceRule.fromString(trimmed.startsWith('RRULE:') ? trimmed : 'RRULE:$trimmed');
  } catch (_) {
    // The parser reports some malformed text as a FormatException and some as a RangeError: any failure is "no rule".
    return null;
  }
}

/// The days named in an `ex_dates` cell (a JSON array of `YYYY-MM-DD` or ISO date-times), as `YYYY-MM-DD`. Unreadable
/// entries are ignored.
Set<String> exDays(String? json) {
  if (json == null || json.trim().isEmpty) return const {};
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const {};
  }
  if (decoded is! List) return const {};
  return {
    for (final item in decoded)
      if (item is String && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(item.trim())) item.trim().substring(0, 10),
  };
}

String _day(DateTime wall) =>
    '${wall.year.toString().padLeft(4, '0')}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';

/// How many occurrences the search looks at before it gives up (a rule whose every day is in `ex_dates`).
const _maxLooked = 2000;

/// The next round of a repeating task finished at [completedWall] (the wall-clock reading where the dates are shown), or
/// null when the series is over: the rule cannot be read, it has no occurrence left, the task has no date, or it ran out
/// of `COUNT`.
///
/// The task's own moment is its due, or its start when it has no due. With [RepeatFrom.due] the next one is the next
/// occurrence of the rule after that moment and after [completedWall], so a task finished late does not come back
/// already overdue many times over. With [RepeatFrom.completion] the rule is counted from the day it was finished
/// (at the same time of day). Occurrences on a day in [exDates] are skipped. The start keeps its distance from the due.
NextOccurrence? nextOccurrence({
  required String? rrule,
  required RepeatFrom repeatFrom,
  String? exDates,
  required TaskDates dates,
  required DateTime completedWall,
}) {
  final rule = parseRrule(rrule);
  if (rule == null) return null;
  final due = dates.due;
  final start = dates.start;
  final anchor = due ?? start;
  if (anchor == null) return null;
  final left = rule.count;
  if (left != null && left <= 1) return null;

  final completedDay = dayOf(completedWall);
  final DateTime from;
  final DateTime after;
  if (repeatFrom == RepeatFrom.completion) {
    from = dates.allDay ? completedDay : DateTime.utc(completedDay.year, completedDay.month, completedDay.day, anchor.hour, anchor.minute);
    after = from;
  } else {
    from = anchor;
    final completed = dates.allDay ? completedDay : DateTime.utc(completedWall.year, completedWall.month, completedWall.day, completedWall.hour, completedWall.minute);
    after = completed.isAfter(anchor) ? completed : anchor;
  }

  final skipped = exDays(exDates);
  DateTime? next;
  var looked = 0;
  for (final candidate in rule.getInstances(start: from, after: after)) {
    if (++looked > _maxLooked) break;
    if (skipped.contains(_day(candidate))) continue;
    next = candidate;
    break;
  }
  if (next == null) return null;

  final shift = next.difference(anchor);
  final nextDates = TaskDates(
    start: start?.add(shift),
    due: due?.add(shift),
    allDay: dates.allDay,
    zone: dates.zone,
  );
  var text = rrule!.trim();
  if (left != null) text = text.replaceFirst(RegExp(r'COUNT=\d+', caseSensitive: false), 'COUNT=${left - 1}');
  return NextOccurrence(dates: nextDates, rrule: text);
}
