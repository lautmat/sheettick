/// Full-text search over task title and content.
///
/// A standalone FTS5 table (not external-content): `tasks` has a text primary key, so its implicit rowid is
/// not stable across VACUUM and cannot back an external-content index. `id` is stored UNINDEXED and used to
/// join back to `tasks`.
const ftsStatements = <String>[
  '''
CREATE VIRTUAL TABLE tasks_fts USING fts5(
  id UNINDEXED,
  title,
  content,
  tokenize = 'unicode61 remove_diacritics 2'
)''',
  '''
CREATE TRIGGER tasks_fts_ai AFTER INSERT ON tasks BEGIN
  INSERT INTO tasks_fts (id, title, content) VALUES (new.id, new.title, new.content);
END''',
  '''
CREATE TRIGGER tasks_fts_ad AFTER DELETE ON tasks BEGIN
  DELETE FROM tasks_fts WHERE id = old.id;
END''',
  '''
CREATE TRIGGER tasks_fts_au AFTER UPDATE OF id, title, content ON tasks BEGIN
  DELETE FROM tasks_fts WHERE id = old.id;
  INSERT INTO tasks_fts (id, title, content) VALUES (new.id, new.title, new.content);
END''',
];

final _hasWordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Turns free user text into a safe FTS5 query: every word becomes a quoted prefix term, so punctuation
/// and operators typed by the user can never cause a syntax error. Returns null when nothing searchable
/// is left.
String? toFtsQuery(String input) {
  final terms = input
      .split(RegExp(r'\s+'))
      .where(_hasWordChar.hasMatch)
      .map((w) => '"${w.replaceAll('"', '""')}"*')
      .toList();
  return terms.isEmpty ? null : terms.join(' ');
}
