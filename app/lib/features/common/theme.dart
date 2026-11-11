import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_choice.dart';

/// The theme picked on this device, kept in `device_state` so it never reaches the Sheet. Until it is read, and when
/// nothing was ever picked, it is [ThemeChoice.system].
class ThemeChoiceState extends AsyncNotifier<ThemeChoice> {
  @override
  Future<ThemeChoice> build() async {
    final stored = await ref.watch(appDatabaseProvider).getDeviceState(DeviceStateKeys.themeChoice);
    return ThemeChoice.parse(stored);
  }

  /// Saves [choice], then shows it. The write comes first, so a failing write leaves the app showing the choice that is
  /// still stored rather than one that would be gone at the next start.
  Future<void> choose(ThemeChoice choice) async {
    await ref.read(appDatabaseProvider).setDeviceState(DeviceStateKeys.themeChoice, choice.value);
    state = AsyncData(choice);
  }
}

final themeChoiceProvider = AsyncNotifierProvider<ThemeChoiceState, ThemeChoice>(ThemeChoiceState.new);

/// The two themes of the app, from one seed colour.
ThemeData appTheme(Brightness brightness) =>
    ThemeData(colorSchemeSeed: Colors.indigo, brightness: brightness, useMaterial3: true);

extension on ThemeChoice {
  String get label => switch (this) {
        ThemeChoice.system => 'System',
        ThemeChoice.light => 'Light',
        ThemeChoice.dark => 'Dark',
      };

  ThemeMode get mode => switch (this) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      };
}

/// The [ThemeMode] to run the app in.
ThemeMode themeModeOf(ThemeChoice? choice) => (choice ?? ThemeChoice.system).mode;

/// App bar button to pick System, Light or Dark.
class ThemeMenu extends ConsumerWidget {
  const ThemeMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeChoiceProvider).value ?? ThemeChoice.system;
    return PopupMenuButton<ThemeChoice>(
      key: const Key('themeMenu'),
      tooltip: 'Theme',
      icon: const Icon(Icons.brightness_6_outlined),
      initialValue: current,
      onSelected: (c) => ref.read(themeChoiceProvider.notifier).choose(c),
      itemBuilder: (_) => [
        for (final c in ThemeChoice.values)
          CheckedPopupMenuItem<ThemeChoice>(
            key: Key('theme-${c.value}'),
            value: c,
            checked: c == current,
            child: Text(c.label),
          ),
      ],
    );
  }
}
