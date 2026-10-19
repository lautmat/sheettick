/// OAuth client identifiers, supplied at build time from the git-ignored `app/secrets/dart_defines.json`
/// (generate it with `dart run tools/oauth_defines.dart`, then
/// `flutter run --dart-define-from-file=secrets/dart_defines.json`). They are never committed.
class OAuthConfig {
  const OAuthConfig({
    this.desktopClientId = const String.fromEnvironment('DESKTOP_CLIENT_ID'),
    this.desktopClientSecret = const String.fromEnvironment('DESKTOP_CLIENT_SECRET'),
    this.webClientId = const String.fromEnvironment('WEB_CLIENT_ID'),
  });

  /// "Desktop app" client (Windows loopback flow). Google documents that the secret of an installed-app client
  /// is not confidential, but it still stays out of git.
  final String desktopClientId;
  final String desktopClientSecret;

  /// "Web application" client whose id Google Sign-In on Android needs as `serverClientId`.
  final String webClientId;

  bool get hasDesktopClient => desktopClientId.isNotEmpty;
  bool get hasWebClient => webClientId.isNotEmpty;
}
