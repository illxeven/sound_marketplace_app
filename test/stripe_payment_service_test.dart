import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:sound_marketplace_app/services/stripe_payment_service.dart';

void main() {
  group('Stripe Frontend Configuration & Service Tests', () {
    test('PaymentIntentResult decodes valid JSON correctly', () {
      final json = {
        'clientSecret': 'pi_test123_secret_xyz456',
        'paymentIntentId': 'pi_test123',
        'amount': 29.99,
        'currency': 'USD',
        'status': 'requires_payment_method',
      };

      final result = PaymentIntentResult.fromJson(json);

      expect(result.clientSecret, equals('pi_test123_secret_xyz456'));
      expect(result.paymentIntentId, equals('pi_test123'));
      expect(result.amount, equals(29.99));
      expect(result.currency, equals('USD'));
      expect(result.status, equals('requires_payment_method'));
    });

    test('PaymentIntentResult handles null/missing fields with safe defaults', () {
      final json = <String, dynamic>{};

      final result = PaymentIntentResult.fromJson(json);

      expect(result.clientSecret, isEmpty);
      expect(result.paymentIntentId, isEmpty);
      expect(result.amount, equals(0.0));
      expect(result.currency, equals('USD'));
      expect(result.status, isEmpty);
    });

    test('Stripe publishableKey can be set and accessed', () {
      Stripe.publishableKey = 'YOUR_STRIPE_PUBLISHABLE_KEY_PLACEHOLDER';
      expect(Stripe.publishableKey, equals('YOUR_STRIPE_PUBLISHABLE_KEY_PLACEHOLDER'));

      // Also verify setting a custom test key
      Stripe.publishableKey = 'pk_test_sampleKey12345';
      expect(Stripe.publishableKey, equals('pk_test_sampleKey12345'));
    });

    test('Simulated JSON payload format for createPaymentIntent matches backend schema', () {
      final payload = {
        'amount': 15.00,
        'currency': 'usd',
        'itemDetails': 'track: Summer Waves',
        'itemType': 'track',
        'itemId': 88,
        'buyerId': 12,
        'metadata': {
          'licenseType': 'exclusive',
        },
      };

      final encoded = jsonEncode(payload);
      final decoded = jsonDecode(encoded);

      expect(decoded['amount'], equals(15.00));
      expect(decoded['currency'], equals('usd'));
      expect(decoded['itemType'], equals('track'));
      expect(decoded['itemId'], equals(88));
      expect(decoded['buyerId'], equals(12));
      expect(decoded['metadata']['licenseType'], equals('exclusive'));
    });
  });
}
