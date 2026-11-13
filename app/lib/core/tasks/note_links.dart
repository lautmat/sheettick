/// The link in a note that is safe to open, or null.
///
/// Notes come from the Sheet, so a link in them is whatever someone typed: only web addresses and mail addresses are
/// opened. Anything else (`file:`, `javascript:`, an app's own scheme, a relative path) is ignored. A bare `www.` address
/// is taken as `https://`.
Uri? safeNoteLink(String? href) {
  var text = (href ?? '').trim();
  if (text.isEmpty) return null;
  if (RegExp(r'^www\.', caseSensitive: false).hasMatch(text)) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) return null;
  switch (uri.scheme.toLowerCase()) {
    case 'http':
    case 'https':
      return uri.host.isEmpty ? null : uri;
    case 'mailto':
      return uri.path.isEmpty ? null : uri;
    default:
      return null;
  }
}
