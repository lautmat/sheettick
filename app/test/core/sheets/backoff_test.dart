import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:sheettick/core/sheets/backoff.dart';
import 'package:sheettick/core/sheets/google_sheets_backend.dart';

/// Always draws 1.0, i.e. the full (un-jittered) delay.
class _MaxRandom implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 1.0;
  @override
  int nextInt(int max) => max - 1;
}

void main() {
  bool retryAll(Object _) => true;

  test('returns the result without sleeping when the first attempt works', () async {
    final slept = <Duration>[];
    final v = await retryWithBackoff(() async => 42, isRetryable: retryAll, sleep: (d) async => slept.add(d));
    expect(v, 42);
    expect(slept, isEmpty);
  });

  test('doubles the delay from 1 s and caps it at 64 s', () async {
    final slept = <Duration>[];
    var calls = 0;
    final v = await retryWithBackoff(
      () async => ++calls < 8 ? throw StateError('429') : 'ok',
      isRetryable: retryAll,
      random: _MaxRandom(),
      sleep: (d) async => slept.add(d),
    );
    expect(v, 'ok');
    expect(slept.map((d) => d.inSeconds), [1, 2, 4, 8, 16, 32, 64]);
  });

  test('jitter keeps each delay within [50%, 100%] of the nominal one', () async {
    final slept = <Duration>[];
    var calls = 0;
    await retryWithBackoff(
      () async => ++calls < 5 ? throw StateError('x') : null,
      isRetryable: retryAll,
      random: Random(7),
      sleep: (d) async => slept.add(d),
    );
    for (var i = 0; i < slept.length; i++) {
      final nominal = 1000 * (1 << i);
      expect(slept[i].inMilliseconds, inInclusiveRange(nominal * 0.5, nominal.toDouble()));
    }
  });

  test('gives up after maxAttempts and rethrows the last error', () async {
    var calls = 0;
    await expectLater(
      retryWithBackoff<void>(
        () async => throw StateError('attempt ${++calls}'),
        isRetryable: retryAll,
        maxAttempts: 3,
        sleep: (_) async {},
      ),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'attempt 3')),
    );
    expect(calls, 3);
  });

  test('does not retry errors that are not transient', () async {
    var calls = 0;
    await expectLater(
      retryWithBackoff<void>(
        () async {
          calls++;
          throw StateError('permanent');
        },
        isRetryable: (_) => false,
        sleep: (_) async {},
      ),
      throwsStateError,
    );
    expect(calls, 1);
  });

  test('isTransientApiError: 429 and 5xx yes, 4xx and other errors no', () {
    expect(isTransientApiError(drive.DetailedApiRequestError(429, 'slow down')), isTrue);
    expect(isTransientApiError(drive.DetailedApiRequestError(500, 'boom')), isTrue);
    expect(isTransientApiError(drive.DetailedApiRequestError(503, 'unavailable')), isTrue);
    expect(isTransientApiError(drive.DetailedApiRequestError(401, 'auth')), isFalse);
    expect(isTransientApiError(drive.DetailedApiRequestError(404, 'gone')), isFalse);
    expect(isTransientApiError(StateError('x')), isFalse);
  });
}
