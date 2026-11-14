import 'package:flutter/services.dart' show PhysicalKeyboardKey;
import 'package:hotkey_manager/hotkey_manager.dart';

/// The global hotkey that opens quick add from anywhere in Windows. It is the only place the combination is set: change
/// it here (Ctrl+Alt+N today). If another program already owns the combination, the app still runs and the hotkey just
/// does nothing; the tray menu is the way in then.
HotKey buildQuickAddHotKey() => HotKey(
  key: PhysicalKeyboardKey.keyN,
  modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
  scope: HotKeyScope.system,
);

/// The combination as text, for the tray tooltip and the settings menu.
const kQuickAddHotKeyLabel = 'Ctrl+Alt+N';
