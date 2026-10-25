import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  // The legacy macOS Keychain works without a provisioning profile or
  // Keychain Sharing; credentials are not shared with other apps.
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static const _keyUsername = 'fzu_username';
  static const _keyPassword = 'fzu_password';
  static const _keyAcademicSession = 'fzu_academic_session';

  Future<void> saveAcademicSession(Map<String, dynamic> session) =>
      _storage.write(key: _keyAcademicSession, value: jsonEncode(session));

  Future<Map<String, dynamic>?> loadAcademicSession() async {
    try {
      final raw = await _storage.read(key: _keyAcademicSession);
      return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw));
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clearAcademicSession() =>
      _storage.delete(key: _keyAcademicSession);

  Future<void> saveCredentials(String username, String password) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<({String username, String password})?> loadCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    if (username != null && password != null) {
      return (username: username, password: password);
    }
    return null;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPassword);
  }
}
