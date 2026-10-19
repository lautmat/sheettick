import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'android_auth_service.dart';
import 'auth_service.dart';
import 'credential_store.dart';
import 'desktop_auth_service.dart';
import 'oauth_config.dart';

class _UnsupportedAuthService implements AuthService {
  @override
  Future<AuthSession?> restore() async => null;
  @override
  Future<AuthSession> signIn() => throw AuthException('Google sign-in is only available on Windows and Android.');
  @override
  Future<void> signOut() async {}
}

/// The platform sign-in. Tests override this.
final authServiceProvider = Provider<AuthService>((ref) {
  const config = OAuthConfig();
  if (Platform.isWindows) return DesktopAuthService(config: config, store: SecureCredentialStore());
  if (Platform.isAndroid) return AndroidAuthService(config: config);
  return _UnsupportedAuthService();
});

class AuthState {
  const AuthState({this.session, this.restoring = false, this.busy = false, this.error});

  final AuthSession? session;

  /// Looking for a previous sign-in at startup.
  final bool restoring;

  /// An interactive sign-in is in progress.
  final bool busy;

  /// Why the last sign-in or restore failed, or why the session ended.
  final String? error;

  bool get signedIn => session != null;
}

/// Owns "who is signed in". The session comes from a previous run when there is one (the user stays signed in
/// after a restart); everything that talks to Google reads its client from [AuthState.session].
class AuthController extends Notifier<AuthState> {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  AuthState build() {
    Future.microtask(restore);
    return const AuthState(restoring: true);
  }

  Future<void> restore() async {
    try {
      state = AuthState(session: await _service.restore());
    } catch (e) {
      state = AuthState(error: '$e');
    }
  }

  Future<void> signIn() async {
    // Not while the startup restore is still running: its answer would overwrite the result of this sign-in.
    if (state.busy || state.restoring) return;
    state = AuthState(busy: true, session: state.session);
    try {
      state = AuthState(session: await _service.signIn());
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
    } catch (e) {
      state = AuthState(error: 'Sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    final session = state.session;
    try {
      await _service.signOut();
    } finally {
      session?.client.close();
      state = const AuthState();
    }
  }

  /// The session stopped working (access revoked, refresh token rejected): ask the user to sign in again.
  void sessionExpired(String message) {
    state.session?.client.close();
    state = AuthState(error: message);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
