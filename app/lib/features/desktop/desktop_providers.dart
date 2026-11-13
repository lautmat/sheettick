import 'dart:async';

import 'package:flutter/widgets.dart' show GlobalKey, NavigatorState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_shell.dart';
import '../../core/sync/sync_controller.dart';
import '../lists/lists_providers.dart';

/// The Windows shell (tray, hotkey, hide to tray). `main` replaces it with the real one on Windows; everywhere else, and
/// in tests, there is none.
final desktopShellProvider = Provider<DesktopShell>((ref) => const NoopDesktopShell());

/// The key of the app's navigator, so the hotkey can close the pages that are open on top of the list.
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) => GlobalKey<NavigatorState>());

/// Asks the quick-add bar to take the keyboard focus. The hotkey raises a request; the bar answers it as soon as it is on
/// screen (it may have to be brought there first), and only once.
class QuickAddRequest extends Notifier<int> {
  var _answered = 0;

  @override
  int build() => 0;

  void request() => state++;

  /// True once for each request.
  bool take() {
    if (_answered == state) return false;
    _answered = state;
    return true;
  }
}

final quickAddRequestProvider = NotifierProvider<QuickAddRequest, int>(QuickAddRequest.new);

/// The global hotkey: bring the window to the front on the list the add bar belongs to (a smart list has none, so the
/// list picked before it, or the Inbox, comes back), close any page open on top of it, and focus the add bar.
Future<void> openQuickAdd(Ref ref, DesktopShell shell) async {
  await shell.showWindow();
  ref.read(navigatorKeyProvider).currentState?.popUntil((route) => route.isFirst);
  if (ref.read(selectedSmartListProvider) != null) ref.read(selectedSmartListProvider.notifier).select(null);
  ref.read(quickAddRequestProvider.notifier).request();
}

/// Starts the shell once and wires its events to the app: Open, Sync now, Quit and the hotkey. Watched by the app.
final desktopBindingProvider = Provider<void>((ref) {
  final shell = ref.watch(desktopShellProvider);
  if (!shell.isAvailable) return;
  unawaited(
    shell.start(
      DesktopCallbacks(
        onOpen: () => unawaited(shell.showWindow()),
        onSyncNow: () => unawaited(ref.read(syncControllerProvider.notifier).sync()),
        onQuickAdd: () => unawaited(openQuickAdd(ref, shell)),
        onQuit: () => unawaited(shell.quit()),
      ),
    ),
  );
  ref.onDispose(() => unawaited(shell.dispose()));
});

/// Whether the app starts when the user signs in to Windows, read from the system and changed through the shell.
class StartWithWindows extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(desktopShellProvider).startWithWindows();

  /// Turns it on or off and shows what the system now says. Throws if the system refused.
  Future<void> set(bool on) async {
    final shell = ref.read(desktopShellProvider);
    await shell.setStartWithWindows(on);
    state = AsyncData(await shell.startWithWindows());
  }
}

final startWithWindowsProvider = AsyncNotifierProvider<StartWithWindows, bool>(StartWithWindows.new);
