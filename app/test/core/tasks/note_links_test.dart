import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/tasks/note_links.dart';

void main() {
  test('web and mail addresses open', () {
    expect(safeNoteLink('https://example.com/a?b=1#c').toString(), 'https://example.com/a?b=1#c');
    expect(safeNoteLink('http://example.com').toString(), 'http://example.com');
    expect(safeNoteLink('HTTPS://Example.com').toString(), 'https://example.com');
    expect(safeNoteLink('mailto:me@example.com').toString(), 'mailto:me@example.com');
    expect(safeNoteLink('  https://example.com  ').toString(), 'https://example.com');
  });

  test('a bare www address is taken as https', () {
    expect(safeNoteLink('www.example.com/x').toString(), 'https://www.example.com/x');
  });

  test('everything else is ignored', () {
    for (final h in [
      null,
      '',
      '   ',
      'javascript:alert(1)',
      'JavaScript:alert(1)',
      'file:///etc/passwd',
      'content://com.android.contacts/1',
      'intent://scan/#Intent;scheme=zxing;end',
      'tel:+33123456789',
      'sms:+33123456789',
      '/relative/path',
      'example.com',
      '#heading',
      'https://',
      'mailto:',
      'data:text/html,<b>x</b>',
    ]) {
      expect(safeNoteLink(h), isNull, reason: '$h');
    }
  });
}
