import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

/// Where the app talks to the backend.
///
/// Release builds must pass the URL at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://api.yourdomain.com/api
/// Debug builds fall back to the local Spring Boot server.
class ApiConfig {
  static const String _fromBuild = String.fromEnvironment('API_BASE_URL');

  static String? _debugOverride;

  /// Debug builds only: point the app at another server (e.g. a phone testing against a laptop).
  /// Ignored in release builds so nobody can redirect users' logins to a different server.
  static void setCustomBaseUrl(String url) {
    if (kDebugMode && url.trim().isNotEmpty) _debugOverride = _trimSlash(url.trim());
  }

  static String get baseUrl {
    if (kDebugMode && _debugOverride != null) return _debugOverride!;
    if (_fromBuild.isNotEmpty) return _trimSlash(_fromBuild);
    if (!kDebugMode) {
      // Fail loudly instead of silently pointing a release build at localhost.
      throw StateError('API_BASE_URL is not set. Build with --dart-define=API_BASE_URL=https://.../api');
    }
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) return 'http://10.0.2.2:8080/api'; // Android emulator -> host machine
      } catch (_) {
        // Platform is unavailable in some test environments; use localhost.
      }
    }
    return 'http://localhost:8080/api';
  }

  /// Server origin without the `/api` suffix, e.g. `http://localhost:8080`.
  static String get origin {
    final base = baseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  /// Turns a path from the server into a full URL.
  ///
  /// The backend returns paths that already start with `/api` (cover, avatar and stream URLs).
  /// Those are joined to the origin; joining them to [baseUrl] produced `/api/api/...` (404).
  static String resolve(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) return pathOrUrl;
    final path = pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
    if (path == '/api' || path.startsWith('/api/')) return '$origin$path';
    return '$baseUrl$path';
  }

  static String? resolveOrNull(String? pathOrUrl) =>
      (pathOrUrl == null || pathOrUrl.trim().isEmpty) ? null : resolve(pathOrUrl.trim());

  static const Duration timeoutDuration = Duration(seconds: 15);

  static String _trimSlash(String s) => s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
