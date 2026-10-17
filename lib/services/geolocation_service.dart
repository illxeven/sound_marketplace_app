import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeolocationService {
  /// Optional Google Maps Geocoding API key if provided by user/config.
  static String? googleApiKey;

  /// Detects the user's country code automatically (e.g. "US", "CA", "GB", etc.).
  /// 
  /// Strategy:
  /// 1. If [googleApiKey] is provided, attempts reverse geocoding via Google Maps Geocoding API.
  /// 2. If no key is set or Google Geocoding fails/returns empty, uses IP-based geolocation fallback
  ///    (ipapi.co / ip-api.com) so users don't have to enter it manually and registration doesn't fail.
  /// 3. Falls back safely to 'US' or empty string if offline.
  static Future<String> detectCountryCode() async {
    // 1. Try Google Geocoding if API key is present
    if (googleApiKey != null && googleApiKey!.trim().isNotEmpty) {
      try {
        final googleCountry = await _getCountryFromGoogle(googleApiKey!.trim());
        if (googleCountry != null && googleCountry.isNotEmpty) {
          debugPrint('Detected country via Google API: $googleCountry');
          return googleCountry.toUpperCase();
        }
      } catch (e) {
        debugPrint('Google Geolocation failed: $e');
      }
    }

    // 2. IP Geolocation auto-detection fallback (reliable, requires no key, instant)
    try {
      final res = await http.get(
        Uri.parse('https://ipapi.co/json/'),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['country_code'] != null) {
          final code = data['country_code'].toString().trim().toUpperCase();
          if (code.isNotEmpty) {
            debugPrint('Auto-detected country via IP service: $code');
            return code;
          }
        }
      }
    } catch (e) {
      debugPrint('ipapi detection fallback: $e');
    }

    // Secondary IP fallback
    try {
      final res = await http.get(
        Uri.parse('http://ip-api.com/json'),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['countryCode'] != null) {
          final code = data['countryCode'].toString().trim().toUpperCase();
          if (code.isNotEmpty) {
            return code;
          }
        }
      }
    } catch (_) {}

    return 'US'; // Safe fallback
  }

  static Future<String?> _getCountryFromGoogle(String apiKey) async {
    // Queries Google Maps Geolocation / Geocoding endpoint
    final uri = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?key=$apiKey');
    final res = await http.get(uri).timeout(const Duration(seconds: 4));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['results'] is List && (data['results'] as List).isNotEmpty) {
        for (var result in data['results']) {
          if (result['address_components'] is List) {
            for (var comp in result['address_components']) {
              if (comp['types'] is List && (comp['types'] as List).contains('country')) {
                return comp['short_name'] as String?;
              }
            }
          }
        }
      }
    }
    return null;
  }
}
