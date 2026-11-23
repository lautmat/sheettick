import 'dart:ui' show VoidCallback;

/// What the desktop shell (tray icon, global hotkey, hide-to-tray) tells the app.
class DesktopCallbacks {
  const DesktopCallbacks({
    required this.onOpen,
    required this.onSyncNow,
    required this.onQuickAdd,
    required this.onQuit,
  });

  /// "Open" in the tray menu, or a click on the tray icon: bring the window back.
  final VoidCallback onOpen;

  /// "Sync now" in the tray menu.
  final VoidCallback onSyncNow;

  /// The global quick-add hotkey was pressed.
  final VoidCallback onQuickAdd;

  /// "Quit" in the tray menu: really close the app.
  final VoidCallback onQuit;
}

/// The Windows desktop shell around the app: it keeps running in the tray when the window is closed (so reminders still
/// fire), has a tray menu, a global hotkey for quick add, and a "Start with Windows" setting. Everything that touches the
/// platform is behind this interface, so the app logic runs in tests with [NoopDesktopShell] or a fake.
abstract interface class DesktopShell {
  /// Whether this platform has a tray and hotkey at all. False on Android and in tests.
  bool get isAvailable;

  /// Starts the tray icon, the hotkey and the close-to-tray behaviour, and reports their events to [callbacks].
  Future<void> start(DesktopCallbacks callbacks);

  /// Brings the window to the front, restoring it if it was hidden in the tray or minimised.
  Future<void> showWindow();

  /// Really closes the app: removes the tray icon and the hotkey, then exits.
  Future<void> quit();

  /// Whether the app starts when the user signs in to Windows.
  Future<bool> startWithWindows();

  Future<void> setStartWithWindows(bool on);

  Future<void> dispose();
}

/// The shell where there is none (Android, tests).
class NoopDesktopShell implements DesktopShell {
  const NoopDesktopShell();

  @override
  bool get isAvailable => false;

  @override
  Future<void> start(DesktopCallbacks callbacks) async {}

  @override
  Future<void> showWindow() async {}

  @override
  Future<void> quit() async {}

  @override
  Future<bool> startWithWindows() async => false;

  @override
  Future<void> setStartWithWindows(bool on) async {}

  @override
  Future<void> dispose() async {}
}

/// The argument the app is started with when Windows starts it at sign-in: it then stays in the tray instead of
/// opening its window.
const kStartHiddenArgument = '--minimized';
