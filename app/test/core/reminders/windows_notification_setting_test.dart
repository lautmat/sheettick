import 'dart:io' show ProcessResult;

import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/reminders/windows_notification_setting.dart';

void main() {
  const allApps = r'HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications';
  const thisApp = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\com.lmathieu.sheettick';

  ProcessResult dword(String key, String name, String hex) =>
      ProcessResult(0, 0, '\r\n$key\r\n    $name    REG_DWORD    $hex\r\n\r\n', '');
  final missing = ProcessResult(0, 1, '', 'ERROR: The system was unable to find the specified registry key or value.');

  WindowsNotificationSetting setting(Map<String, ProcessResult> answers) => WindowsNotificationSetting(
    appId: 'com.lmathieu.sheettick',
    run: (executable, args) async {
      expect(executable, 'reg');
      expect(args.first, 'query', reason: 'it only ever reads');
      return answers[args[1]] ?? missing;
    },
  );

  test('off for the whole account', () async {
    expect(await setting({allApps: dword(allApps, 'ToastEnabled', '0x0')}).areEnabled(), isFalse);
  });

  test('off for this app only', () async {
    final answers = {allApps: dword(allApps, 'ToastEnabled', '0x1'), thisApp: dword(thisApp, 'Enabled', '0x0')};
    expect(await setting(answers).areEnabled(), isFalse);
  });

  test('on when both say so', () async {
    final answers = {allApps: dword(allApps, 'ToastEnabled', '0x1'), thisApp: dword(thisApp, 'Enabled', '0x1')};
    expect(await setting(answers).areEnabled(), isTrue);
  });

  test('a setting that does not exist counts as on, the Windows default', () async {
    expect(await setting({}).areEnabled(), isTrue);
    expect(await setting({allApps: dword(allApps, 'ToastEnabled', '0x1')}).areEnabled(), isTrue);
  });

  test('output it cannot read, or reg failing to run, counts as on', () async {
    final garbled = ProcessResult(0, 0, 'ToastEnabled is something else', '');
    expect(await setting({allApps: garbled}).areEnabled(), isTrue);
    final broken = WindowsNotificationSetting(appId: 'x', run: (_, _) async => throw StateError('no reg'));
    expect(await broken.areEnabled(), isTrue);
  });
}
