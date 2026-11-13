import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';
import 'bearer_client.dart';
import 'oauth_config.dart';

/// Android sign-in: Google Sign-In (Credential Manager) for the account, and its authorization client for
/// an access token with the `drive.file` scope. The platform keeps the account across restarts.
class AndroidAuthService implements AuthService {
  AndroidAuthService({required this.config, GoogleSignIn? googleSignIn}) : _google = googleSignIn ?? GoogleSignIn.instance;

  final OAuthConfig config;
  final GoogleSignIn _google;
  Future<void>? _initialized;

  Future<void> _init() => _initialized ??= _google.initialize(
    serverClientId: config.hasWebClient ? config.webClientId : null,
  );

  AuthSession _session(GoogleSignInAccount account) => AuthSession(
    email: account.email,
    // Access tokens last about an hour and the SDK has no refresh token to give us, so ask it again, silently,
    // whenever the client needs a token. If the user revoked access this fails and the sync reports it.
    client: BearerClient(() async {
      final authz = await account.authorizationClient.authorizationForScopes([kDriveFileScope]);
      if (authz == null) throw AuthException('Google access was revoked or expired. Please sign in again.');
      return authz.accessToken;
    }),
  );

  @override
  Future<AuthSession?> restore() async {
    await _init();
    try {
      final account = await _google.attemptLightweightAuthentication();
      if (account == null) return null;
      final authz = await account.authorizationClient.authorizationForScopes([kDriveFileScope]);
      return authz == null ? null : _session(account);
    } on GoogleSignInException {
      return null;
    }
  }

  /// A client for a background job: no screen, so no sign-in prompt. It asks the authorization client for a token that
  /// can be returned without user interaction, which works when the account already granted [kDriveFileScope] in the
  /// app (the platform remembers it). Null when Google would need the user to say yes again, or the device has no
  /// authorized account: the job then skips its run and the app asks the next time it is opened.
  ///
  /// This does not look up the account (that needs an Activity). The authorization client picks the account that
  /// authorized the app, which is the only one the app ever uses.
  Future<AuthSession?> restoreWithoutUi() async {
    await _init();
    try {
      final client = _google.authorizationClient;
      final authz = await client.authorizationForScopes([kDriveFileScope]);
      if (authz == null) return null;
      return AuthSession(
        client: BearerClient(() async {
          final again = await client.authorizationForScopes([kDriveFileScope]);
          if (again == null) throw AuthException('Google access was revoked or expired. Please sign in again.');
          return again.accessToken;
        }),
      );
    } on GoogleSignInException {
      return null;
    }
  }

  @override
  Future<AuthSession> signIn() async {
    await _init();
    try {
      final account = await _google.authenticate(scopeHint: [kDriveFileScope]);
      await account.authorizationClient.authorizeScopes([kDriveFileScope]);
      return _session(account);
    } on GoogleSignInException catch (e) {
      throw AuthException(switch (e.code) {
        GoogleSignInExceptionCode.canceled => 'Sign-in was cancelled.',
        _ => 'Google sign-in failed (${e.code.name}): ${e.description ?? 'no details'}',
      });
    }
  }

  @override
  Future<void> signOut() async {
    await _init();
    await _google.signOut();
  }
}
