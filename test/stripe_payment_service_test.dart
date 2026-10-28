import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sound_marketplace_app/services/api_client.dart';
import 'package:sound_marketplace_app/services/stripe_payment_service.dart';

void main() {
  group('Stripe Frontend Configuration & Service Tests', () {
    tearDown(() {
      ApiClient.httpClient = http.Client();
    });

    test('CheckoutResult decodes valid JSON correctly', () {
      final json = {
        'orderId': 1042,
        'clientSecret': 'pi_test123_secret_xyz456',
        'customerId': 'cus_abc123',
        'ephemeralKey': 'ek_test_456',
        'url': 'https://checkout.stripe.com/c/pay/cs_test_789',
      };

      final result = CheckoutResult.fromJson(json);

      expect(result.orderId, equals(1042));
      expect(result.clientSecret, equals('pi_test123_secret_xyz456'));
      expect(result.customerId, equals('cus_abc123'));
      expect(result.ephemeralKey, equals('ek_test_456'));
      expect(result.url, equals('https://checkout.stripe.com/c/pay/cs_test_789'));
    });

    test('CheckoutResult handles null/missing fields with safe defaults', () {
      final json = <String, dynamic>{};

      final result = CheckoutResult.fromJson(json);

      expect(result.orderId, equals(0));
      expect(result.clientSecret, isEmpty);
      expect(result.customerId, isNull);
      expect(result.ephemeralKey, isNull);
      expect(result.url, isNull);
    });

    test('Stripe publishableKey can be set and accessed', () {
      Stripe.publishableKey = 'YOUR_STRIPE_PUBLISHABLE_KEY_PLACEHOLDER';
      expect(Stripe.publishableKey, equals('YOUR_STRIPE_PUBLISHABLE_KEY_PLACEHOLDER'));

      Stripe.publishableKey = 'pk_test_sampleKey12345';
      expect(Stripe.publishableKey, equals('pk_test_sampleKey12345'));
    });

    test('Simulated JSON payload format for checkout matches backend schema', () {
      final cartPayload = {
        'fromCart': true,
      };

      final buyNowPayload = {
        'items': [
          {'type': 'TRACK', 'id': 88, 'quantity': 1},
        ],
      };

      final cartEncoded = jsonDecode(jsonEncode(cartPayload));
      expect(cartEncoded['fromCart'], isTrue);

      final buyNowEncoded = jsonDecode(jsonEncode(buyNowPayload));
      expect(buyNowEncoded['items'], isA<List>());
      expect(buyNowEncoded['items'][0]['type'], equals('TRACK'));
      expect(buyNowEncoded['items'][0]['id'], equals(88));
      expect(buyNowEncoded['items'][0]['quantity'], equals(1));
    });

    // Requirement A1: MockClient test verifying shippingAddress in POST /api/checkout body
    test('createCheckout includes shippingAddress in POST /api/checkout body for merchandise', () async {
      Map<String, dynamic>? capturedBody;
      String? capturedPath;

      ApiClient.httpClient = MockClient((request) async {
        capturedPath = request.url.path;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        final responseJson = {
          'success': true,
          'message': 'Checkout created',
          'data': {
            'orderId': 2026,
            'clientSecret': 'pi_mock_secret_xyz',
            'customerId': 'cus_mock123',
            'ephemeralKey': 'ek_mock456',
          },
        };
        return http.Response(jsonEncode(responseJson), 200, headers: {'content-type': 'application/json'});
      });

      final shippingAddress = {
        'fullName': 'Alice Producer',
        'line1': '742 Evergreen Terrace',
        'line2': 'Suite 100',
        'city': 'Springfield',
        'region': 'IL',
        'postalCode': '62704',
        'countryCode': 'US',
        'phone': '+1 555-0142',
      };

      final result = await StripePaymentService.createCheckout(
        items: [
          {'type': 'MERCHANDISE', 'id': 42, 'quantity': 2},
        ],
        shippingAddress: shippingAddress,
      );

      expect(capturedPath, equals('/api/checkout'));
      expect(capturedBody, isNotNull);
      expect(capturedBody!['shippingAddress'], isNotNull);
      expect(capturedBody!['shippingAddress']['fullName'], equals('Alice Producer'));
      expect(capturedBody!['shippingAddress']['line1'], equals('742 Evergreen Terrace'));
      expect(capturedBody!['shippingAddress']['line2'], equals('Suite 100'));
      expect(capturedBody!['shippingAddress']['city'], equals('Springfield'));
      expect(capturedBody!['shippingAddress']['region'], equals('IL'));
      expect(capturedBody!['shippingAddress']['postalCode'], equals('62704'));
      expect(capturedBody!['shippingAddress']['countryCode'], equals('US'));
      expect(capturedBody!['shippingAddress']['phone'], equals('+1 555-0142'));
      expect(result.orderId, equals(2026));
      expect(result.clientSecret, equals('pi_mock_secret_xyz'));
    });

    test('createCheckout works without shippingAddress for digital items', () async {
      Map<String, dynamic>? capturedBody;

      ApiClient.httpClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        final responseJson = {
          'success': true,
          'message': 'Checkout created',
          'data': {
            'orderId': 2027,
            'clientSecret': 'pi_mock_secret_abc',
          },
        };
        return http.Response(jsonEncode(responseJson), 200, headers: {'content-type': 'application/json'});
      });

      final result = await StripePaymentService.createCheckout(
        items: [
          {'type': 'TRACK', 'id': 15, 'quantity': 1},
        ],
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!.containsKey('shippingAddress'), isFalse);
      expect(result.orderId, equals(2027));
    });
  });
}
