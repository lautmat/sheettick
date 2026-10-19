import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sheettick/core/auth/bearer_client.dart';

void main() {
  late List<String?> seenAuth;
  late int tokenCalls;
  late DateTime now;
  late int nextStatus;

  BearerClient client({Future<String> Function()? token, Duration maxAge = const Duration(minutes: 30)}) => BearerClient(
    token ?? () async => 'token-${++tokenCalls}',
    maxAge: maxAge,
    clock: () => now,
    inner: MockClient((req) async {
      seenAuth.add(req.headers['Authorization']);
      return http.Response('{}', nextStatus);
    }),
  );

  setUp(() {
    seenAuth = [];
    tokenCalls = 0;
    now = DateTime.utc(2026, 10, 19, 12);
    nextStatus = 200;
  });

  test('adds the bearer token to every request', () async {
    final c = client();
    await c.get(Uri.parse('https://example.test/a'));
    expect(seenAuth, ['Bearer token-1']);
  });

  test('reuses a token while it is fresh, asks again after maxAge', () async {
    final c = client();
    await c.get(Uri.parse('https://example.test/a'));
    now = now.add(const Duration(minutes: 29));
    await c.get(Uri.parse('https://example.test/b'));
    expect(seenAuth, ['Bearer token-1', 'Bearer token-1']);
    expect(tokenCalls, 1);

    now = now.add(const Duration(minutes: 2));
    await c.get(Uri.parse('https://example.test/c'));
    expect(seenAuth.last, 'Bearer token-2');
  });

  test('a 401 drops the token so the next request gets a new one', () async {
    final c = client();
    nextStatus = 401;
    final r = await c.get(Uri.parse('https://example.test/a'));
    expect(r.statusCode, 401);

    nextStatus = 200;
    await c.get(Uri.parse('https://example.test/b'));
    expect(seenAuth, ['Bearer token-1', 'Bearer token-2']);
  });

  test('other error statuses keep the token', () async {
    final c = client();
    nextStatus = 500;
    await c.get(Uri.parse('https://example.test/a'));
    await c.get(Uri.parse('https://example.test/b'));
    expect(tokenCalls, 1);
  });

  test('a failing token provider fails the request instead of sending it unauthenticated', () async {
    final c = client(token: () async => throw StateError('revoked'));
    await expectLater(c.get(Uri.parse('https://example.test/a')), throwsStateError);
    expect(seenAuth, isEmpty);
  });
}
