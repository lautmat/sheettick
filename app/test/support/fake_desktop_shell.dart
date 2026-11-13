import 'package:sheettick/core/desktop/desktop_shell.dart';

/// A [DesktopShell] that records what the app asks of it and lets a test press the tray and the hotkey.
class FakeDesktopShell implements DesktopShell {
  FakeDesktopShell({this.startup = false, this.failStartupChange});

  DesktopCallbacks? callbacks;
  int starts = 0;
  int shows = 0;
  int quits = 0;
  int disposes = 0;

  bool startup;

  /// Thrown by [setStartWithWindows] when set, as when the system refuses.
  Object? failStartupChange;

  @override
  bool get isAvailable => true;

  @override
  Future<void> start(DesktopCallbacks callbacks) async {
    starts++;
    this.callbacks = callbacks;
  }

  @override
  Future<void> showWindow() async => shows++;

  @override
  Future<void> quit() async => quits++;

  @override
  Future<bool> startWithWindows() async => startup;

  @override
  Future<void> setStartWithWindows(bool on) async {
    if (failStartupChange != null) throw failStartupChange!;
    startup = on;
  }

  @override
  Future<void> dispose() async => disposes++;
}
