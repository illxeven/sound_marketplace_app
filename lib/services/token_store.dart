import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access and refresh tokens, kept in the OS keychain / keystore (browser storage on web).
/// The user object itself is never cached as a "session"; it is re-fetched from /users/me.
class TokenStore {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'sm_access_token';
  static const _refreshKey = 'sm_refresh_token';

  static Future<String?> readAccess() => _storage.read(key: _accessKey);
  static Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  static Future<void> save({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
