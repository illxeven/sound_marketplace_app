import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String? _customBaseUrl;

  static void setCustomBaseUrl(String url) {
    _customBaseUrl = url;
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    } else {
      try {
        if (Platform.isAndroid) {
          // Android emulator routes to host via 10.0.2.2
          return 'http://10.0.2.2:8080/api';
        }
      } catch (_) {
        // Fallback if Platform is unsupported in some environments
      }
      return 'http://localhost:8080/api';
    }
  }

  static const Duration timeoutDuration = Duration(seconds: 15);
}
