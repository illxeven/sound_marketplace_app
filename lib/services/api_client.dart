import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_response.dart';

/// A failed API call with a message that is safe to show the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Machine-readable code from the server when present (e.g. `EMAIL_NOT_VERIFIED`).
  final String? code;

  /// Backend request id, quoted in support questions and matched against server logs.
  final String? requestId;

  ApiException(this.message, {this.statusCode, this.code, this.requestId});

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}

class MultipartFileItem {
  final String field;
  final String? filePath;
  final List<int>? fileBytes;
  final String filename;

  MultipartFileItem({
    required this.field,
    this.filePath,
    this.fileBytes,
    required this.filename,
  });
}

/// HTTP client for the Spring Boot API.
///
/// * Sends `Authorization: Bearer <access token>` when signed in.
/// * On a 401 it refreshes the access token once (shared by concurrent requests) and retries.
/// * Sends an `X-Request-Id` so a request can be followed through the backend trace logs.
/// * Turns every failure into an [ApiException] with a readable message, including non-JSON
///   error bodies (Spring Security's 401/403 have no JSON body).
class ApiClient {
  static http.Client _http = http.Client();
  static String? _accessToken;

  /// Set by AuthProvider: exchanges the refresh token for a new access token, or returns null.
  static Future<String?> Function()? onRefreshToken;

  /// Set by AuthProvider: called when the session can't be recovered (refresh failed).
  static Future<void> Function()? onSessionExpired;

  static Future<String?>? _refreshInFlight;

  @visibleForTesting
  static set httpClient(http.Client client) => _http = client;

  static void setAccessToken(String? token) => _accessToken = token;
  static bool get hasAccessToken => _accessToken != null;

  static final Random _random = Random();

  static String _newRequestId() {
    final bytes = List<int>.generate(8, (_) => _random.nextInt(256));
    return 'app-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  static Map<String, String> _headers({bool json = true, String? requestId}) => {
        if (json) 'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Request-Id': requestId ?? _newRequestId(),
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// Builds `/api/<path>?query`. Query values are URL-encoded (emails with `+` or `&` are safe).
  static Uri buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final params = queryParameters?.map((k, v) => MapEntry(k, v.toString()));
    final uri = Uri.parse('${ApiConfig.baseUrl}$normalizedPath');
    return (params == null || params.isEmpty) ? uri : uri.replace(queryParameters: {...uri.queryParameters, ...params});
  }

  static Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) =>
      _send<T>('GET', path, queryParameters: queryParameters, fromJsonT: fromJsonT);

  static Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) =>
      _send<T>('POST', path, body: body, queryParameters: queryParameters, fromJsonT: fromJsonT);

  static Future<ApiResponse<T>> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) =>
      _send<T>('PUT', path, body: body, queryParameters: queryParameters, fromJsonT: fromJsonT);

  static Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) =>
      _send<T>('DELETE', path, queryParameters: queryParameters, fromJsonT: fromJsonT);

  static Future<ApiResponse<T>> _send<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
    bool isRetry = false,
  }) async {
    final uri = buildUri(path, queryParameters);
    final requestId = _newRequestId();
    final started = DateTime.now();
    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(_headers(requestId: requestId));
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(ApiConfig.timeoutDuration);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Check your connection and try again.',
          requestId: requestId);
    } on http.ClientException catch (e) {
      debugPrint('[api] $method $uri network error: ${e.message} (requestId=$requestId)');
      throw ApiException("Can't reach Sound Marketplace. Check your internet connection.", requestId: requestId);
    }

    debugPrint('[api] $method ${uri.path} -> ${response.statusCode} '
        '${DateTime.now().difference(started).inMilliseconds}ms (requestId=$requestId)');

    // Never auto-refresh for /auth/* calls: a 401 from /auth/refresh would otherwise wait on
    // its own in-flight refresh forever.
    final isAuthCall = path.startsWith('/auth/') || path.startsWith('auth/');
    if (response.statusCode == 401 && !isRetry && !isAuthCall && _accessToken != null && onRefreshToken != null) {
      final refreshed = await _refreshOnce();
      if (refreshed != null) {
        return _send<T>(method, path,
            body: body, queryParameters: queryParameters, fromJsonT: fromJsonT, isRetry: true);
      }
      await onSessionExpired?.call();
    }
    return _handleResponse<T>(response, fromJsonT, requestId);
  }

  /// One refresh at a time; concurrent 401s wait for the same result.
  static Future<String?> _refreshOnce() {
    return _refreshInFlight ??= () async {
      try {
        final token = await onRefreshToken!.call();
        _accessToken = token;
        return token;
      } finally {
        _refreshInFlight = null;
      }
    }();
  }

  static Future<ApiResponse<T>> postMultipart<T>(
    String path, {
    String? fileField,
    String? filePath,
    List<int>? fileBytes,
    String? filename,
    List<MultipartFileItem>? files,
    Map<String, String>? fields,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) async {
    final uri = buildUri(path, queryParameters);
    final requestId = _newRequestId();
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(json: false, requestId: requestId));
    if (fields != null) request.fields.addAll(fields);

    Future<void> addFile(String field, String name, String? fPath, List<int>? bytes) async {
      if (bytes != null && bytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(field, bytes, filename: name));
      } else if (fPath != null && fPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(field, fPath, filename: name));
      }
    }

    if (fileField != null && filename != null) await addFile(fileField, filename, filePath, fileBytes);
    for (final item in files ?? const <MultipartFileItem>[]) {
      await addFile(item.field, item.filename, item.filePath, item.fileBytes);
    }

    try {
      // Uploads can be large; allow far longer than normal JSON calls.
      final streamed = await _http.send(request).timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(streamed);
      return _handleResponse<T>(response, fromJsonT, requestId);
    } on TimeoutException {
      throw ApiException('The upload timed out. Try a smaller file or a faster connection.', requestId: requestId);
    } on http.ClientException catch (e) {
      debugPrint('[api] upload $uri network error: ${e.message} (requestId=$requestId)');
      throw ApiException("Can't reach Sound Marketplace. Check your internet connection.", requestId: requestId);
    }
  }

  static ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic json)? fromJsonT,
    String requestId,
  ) {
    final status = response.statusCode;
    final ok = status >= 200 && status < 300;

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null; // HTML or plain-text error page
      }
    }

    if (!ok) {
      final serverMessage = decoded is Map ? decoded['message']?.toString() : null;
      final serverRequestId = decoded is Map ? decoded['requestId']?.toString() : null;
      throw ApiException(
        _friendlyMessage(status, serverMessage),
        statusCode: status,
        code: _knownCode(serverMessage),
        requestId: serverRequestId ?? response.headers['x-request-id'] ?? requestId,
      );
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('success')) {
      return ApiResponse<T>.fromJson(decoded, fromJsonT);
    }
    return ApiResponse<T>(
      success: true,
      data: decoded == null ? null : (fromJsonT != null ? fromJsonT(decoded) : decoded as T?),
    );
  }

  static const _codes = ['EMAIL_NOT_VERIFIED', 'ACCOUNT_DISABLED'];

  static String? _knownCode(String? message) {
    if (message == null) return null;
    for (final c in _codes) {
      if (message.contains(c)) return c;
    }
    return null;
  }

  static String _friendlyMessage(int status, String? serverMessage) {
    final code = _knownCode(serverMessage);
    if (code == 'EMAIL_NOT_VERIFIED') return 'Please verify your email before signing in.';
    if (code == 'ACCOUNT_DISABLED') return 'This account has been disabled. Contact support.';
    if (serverMessage != null && serverMessage.trim().isNotEmpty && status < 500) return serverMessage;
    switch (status) {
      case 400:
        return 'Some details are invalid. Check the form and try again.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return "We couldn't find what you were looking for.";
      case 409:
        return 'That conflicts with something that already exists.';
      case 413:
        return 'That file is too large.';
      case 415:
        return "That file type isn't supported.";
      case 429:
        return 'Too many attempts. Wait a minute and try again.';
      default:
        return 'Something went wrong on our side. Please try again.';
    }
  }
}
