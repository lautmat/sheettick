/// UTC ISO 8601 with a `Z` suffix and no fractional seconds, the timestamp format of the Sheet
/// (`2026-10-19T13:05:00Z`).
String formatUtc(DateTime time) => time.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
