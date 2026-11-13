import 'dart:io' show ProcessResult;

import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/desktop/startup_entry.dart';

void main() {
  const exe = r'C:\Users\Laurent\Apps\SheetTick\sheettick.exe';
  const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  late List<List<String>> calls;
  late Map<String, ProcessResult Function(List<String> args)> answers;

  /// A fake `reg`: [answers] says what each sub-command ("query", "add", "delete") returns.
  StartupEntry entry({String path = exe}) => StartupEntry(
    executablePath: path,
    run: (executable, args) async {
      expect(executable, 'reg');
      calls.add(args);
      return answers[args.first]!(args);
    },
  );

  ProcessResult ok([String out = '']) => ProcessResult(0, 0, out, '');
  ProcessResult fail(String err) => ProcessResult(0, 1, '', err);
  String listed(String data) => '\r\n$key\r\n    SheetTick    REG_SZ    $data\r\n\r\n';

  setUp(() {
    calls = [];
    answers = {'query': (_) => fail('not found'), 'add': (_) => ok(), 'delete': (_) => ok()};
  });

  test('the command is the quoted program path and the start-hidden argument', () {
    expect(entry().command, '"$exe" --minimized');
    expect(entry(path: r'C:\Program Files\SheetTick\sheettick.exe').command, startsWith('"C:\\Program Files\\'));
  });

  group('isEnabled', () {
    test('false when there is no entry', () async {
      expect(await entry().isEnabled(), isFalse);
      expect(calls.single, ['query', key, '/v', 'SheetTick']);
    });

    test('true when the entry starts this program, whatever the letter case', () async {
      answers['query'] = (_) => ok(listed('"${exe.toUpperCase()}" --minimized'));
      expect(await entry().isEnabled(), isTrue);
    });

    test('false when the entry points at another copy of the app', () async {
      answers['query'] = (_) => ok(listed(r'"D:\Old\sheettick.exe" --minimized'));
      expect(await entry().isEnabled(), isFalse);
    });
  });

  group('setEnabled', () {
    test('on: writes the value for the current user, replacing any old one', () async {
      await entry().setEnabled(true);
      expect(calls.single, ['add', key, '/v', 'SheetTick', '/t', 'REG_SZ', '/d', '"$exe" --minimized', '/f']);
    });

    test('on, when Windows refuses: an error with what reg said', () async {
      answers['add'] = (_) => fail('ERROR: Access is denied.');
      await expectLater(
        entry().setEnabled(true),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Access is denied'))),
      );
    });

    test('off: removes the value when it is there', () async {
      answers['query'] = (_) => ok(listed('"$exe" --minimized'));
      await entry().setEnabled(false);
      expect(calls.map((c) => c.first), ['query', 'delete']);
      expect(calls.last, ['delete', key, '/v', 'SheetTick', '/f']);
    });

    test('off: nothing to remove is fine and deletes nothing', () async {
      await entry().setEnabled(false);
      expect(calls.map((c) => c.first), ['query']);
    });

    test('off, when Windows refuses: an error', () async {
      answers['query'] = (_) => ok(listed('"$exe" --minimized'));
      answers['delete'] = (_) => fail('ERROR: Access is denied.');
      await expectLater(entry().setEnabled(false), throwsStateError);
    });
  });
}
