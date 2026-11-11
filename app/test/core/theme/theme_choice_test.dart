import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/theme/theme_choice.dart';

void main() {
  test('each choice is read back from the text it is stored as', () {
    for (final c in ThemeChoice.values) {
      expect(ThemeChoice.parse(c.value), c);
    }
  });

  test('nothing stored, or something unknown, means follow the system', () {
    expect(ThemeChoice.parse(null), ThemeChoice.system);
    expect(ThemeChoice.parse(''), ThemeChoice.system);
    expect(ThemeChoice.parse('sepia'), ThemeChoice.system);
  });
}
