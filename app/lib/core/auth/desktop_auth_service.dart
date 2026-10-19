import 'dart:async';
import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';
import 'credential_store.dart';
import 'oauth_config.dart';

/// Runs the consent flow: shows [url] to the user and returns once the loopback server got the answer.
typedef ConsentFlow =
    Future<gauth.AuthClient> Function(
      gauth.ClientId clientId,
      List<String> scopes,
      void Function(String url) prompt,
    );

Future<gauth.AuthClient> _loopbackConsent(
  gauth.ClientId clientId,
  List<String> scopes,
  void Function(String url) prompt,
) => gauth.clientViaUserConsent(clientId, scopes, prompt);

/// Windows sign-in: the desktop OAuth loopback flow in the default browser (the app listens on a random
/// localhost port for Google's redirect). The credentials, including the refresh token, are kept in Windows
/// Credential Manager so the user stays signed in after a restart.
class DesktopAuthService implements AuthService {
  DesktopAuthService({
    required this.config,
    required this.store,
    ConsentFlow? consentFlow,
    Future<bool> Function(Uri url)? openBrowser,
    http.Client Function()? newBaseClient,
    this.signInTimeout = const Duration(minutes: 5),
  }) : _consent = consentFlow ?? _loopbackConsent,
       _openBrowser = openBrowser ?? ((url) => launchUrl(url, mode: LaunchMode.externalApplication)),
       _newBaseClient = newBaseClient ?? http.Client.new;

  final OAuthConfig config;
  final CredentialStore store;

  /// How long to wait for the user to finish in the browser before giving up.
  final Duration signInTimeout;
  final ConsentFlow _consent;
  final Future<bool> Function(Uri url) _openBrowser;
  final http.Client Function() _newBaseClient;

  gauth.ClientId get _clientId {
    if (!config.hasDesktopClient) {
      throw AuthException(
        'The Google OAuth client is not configured. Build with '
        '--dart-define-from-file=secrets/dart_defines.json (see app/secrets/README.md).',
      );
    }
    return gauth.ClientId(config.desktopClientId, config.desktopClientSecret);
  }

  @override
  Future<AuthSession?> restore() async {
    final stored = await store.read();
    if (stored == null || !config.hasDesktopClient) return null;
    final gauth.AccessCredentials credentials;
    try {
      credentials = gauth.AccessCredentials.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    } on Object {
      await store.delete(); // Unreadable: start clean rather than fail on every launch.
      return null;
    }
    if (credentials.refreshToken == null) return null;
    // The returned client refreshes the access token when it expires, so no network is needed here.
    return AuthSession(client: gauth.autoRefreshingClient(_clientId, credentials, _newBaseClient()));
  }

  @override
  Future<AuthSession> signIn() async {
    final clientId = _clientId;
    final gauth.AuthClient client;
    // The consent flow waits for Google to call the local loopback server, which never happens if the browser
    // could not be opened. So a launch failure completes this future with an error and wins the race.
    final launchFailed = Completer<gauth.AuthClient>();
    try {
      client = await Future.any([
        _consent(clientId, [kDriveFileScope], (url) {
          _openBrowser(Uri.parse(url)).then(
            (opened) {
              if (!opened) launchFailed.completeError(AuthException('Could not open the browser to sign in.'));
            },
            onError: (Object e) {
              launchFailed.completeError(AuthException('Could not open the browser to sign in: $e'));
            },
          );
        }),
        launchFailed.future,
      ]).timeout(
        signInTimeout,
        onTimeout: () => throw AuthException('Sign-in timed out. Please try again.'),
      );
    } on gauth.UserConsentException catch (e) {
      throw AuthException('Sign-in was cancelled or refused: ${e.message}');
    } on gauth.AccessDeniedException catch (e) {
      throw AuthException('Google refused the sign-in: ${e.message}');
    }

    final credentials = client.credentials;
    if (credentials.refreshToken == null) {
      // Without a refresh token the app would be signed out within the hour.
      client.close();
      throw AuthException('Google did not return a refresh token, so the sign-in cannot be kept. Please report this.');
    }
    await store.write(jsonEncode(credentials.toJson()));
    return AuthSession(client: client);
  }

  @override
  Future<void> signOut() => store.delete();
}
