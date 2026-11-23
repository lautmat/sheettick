import 'dart:io' show Process;

import '../desktop/startup_entry.dart' show CommandRunner;

/// Whether Windows will show this app's notifications, read from the per-user settings with `reg.exe` (no package, and
/// nothing is changed). Windows accepts a toast without complaint when they are off and drops it, so this is the only way
/// to know.
///
/// A setting that is missing or cannot be read counts as on, which is the Windows default: a wrong warning would be worse
/// than none.
class WindowsNotificationSetting {
  WindowsNotificationSetting({required this.appId, CommandRunner? run}) : _run = run ?? Process.run;

  static const _allApps = r'HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications';
  static const _perApp = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings';

  final String appId;
  final CommandRunner _run;

  /// False when notifications are off for the whole account or for this app.
  Future<bool> areEnabled() async {
    if (await _dword(_allApps, 'ToastEnabled') == 0) return false;
    return await _dword('$_perApp\\$appId', 'Enabled') != 0;
  }

  Future<int?> _dword(String key, String value) async {
    try {
      final result = await _run('reg', ['query', key, '/v', value]);
      if (result.exitCode != 0) return null;
      final line = RegExp(
        '^\\s*${RegExp.escape(value)}\\s+REG_DWORD\\s+0x([0-9a-f]+)\\s*\$',
        caseSensitive: false,
        multiLine: true,
      ).firstMatch('${result.stdout}');
      return line == null ? null : int.parse(line[1]!, radix: 16);
    } catch (_) {
      return null;
    }
  }
}
