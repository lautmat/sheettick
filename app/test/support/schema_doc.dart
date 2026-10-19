import 'dart:io';

/// Reads `docs/sheet-schema.md`, the canonical schema, so tests can check code against it.
/// Tests run with the `app/` directory as the working directory.
class SchemaDoc {
  SchemaDoc() : _text = File('../docs/sheet-schema.md').readAsStringSync();

  final String _text;

  /// The body of the section whose heading line starts with `### [heading]`.
  String _section(String heading) {
    final match = RegExp(
      '^### ${RegExp.escape(heading)}[^\\n]*\\n(.*?)(?=^##|(?![\\s\\S]))',
      multiLine: true,
      dotAll: true,
    ).firstMatch(_text);
    if (match == null) throw StateError('Section "### $heading" not found in docs/sheet-schema.md');
    return match.group(1)!;
  }

  /// Column names the doc declares for [heading]: the first cell of each table row, or the backticked names
  /// of the one-line listing (ignoring parenthesised value lists and the "+ sync columns" tail).
  List<String> columns(String heading) {
    final section = _section(heading);
    if (section.contains('| Column |')) {
      return [
        for (final line in section.split('\n'))
          if (RegExp(r'^\| `(\w+)` \|').firstMatch(line) case final m?) m.group(1)!,
      ];
    }
    var listing = section.contains('columns:')
        ? section.split('columns:').last.split('. ').first
        : section.split('+ sync columns').first;
    listing = listing.replaceAll(RegExp(r'\([^)]*\)'), '');
    return [for (final m in RegExp(r'`(\w+)`').allMatches(listing)) m.group(1)!];
  }

  /// Entity columns of the tab, without the shared sync columns.
  List<String> tabColumns(String tab) => columns('`$tab`');

  /// The shared sync columns.
  List<String> get syncColumns => columns('Sync columns');

  /// The number after "Schema version:" at the top of the doc.
  int get schemaVersion => int.parse(RegExp(r'Schema version: \*\*(\d+)\*\*').firstMatch(_text)!.group(1)!);

  /// Names of the tabs documented as `### \`name\``, in order (includes `View`, which has no columns).
  List<String> get tabNames => [
    for (final m in RegExp(r'^### `(\w+)`', multiLine: true).allMatches(_text)) m.group(1)!,
  ];
}
