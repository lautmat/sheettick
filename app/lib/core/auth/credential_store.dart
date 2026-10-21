import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the Windows sign-in keeps its credentials between runs.
abstract interface class CredentialStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Windows Credential Manager (through `flutter_secure_storage`): the refresh token never touches a plain file.
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'sheettick.google.credentials';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}
