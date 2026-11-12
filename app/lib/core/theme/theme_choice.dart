/// Which theme the user picked on this device. Not synced: a phone may be dark and a desktop light.
enum ThemeChoice {
  /// Follow the system's light or dark setting. The default.
  system('system'),
  light('light'),
  dark('dark');

  const ThemeChoice(this.value);

  /// What is stored in `device_state`.
  final String value;

  /// The choice stored as [text]; anything else, or nothing, is [system].
  static ThemeChoice parse(String? text) {
    for (final c in values) {
      if (c.value == text) return c;
    }
    return system;
  }
}
