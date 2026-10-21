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
