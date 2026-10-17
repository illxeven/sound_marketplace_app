import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_response.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

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

class ApiClient {
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static void setAuthUser(int? userId) {
    if (userId != null) {
      _headers['X-User-Id'] = userId.toString();
    } else {
      _headers.remove('X-User-Id');
    }
  }

  static Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    String base = ApiConfig.baseUrl;
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    String normalizedPath = path.startsWith('/') ? path : '/$path';

    Map<String, String>? stringParams;
    if (queryParameters != null) {
      stringParams = queryParameters.map((k, v) => MapEntry(k, v.toString()));
    }

    return Uri.parse('$base$normalizedPath').replace(queryParameters: stringParams);
  }

  static Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await http
          .get(uri, headers: _headers)
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response, fromJsonT);
    } catch (e) {
      throw _handleError(e);
    }
  }

  static Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response, fromJsonT);
    } catch (e) {
      throw _handleError(e);
    }
  }

  static Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await http
          .put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response, fromJsonT);
    } catch (e) {
      throw _handleError(e);
    }
  }

  static Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await http
          .delete(uri, headers: _headers)
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response, fromJsonT);
    } catch (e) {
      throw _handleError(e);
    }
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
    try {
      final uri = _buildUri(path, queryParameters);
      final request = http.MultipartRequest('POST', uri);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (fileField != null && filename != null) {
        if (fileBytes != null && fileBytes.isNotEmpty) {
          request.files.add(
            http.MultipartFile.fromBytes(
              fileField,
              fileBytes,
              filename: filename,
            ),
          );
        } else if (filePath != null && filePath.isNotEmpty) {
          request.files.add(
            await http.MultipartFile.fromPath(
              fileField,
              filePath,
              filename: filename,
            ),
          );
        }
      }

      if (files != null) {
        for (final item in files) {
          if (item.fileBytes != null && item.fileBytes!.isNotEmpty) {
            request.files.add(
              http.MultipartFile.fromBytes(
                item.field,
                item.fileBytes!,
                filename: item.filename,
              ),
            );
          } else if (item.filePath != null && item.filePath!.isNotEmpty) {
            request.files.add(
              await http.MultipartFile.fromPath(
                item.field,
                item.filePath!,
                filename: item.filename,
              ),
            );
          }
        }
      }

      final streamedResponse = await request.send().timeout(ApiConfig.timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response, fromJsonT);
    } catch (e) {
      throw _handleError(e);
    }
  }

  static ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic json)? fromJsonT,
  ) {
    if (response.body.isEmpty) {
      return ApiResponse<T>(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: 'No response body',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final apiResponse = ApiResponse<T>.fromJson(decoded, fromJsonT);
      if (!apiResponse.success && response.statusCode >= 400) {
        throw ApiException(apiResponse.message ?? 'Server error', statusCode: response.statusCode);
      }
      return apiResponse;
    } else {
      return ApiResponse<T>(
        success: response.statusCode >= 200 && response.statusCode < 300,
        data: fromJsonT != null ? fromJsonT(decoded) : decoded as T?,
      );
    }
  }

  static ApiException _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }
    return ApiException(
      'Connection failed: Unable to reach Sound Marketplace backend. Check if the server is running on ${ApiConfig.baseUrl}. Details: $error',
    );
  }
}
