import 'dart:math';

/// Runs [action], retrying while [isRetryable] says the error is transient (HTTP 429 and 5xx).
///
/// Waits 1 s, 2 s, 4 s ... up to [maxDelay] (64 s) between attempts, each scaled by a random factor in
/// [0.5, 1.0] so devices that were throttled together do not retry together. The last error is rethrown
/// after [maxAttempts] attempts. [sleep] and [random] are injectable for tests.
Future<T> retryWithBackoff<T>(
  Future<T> Function() action, {
  required bool Function(Object error) isRetryable,
  int maxAttempts = 8,
  Duration baseDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 64),
  Random? random,
  Future<void> Function(Duration)? sleep,
}) async {
  final rng = random ?? Random();
  final wait = sleep ?? Future<void>.delayed;
  for (var attempt = 1;; attempt++) {
    try {
      return await action();
    } catch (e) {
      if (attempt >= maxAttempts || !isRetryable(e)) rethrow;
      final exponential = baseDelay * (1 << (attempt - 1));
      final capped = exponential > maxDelay ? maxDelay : exponential;
      await wait(capped * (0.5 + rng.nextDouble() / 2));
    }
  }
}
