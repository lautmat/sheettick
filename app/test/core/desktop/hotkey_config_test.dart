import 'package:flutter/services.dart' show PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:sheettick/core/desktop/hotkey_config.dart';

void main() {
  test('the quick-add hotkey is Ctrl+Alt+N and works system wide', () {
    final hotKey = buildQuickAddHotKey();
    expect(hotKey.key, PhysicalKeyboardKey.keyN);
    expect(hotKey.modifiers, unorderedEquals([HotKeyModifier.control, HotKeyModifier.alt]));
    expect(hotKey.scope, HotKeyScope.system);
    expect(kQuickAddHotKeyLabel, 'Ctrl+Alt+N');
  });
}
