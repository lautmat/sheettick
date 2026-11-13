import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/hotkey_config.dart';
import 'desktop_providers.dart';

/// App bar button for the Windows settings: Start with Windows, and a reminder of the quick-add hotkey. Not shown where
/// there is no desktop shell (Android).
class DesktopMenu extends ConsumerWidget {
  const DesktopMenu({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(startWithWindowsProvider.notifier).set(on);
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(desktopShellProvider).isAvailable) return const SizedBox.shrink();
    final startup = ref.watch(startWithWindowsProvider).value ?? false;
    return PopupMenuButton<bool>(
      key: const Key('desktopMenu'),
      tooltip: 'Windows',
      icon: const Icon(Icons.desktop_windows_outlined),
      onSelected: (on) => _toggle(context, ref, on),
      itemBuilder: (_) => [
        CheckedPopupMenuItem<bool>(
          key: const Key('startWithWindows'),
          value: !startup,
          checked: startup,
          child: const Text('Start with Windows'),
        ),
        const PopupMenuItem<bool>(
          enabled: false,
          child: Text('Quick add from anywhere: $kQuickAddHotKeyLabel'),
        ),
      ],
    );
  }
}
