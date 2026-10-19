import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:sheettick/core/auth/auth_service.dart';
import 'package:sheettick/core/auth/credential_store.dart';
import 'package:sheettick/core/auth/desktop_auth_service.dart';
import 'package:sheettick/core/auth/oauth_config.dart';

class _MemoryStore implements CredentialStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async => value = v;
  @override
  Future<void> delete() async => value = null;
}

const _configured = OAuthConfig(desktopClientId: 'id.apps.googleusercontent.com', desktopClientSecret: 'shh');

gauth.AccessCredentials _credentials({String? refreshToken = 'refresh-1'}) => gauth.AccessCredentials(
  gauth.AccessToken('Bearer', 'access-1', DateTime.now().toUtc().add(const Duration(hours: 1))),
  refreshToken,
  [kDriveFileScope],
);

void main() {
  late _MemoryStore store;
  setUp(() => store = _MemoryStore());

  DesktopAuthService service({
    OAuthConfig config = _configured,
    ConsentFlow? consent,
    List<Uri>? opened,
  }) => DesktopAuthService(
    config: config,
    store: store,
    consentFlow: consent,
    openBrowser: (url) async {
      opened?.add(url);
      return true;
    },
  );

  ConsentFlow consentReturning(gauth.AccessCredentials credentials, {List<List<String>>? scopesSeen}) =>
      (clientId, scopes, prompt) async {
        scopesSeen?.add(scopes);
        prompt('https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId.identifier}');
        return gauth.authenticatedClient(http.Client(), credentials);
      };

  group('signIn', () {
    test('opens the consent URL in the browser, asks for drive.file only, and stores the credentials', () async {
      final opened = <Uri>[];
      final scopes = <List<String>>[];
      final session = await service(opened: opened, consent: consentReturning(_credentials(), scopesSeen: scopes)).signIn();

      expect(session.client, isNotNull);
      expect(opened.single.host, 'accounts.google.com');
      expect(scopes.single, ['https://www.googleapis.com/auth/drive.file']);
      final saved = jsonDecode(store.value!) as Map<String, dynamic>;
      expect(saved['refreshToken'], 'refresh-1');
      expect(saved['scopes'], ['https://www.googleapis.com/auth/drive.file']);
    });

    test('no refresh token: fails loudly and stores nothing', () async {
      await expectLater(
        service(consent: consentReturning(_credentials(refreshToken: null))).signIn(),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('refresh token'))),
      );
      expect(store.value, isNull);
    });

    test('a browser that cannot be opened fails the sign-in at once instead of hanging', () async {
      final neverAnswers = Completer<gauth.AuthClient>();
      final s = DesktopAuthService(
        config: _configured,
        store: store,
        consentFlow: (clientId, scopes, prompt) {
          prompt('https://accounts.google.com/o/oauth2/v2/auth');
          return neverAnswers.future; // the loopback redirect never comes
        },
        openBrowser: (_) async => false,
      );
      await expectLater(
        s.signIn().timeout(const Duration(seconds: 5)),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('open the browser'))),
      );
      expect(store.value, isNull);
    });

    test('a browser launch that throws is reported the same way', () async {
      final s = DesktopAuthService(
        config: _configured,
        store: store,
        consentFlow: (clientId, scopes, prompt) {
          prompt('https://accounts.google.com/o/oauth2/v2/auth');
          return Completer<gauth.AuthClient>().future;
        },
        openBrowser: (_) async => throw StateError('no default browser'),
      );
      await expectLater(
        s.signIn().timeout(const Duration(seconds: 5)),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('no default browser'))),
      );
    });

    test('a user who never finishes in the browser times out', () async {
      final s = DesktopAuthService(
        config: _configured,
        store: store,
        consentFlow: (clientId, scopes, prompt) => Completer<gauth.AuthClient>().future,
        openBrowser: (_) async => true,
        signInTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        s.signIn(),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('timed out'))),
      );
    });

    test('a cancelled consent becomes a readable AuthException', () async {
      await expectLater(
        service(consent: (_, _, _) async => throw gauth.UserConsentException('access_denied')).signIn(),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('cancelled or refused'))),
      );
      expect(store.value, isNull);
    });

    test('without the OAuth client configured it says how to configure it', () async {
      await expectLater(
        service(config: const OAuthConfig(desktopClientId: '')).signIn(),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('dart_defines.json'))),
      );
    });
  });

  group('restore', () {
    test('nothing stored: no session', () async {
      expect(await service().restore(), isNull);
    });

    test('stored credentials come back as a session, with no network call', () async {
      store.value = jsonEncode(_credentials().toJson());
      expect(await service().restore(), isNotNull);
    });

    test('credentials without a refresh token cannot be kept', () async {
      store.value = jsonEncode(_credentials(refreshToken: null).toJson());
      expect(await service().restore(), isNull);
    });

    test('unreadable stored data is discarded instead of failing every launch', () async {
      store.value = 'not json';
      expect(await service().restore(), isNull);
      expect(store.value, isNull);
    });

    test('without the OAuth client configured there is nothing to restore with', () async {
      store.value = jsonEncode(_credentials().toJson());
      expect(await service(config: const OAuthConfig(desktopClientId: '')).restore(), isNull);
    });
  });

  test('signOut forgets the credentials', () async {
    store.value = jsonEncode(_credentials().toJson());
    await service().signOut();
    expect(store.value, isNull);
    expect(await service().restore(), isNull);
  });
}
