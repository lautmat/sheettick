import 'package:http/http.dart' as http;

/// The only OAuth scope the app ever asks for: files the app itself created or opened. It is non-sensitive,
/// so no Google verification is needed. Never widen it (see CLAUDE.md).
const kDriveFileScope = 'https://www.googleapis.com/auth/drive.file';

/// A signed-in Google account: an authenticated [client] (it attaches and refreshes the access token itself)
/// and, when known, the account's [email].
class AuthSession {
  const AuthSession({required this.client, this.email});

  final http.Client client;
  final String? email;
}

/// Anything that stops sign-in from working, with a message fit to show the user.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Platform sign-in: Google Sign-In on Android, the desktop loopback flow on Windows.
abstract interface class AuthService {
  /// The session from a previous sign-in, without any UI; null if there is none or it cannot be used silently.
  /// Does not need the network: a device that is offline keeps its session.
  Future<AuthSession?> restore();

  /// Interactive sign-in. Throws [AuthException] when it fails or is cancelled.
  Future<AuthSession> signIn();

  /// Forgets the account on this device.
  Future<void> signOut();
}
