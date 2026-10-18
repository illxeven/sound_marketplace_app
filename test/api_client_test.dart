import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sound_marketplace_app/config/api_config.dart';
import 'package:sound_marketplace_app/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.setAccessToken(null);
    ApiClient.onRefreshToken = null;
    ApiClient.onSessionExpired = null;
  });

  test('resolve() never produces /api/api for server paths', () {
    final cover = ApiConfig.resolve('/api/tracks/5/cover');
    expect(cover, endsWith('/api/tracks/5/cover'));
    expect(cover, isNot(contains('/api/api/')));
    expect(ApiConfig.resolve('https://cdn.example.com/a.jpg'), 'https://cdn.example.com/a.jpg');
    expect(ApiConfig.resolve('/tracks/5'), endsWith('/api/tracks/5'));
  });

  test('query values are URL-encoded (emails with + and &)', () {
    final uri = ApiClient.buildUri('/auth/resend-verification', {'email': 'a+b&c@example.com'});
    expect(uri.queryParameters['email'], 'a+b&c@example.com');
    expect(uri.toString(), contains('a%2Bb%26c%40example.com'));
  });

  test('non-JSON 401 becomes a readable ApiException', () async {
    ApiClient.httpClient = MockClient((_) async => http.Response('', 401));
    await expectLater(
      ApiClient.get('/users/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401).having((e) => e.message, 'message',
          contains('session'))),
    );
  });

  test('EMAIL_NOT_VERIFIED code is surfaced for the sign-in screen', () async {
    ApiClient.httpClient = MockClient((_) async =>
        http.Response(jsonEncode({'success': false, 'message': 'EMAIL_NOT_VERIFIED'}), 403));
    await expectLater(
      ApiClient.post('/auth/login', body: {'email': 'x@y.z', 'password': 'p'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'EMAIL_NOT_VERIFIED')),
    );
  });

  test('401 refreshes once, retries with the new token, and concurrent calls share the refresh', () async {
    var refreshes = 0;
    final seenTokens = <String?>[];
    ApiClient.setAccessToken('old');
    ApiClient.onRefreshToken = () async {
      refreshes++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return 'new';
    };
    ApiClient.httpClient = MockClient((req) async {
      final auth = req.headers['Authorization'];
      seenTokens.add(auth);
      if (auth == 'Bearer old') return http.Response('', 401);
      return http.Response(jsonEncode({'success': true, 'data': 1}), 200);
    });

    final results = await Future.wait([ApiClient.get<int>('/a'), ApiClient.get<int>('/b')]);
    expect(results.map((r) => r.data), [1, 1]);
    expect(refreshes, 1);
    expect(seenTokens.where((t) => t == 'Bearer new').length, 2);
  });

  test('a 401 from /auth/refresh does not try to refresh itself (no deadlock)', () async {
    ApiClient.setAccessToken('old');
    var refreshes = 0;
    ApiClient.onRefreshToken = () async {
      refreshes++;
      return null;
    };
    ApiClient.httpClient = MockClient((_) async => http.Response('', 401));
    await expectLater(ApiClient.post('/auth/refresh', body: {'refreshToken': 'r'}), throwsA(isA<ApiException>()));
    expect(refreshes, 0);
  });

  test('every request carries an X-Request-Id', () async {
    String? requestId;
    ApiClient.httpClient = MockClient((req) async {
      requestId = req.headers['X-Request-Id'];
      return http.Response(jsonEncode({'success': true}), 200);
    });
    await ApiClient.get('/genres');
    expect(requestId, startsWith('app-'));
  });
}
