import 'quick_add.dart';

/// Edits to quick-add text that a button can make, so the field's text stays the one thing that says what a task will be
/// and [parseQuickAdd] stays the one thing that reads it.
///
/// Each edit asks the parser where the part it is changing sits in the text (see [QuickAddResult.spans]), then puts its
/// token there, or at the end of the text when the text has no such part. Everything else in the text, including the
/// title, is left exactly as typed. The tokens are the English ones; the parser reads those whatever else is typed.
///
/// [now] and [zone] are the ones [parseQuickAdd] takes: "today" and a bare weekday depend on them, so they decide
/// what counts as a day word.

/// [text] with the day set to the word [day] (`today`, `tomorrow`, or any other the parser reads), replacing the day the
/// text names; a time of day stays. A null [day] takes the day out.
String setQuickAddDay(String text, String? day, {required DateTime now, String? zone}) =>
    _rewrite(text, QuickAddPart.day, day, now, zone);

/// [text] with the priority set: `!high`, `!medium` or `!low` for the `priority` column values 5, 3 and 1, and no
/// priority token for anything else (the task then has the default).
String setQuickAddPriority(String text, int? priority, {required DateTime now, String? zone}) => _rewrite(
  text,
  QuickAddPart.priority,
  switch (priority) {
    5 => '!high',
    3 => '!medium',
    1 => '!low',
    _ => null,
  },
  now,
  zone,
);

/// [text] with the list set to [name], or with the list taken out when [name] is null or cannot be written in the
/// text (see [quickAddListToken]).
String setQuickAddList(String text, String? name, {required DateTime now, String? zone}) =>
    _rewrite(text, QuickAddPart.list, name == null ? null : quickAddListToken(name), now, zone);

/// [text] with the tag [name] added, or taken out when the text already has it (in any case). Text that cannot carry
/// the tag (see [quickAddTagToken]) is returned as it is.
String toggleQuickAddTag(String text, String name, {required DateTime now, String? zone}) {
  final token = quickAddTagToken(name);
  if (token == null) return text;
  final spans = parseQuickAdd(text, now: now, zone: zone, allowEmptyTitle: true).spans[QuickAddPart.tag] ?? const [];
  final same = [for (final s in spans) if (text.substring(s.start, s.end).toLowerCase() == token.toLowerCase()) s];
  if (same.isEmpty) return _append(text, token);
  return _replace(text, same, null);
}

/// How the text names the list [name]: `^name`, or `^"a name"` when it has spaces or other characters a bare word cannot
/// hold. Null when the name cannot be written at all (it is blank, or has a double quote in it).
String? quickAddListToken(String name) {
  final clean = name.trim();
  if (clean.isEmpty || clean.contains('"')) return null;
  return _bareWord.hasMatch(clean) ? '^$clean' : '^"$clean"';
}

/// How the text names the tag [name]: `#name`. Null when the name cannot be written (a tag with a space in it, say: the
/// text reads a tag up to the next space).
String? quickAddTagToken(String name) {
  final clean = name.trim();
  return _bareWord.hasMatch(clean) ? '#$clean' : null;
}

final _bareWord = RegExp(r'^[\p{L}\p{N}_\-]+$', unicode: true);

String _rewrite(String text, QuickAddPart part, String? token, DateTime now, String? zone) {
  final spans = parseQuickAdd(text, now: now, zone: zone, allowEmptyTitle: true).spans[part] ?? const [];
  if (spans.isEmpty) return token == null ? text : _append(text, token);
  return _replace(text, spans, token);
}

/// [text] with [token] at the end, after a space when the text does not end in one. On blank text the token is followed
/// by a space, so the next thing typed is a new word.
String _append(String text, String token) {
  if (text.trim().isEmpty) return '$token ';
  return _isSpace(text[text.length - 1]) ? '$text$token' : '$text $token';
}

/// [text] with the first of [spans] (in text order) replaced by [token] and the rest taken out. A part taken out takes
/// one space with it, so no double space is left where it was. With a null [token] all of them are taken out.
String _replace(String text, List<QuickAddSpan> spans, String? token) {
  var out = text;
  // From the end, so the positions of the spans still to do are not moved.
  for (var i = spans.length - 1; i >= 0; i--) {
    var start = spans[i].start;
    var end = spans[i].end;
    if (i == 0 && token != null) {
      out = out.replaceRange(start, end, token);
      continue;
    }
    if (start > 0 && _isSpace(out[start - 1])) {
      start--;
    } else if (end < out.length && _isSpace(out[end])) {
      end++;
    }
    out = out.replaceRange(start, end, '');
  }
  return out;
}

bool _isSpace(String ch) => ch.trim().isEmpty;
