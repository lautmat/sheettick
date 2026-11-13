import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_shell.dart';
import 'hotkey_config.dart';
import 'startup_entry.dart';

const _trayIcon = 'assets/tray_icon.ico';
const _openKey = 'open';
const _syncKey = 'sync';
const _quitKey = 'quit';

/// The Windows shell, over `window_manager`, `tray_manager` and `hotkey_manager`.
///
/// - Closing the window hides it (the app keeps running, so reminders still fire); only the tray's Quit closes the app.
/// - The tray icon opens the window on a click; the right click shows Open, Sync now and Quit.
/// - The hotkey (see [buildQuickAddHotKey]) works while the window is hidden.
///
/// A failure in the tray or the hotkey never stops the app: it is logged, and the rest still works.
class PlatformDesktopShell with TrayListener, WindowListener implements DesktopShell {
  PlatformDesktopShell({required this.startHidden, StartupEntry? startup})
    : _startup = startup ?? StartupEntry(executablePath: Platform.resolvedExecutable);

  /// Started by Windows at sign-in: the window stays in the tray instead of opening.
  final bool startHidden;
  final StartupEntry _startup;

  DesktopCallbacks? _callbacks;
  HotKey? _hotKey;
  var _quitting = false;

  /// Sets the window up. Call before `runApp`.
  Future<void> prepare() async {
    await windowManager.ensureInitialized();
    // Closing the window now reports onWindowClose instead of closing; it is hidden there.
    await windowManager.setPreventClose(true);
    // Not awaited: it waits for the window to be ready, and the first frame needs runApp to have started.
    windowManager.waitUntilReadyToShow(const WindowOptions(skipTaskbar: false), () async {
      if (startHidden) {
        // Windows shows a new window by itself; take it away again at once.
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }

  @override
  bool get isAvailable => true;

  @override
  Future<void> start(DesktopCallbacks callbacks) async {
    _callbacks = callbacks;
    windowManager.addListener(this);
    try {
      await trayManager.setIcon(_trayIcon);
      await trayManager.setToolTip('SheetTick (quick add: $kQuickAddHotKeyLabel)');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: _openKey, label: 'Open'),
            MenuItem(key: _syncKey, label: 'Sync now'),
            MenuItem.separator(),
            MenuItem(key: _quitKey, label: 'Quit'),
          ],
        ),
      );
      trayManager.addListener(this);
    } catch (e) {
      debugPrint('The tray icon is not available: $e');
    }
    try {
      await hotKeyManager.unregisterAll();
      final hotKey = buildQuickAddHotKey();
      _hotKey = hotKey;
      await hotKeyManager.register(hotKey, keyDownHandler: (_) => _callbacks?.onQuickAdd());
    } catch (e) {
      debugPrint('The quick-add hotkey is not available: $e');
    }
  }

  @override
  Future<void> showWindow() async {
    try {
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Could not show the window: $e');
    }
  }

  @override
  Future<void> quit() async {
    _quitting = true;
    try {
      await hotKeyManager.unregisterAll();
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (e) {
      debugPrint('Could not close cleanly: $e');
    } finally {
      exit(0);
    }
  }

  @override
  Future<bool> startWithWindows() => _startup.isEnabled();

  @override
  Future<void> setStartWithWindows(bool on) => _startup.setEnabled(on);

  @override
  Future<void> dispose() async {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    final hotKey = _hotKey;
    if (hotKey != null && !_quitting) {
      try {
        await hotKeyManager.unregister(hotKey);
      } catch (_) {}
    }
  }

  // ---- Window ----------------------------------------------------------------------------------------------------

  @override
  void onWindowClose() {
    // The close button hides the window to the tray. Quit is in the tray menu.
    if (!_quitting) windowManager.hide();
  }

  // ---- Tray ------------------------------------------------------------------------------------------------------

  @override
  void onTrayIconMouseDown() => _callbacks?.onOpen();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _openKey:
        _callbacks?.onOpen();
      case _syncKey:
        _callbacks?.onSyncNow();
      case _quitKey:
        _callbacks?.onQuit();
    }
  }
}
