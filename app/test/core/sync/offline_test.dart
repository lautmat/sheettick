import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sheettick/core/sync/offline.dart';

void main() {
  test('a missing network is offline, however it is wrapped', () {
    const message = "Failed host lookup: 'www.googleapis.com' (OS Error: No address associated with hostname, errno = 7)";
    expect(isOfflineError(const SocketException(message)), isTrue);
    expect(isOfflineError(http.ClientException('SocketException: $message', Uri.parse('https://x.test'))), isTrue);
    expect(isOfflineError(http.ClientException('Connection closed before full header was received')), isFalse);
    expect(isOfflineError(TimeoutException('slow')), isTrue);
  });

  test('real problems are not offline', () {
    expect(isOfflineError(StateError('schema mismatch')), isFalse);
    expect(isOfflineError(ArgumentError('x')), isFalse);
    expect(isOfflineError(const FormatException('bad')), isFalse);
  });
}
