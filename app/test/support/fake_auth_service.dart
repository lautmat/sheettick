import 'package:http/http.dart' as http;
import 'package:sheettick/core/auth/auth_service.dart';

/// A scripted [AuthService]: no browser, no keychain, no network.
class FakeAuthService implements AuthService {
  FakeAuthService({this.restored, this.onSignIn, this.signInError, this.restoreError});

  /// What [restore] returns (a previous sign-in), if any.
  AuthSession? restored;

  /// What a successful [signIn] returns.
  AuthSession Function()? onSignIn;

  /// Thrown by [signIn] instead, when set.
  Object? signInError;

  /// Thrown by [restore], when set.
  Object? restoreError;

  int signInCalls = 0;
  int signOutCalls = 0;

  static AuthSession session({String? email = 'laurent@example.com'}) => AuthSession(client: http.Client(), email: email);

  @override
  Future<AuthSession?> restore() async {
    if (restoreError != null) throw restoreError!;
    return restored;
  }

  @override
  Future<AuthSession> signIn() async {
    signInCalls++;
    if (signInError != null) throw signInError!;
    return (onSignIn ?? session)();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    restored = null;
  }
}
