import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/auth/auth_controller.dart';
import 'package:sheettick/core/auth/auth_service.dart';
import 'package:sheettick/core/auth/oauth_config.dart';
import 'package:sheettick/core/providers.dart';
import 'package:sheettick/core/sheets/sheets_backend.dart';

import '../../support/fake_auth_service.dart';
import '../../support/fake_sheets_backend.dart';

void main() {
  ProviderContainer container(FakeAuthService auth, {SheetsBackend? backend}) {
    final c = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        if (backend != null) backendFactoryProvider.overrideWithValue((_) => backend),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts restoring, then signed out when there is no previous session', () async {
    final c = container(FakeAuthService());
    expect(c.read(authControllerProvider).restoring, isTrue);
    await settle();
    final s = c.read(authControllerProvider);
    expect((s.restoring, s.signedIn, s.error), (false, false, null));
  });

  test('a previous session is restored without any sign-in (stays signed in after a restart)', () async {
    final auth = FakeAuthService(restored: FakeAuthService.session());
    final c = container(auth);
    c.read(authControllerProvider);
    await settle();
    expect(c.read(authControllerProvider).signedIn, isTrue);
    expect(auth.signInCalls, 0);
  });

  test('a failing restore is reported, not thrown', () async {
    final c = container(FakeAuthService(restoreError: StateError('keychain locked')));
    c.read(authControllerProvider);
    await settle();
    expect(c.read(authControllerProvider).signedIn, isFalse);
    expect(c.read(authControllerProvider).error, contains('keychain locked'));
  });

  test('signIn success: signed in, no error', () async {
    final c = container(FakeAuthService());
    await settle();
    await c.read(authControllerProvider.notifier).signIn();
    final s = c.read(authControllerProvider);
    expect((s.signedIn, s.busy, s.error), (true, false, null));
    expect(s.session!.email, 'laurent@example.com');
  });

  test('signIn failure keeps the message for the UI and stays signed out', () async {
    final c = container(FakeAuthService(signInError: AuthException('Sign-in was cancelled.')));
    await settle();
    await c.read(authControllerProvider.notifier).signIn();
    final s = c.read(authControllerProvider);
    expect((s.signedIn, s.error), (false, 'Sign-in was cancelled.'));
  });

  test('an unexpected error is wrapped in a message too', () async {
    final c = container(FakeAuthService(signInError: StateError('boom')));
    await settle();
    await c.read(authControllerProvider.notifier).signIn();
    expect(c.read(authControllerProvider).error, contains('boom'));
  });

  test('signIn is ignored while one is already in progress', () async {
    final auth = FakeAuthService();
    final c = container(auth);
    await settle();
    final n = c.read(authControllerProvider.notifier);
    final first = n.signIn();
    expect(c.read(authControllerProvider).busy, isTrue);
    await n.signIn();
    await first;
    expect(auth.signInCalls, 1);
  });

  test('signOut forgets the session', () async {
    final auth = FakeAuthService(restored: FakeAuthService.session());
    final c = container(auth);
    c.read(authControllerProvider);
    await settle();
    await c.read(authControllerProvider.notifier).signOut();
    expect(c.read(authControllerProvider).signedIn, isFalse);
    expect(auth.signOutCalls, 1);
  });

  test('sessionExpired ends the session and says why', () async {
    final c = container(FakeAuthService(restored: FakeAuthService.session()));
    c.read(authControllerProvider);
    await settle();
    c.read(authControllerProvider.notifier).sessionExpired('Please sign in again.');
    final s = c.read(authControllerProvider);
    expect((s.signedIn, s.error), (false, 'Please sign in again.'));
  });

  test('the sheets backend exists exactly while signed in', () async {
    final backend = FakeSheetsBackend();
    final c = container(FakeAuthService(), backend: backend);
    c.listen(sheetsBackendProvider, (_, _) {});
    await settle();
    expect(c.read(sheetsBackendProvider), isNull);

    await c.read(authControllerProvider.notifier).signIn();
    expect(c.read(sheetsBackendProvider), same(backend));

    await c.read(authControllerProvider.notifier).signOut();
    expect(c.read(sheetsBackendProvider), isNull);
  });

  test('OAuth client ids are empty unless supplied with --dart-define', () {
    const config = OAuthConfig();
    expect((config.hasDesktopClient, config.hasWebClient), (false, false));
  });
}
