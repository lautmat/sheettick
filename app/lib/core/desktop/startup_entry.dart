import 'dart:io' show Process, ProcessResult;

import 'desktop_shell.dart';

/// Runs an executable and returns its result; replaced in tests.
typedef CommandRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

Future<ProcessResult> _runProcess(String executable, List<String> arguments) => Process.run(executable, arguments);

/// Starts the app when the user signs in to Windows, by a value in the per-user `Run` registry key (no admin rights, and
/// the user can see and remove it in Task Manager's Startup tab). It uses `reg.exe`, which every Windows has, so it needs
/// no package. The value is the quoted path of the program followed by [kStartHiddenArgument], so the app starts in the
/// tray.
class StartupEntry {
  StartupEntry({required this.executablePath, this.valueName = 'SheetTick', CommandRunner? run})
    : _run = run ?? _runProcess;

  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  final String executablePath;
  final String valueName;
  final CommandRunner _run;

  /// What is written to the registry value.
  String get command => '"$executablePath" $kStartHiddenArgument';

  /// Whether the entry exists and starts this program (an entry left by a copy in another folder does not count).
  Future<bool> isEnabled() async {
    final result = await _run('reg', ['query', _key, '/v', valueName]);
    if (result.exitCode != 0) return false;
    return '${result.stdout}'.toLowerCase().contains(executablePath.toLowerCase());
  }

  /// Turns the entry on (written, or rewritten with the current path) or off (removed; fine if it was not there).
  /// Throws a [StateError] with the output of `reg` when that fails.
  Future<void> setEnabled(bool on) async {
    if (on) {
      final result = await _run('reg', ['add', _key, '/v', valueName, '/t', 'REG_SZ', '/d', command, '/f']);
      if (result.exitCode != 0) throw StateError('Could not turn on Start with Windows: ${result.stderr}'.trim());
      return;
    }
    final exists = (await _run('reg', ['query', _key, '/v', valueName])).exitCode == 0;
    if (!exists) return;
    final result = await _run('reg', ['delete', _key, '/v', valueName, '/f']);
    if (result.exitCode != 0) throw StateError('Could not turn off Start with Windows: ${result.stderr}'.trim());
  }
}
