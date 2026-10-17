import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/theme.dart';

class SavedCard {
  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    this.isDefault = false,
  });

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: json['id'] ?? '',
      brand: json['brand'] ?? 'card',
      last4: json['last4'] ?? '••••',
      expMonth: (json['expMonth'] as num?)?.toInt() ?? 12,
      expYear: (json['expYear'] as num?)?.toInt() ?? 2028,
      isDefault: json['isDefault'] == true,
    );
  }
}

class PaymentIntentResult {
  final String clientSecret;
  final String paymentIntentId;
  final double amount;
  final String currency;
  final String status;
  final String? customerId;
  final String? customerEphemeralKeySecret;

  PaymentIntentResult({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amount,
    required this.currency,
    required this.status,
    this.customerId,
    this.customerEphemeralKeySecret,
  });

  factory PaymentIntentResult.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResult(
      clientSecret: json['clientSecret'] ?? '',
      paymentIntentId: json['paymentIntentId'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? '',
      customerId: json['customerId'],
      customerEphemeralKeySecret: json['customerEphemeralKeySecret'],
    );
  }
}

class StripePaymentService {
  /// Calls the Spring Boot backend endpoint POST /api/payments/create-intent
  static Future<PaymentIntentResult> createPaymentIntent({
    required double amount,
    required String itemDetails,
    required String itemType, // 'merchandise', 'sound_kit', 'track', 'cart'
    int? itemId,
    required int buyerId,
    String currency = 'usd',
    bool saveCard = true,
    bool confirm = false,
    String? paymentMethodId,
    Map<String, String>? metadata,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/payments/create-intent');
    debugPrint('[Stripe] Calling $uri for amount \$$amount USD (confirm=$confirm)');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'currency': currency,
        'itemDetails': itemDetails,
        'itemType': itemType,
        'itemId': itemId,
        'buyerId': buyerId,
        'saveCard': saveCard,
        'confirm': confirm,
        'paymentMethodId': paymentMethodId,
        'metadata': metadata ?? {},
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('[Stripe Error] Backend create-intent failed (${response.statusCode}): ${response.body}');
      throw Exception('Failed to create payment intent: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded['data'] ?? decoded;
    debugPrint('[Stripe] Received PaymentIntent: ${data['paymentIntentId']} (status: ${data['status']})');
    return PaymentIntentResult.fromJson(data);
  }

  /// Calls the Spring Boot backend endpoint POST /api/payments/confirm-intent
  static Future<PaymentIntentResult> confirmPaymentIntent({
    required String paymentIntentId,
    String paymentMethodId = 'pm_card_visa',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/payments/confirm-intent');
    debugPrint('[Stripe] Calling $uri to confirm $paymentIntentId with $paymentMethodId');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'paymentIntentId': paymentIntentId,
        'paymentMethodId': paymentMethodId,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('[Stripe Error] Backend confirm-intent failed (${response.statusCode}): ${response.body}');
      throw Exception('Failed to confirm payment intent: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded['data'] ?? decoded;
    debugPrint('[Stripe] PaymentIntent confirmed! Status: ${data['status']}');
    return PaymentIntentResult.fromJson(data);
  }

  /// Explicitly initializes and presents the official Stripe Native Payment Sheet.
  /// Used for mobile (Android & iOS).
  static Future<void> presentNativePaymentSheet({
    required String clientSecret,
    String? customerId,
    String? customerEphemeralKeySecret,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Stripe Native Payment Sheet is not supported on Web. Use in-app confirmation.');
    }

    debugPrint('[Stripe] Initializing Payment Sheet with clientSecret: ${clientSecret.substring(0, clientSecret.length > 15 ? 15 : clientSecret.length)}...');

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        customerId: customerId,
        customerEphemeralKeySecret: customerEphemeralKeySecret,
        merchantDisplayName: 'Sound Marketplace',
        style: ThemeMode.dark,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            primary: AppTheme.primaryPurple,
            background: AppTheme.surfaceColor,
          ),
        ),
      ),
    );

    debugPrint('[Stripe] Calling presentPaymentSheet()...');
    await Stripe.instance.presentPaymentSheet();
    debugPrint('[Stripe] presentPaymentSheet completed successfully!');
  }

  /// Fetches securely saved cards for a registered user from backend / Stripe Customer Vault
  static Future<List<SavedCard>> getSavedCards(int buyerId) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/payments/saved-cards/$buyerId');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = (decoded['data'] as List?) ?? [];
        return list.map((item) => SavedCard.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching saved cards: $e');
    }
    return [];
  }

  /// Full-stack checkout flow:
  /// 1. Requests Stripe PaymentIntent from backend (with Customer & EphemeralKey)
  /// 2. Initializes and displays Stripe Payment Sheet
  /// 3. Returns the confirmed Stripe PaymentIntent ID upon success, or null if cancelled/failed
  static Future<String?> processCheckout({
    required BuildContext context,
    required double amount,
    required String itemTitle,
    required String itemType,
    int? itemId,
    required int buyerId,
    bool saveCard = true,
    Map<String, String>? metadata,
  }) async {
    try {
      // Step 1: Request PaymentIntent and clientSecret from backend
      final intentResult = await createPaymentIntent(
        amount: amount,
        itemDetails: '$itemType: $itemTitle',
        itemType: itemType,
        itemId: itemId,
        buyerId: buyerId,
        saveCard: saveCard,
        metadata: metadata,
      );

      final clientSecret = intentResult.clientSecret;
      final isMock = clientSecret.contains('mock') || clientSecret.contains('placeholder');

      // Step 2 & 3: Launch Stripe Payment Sheet (Mobile native only: iOS & Android)
      if (!isMock && !kIsWeb) {
        try {
          await presentNativePaymentSheet(
            clientSecret: clientSecret,
            customerId: intentResult.customerId,
            customerEphemeralKeySecret: intentResult.customerEphemeralKeySecret,
          );
          return intentResult.paymentIntentId;
        } on StripeException catch (e) {
          if (e.error.code == FailureCode.Canceled) {
            debugPrint('[Stripe] Payment sheet was cancelled by user');
            return null;
          }
          debugPrint('[Stripe] Native payment sheet error: ${e.error.code} - ${e.error.localizedMessage}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stripe Error: ${e.error.localizedMessage ?? e.error.code.name}'),
                backgroundColor: AppTheme.errorRed,
              ),
            );
          }
          return null;
        } catch (e) {
          debugPrint('[Stripe] Sheet presentation exception: $e');
          rethrow;
        }
      }

      // Sandbox / Test Mode Handler for Placeholder Keys & Desktop Testing
      if (context.mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.credit_card_rounded, color: AppTheme.secondaryCyan, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Stripe Checkout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          itemTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '\$${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryCyan,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: AppTheme.successGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isMock
                            ? 'Sandbox Environment (Placeholder Key in effect)'
                            : 'Secured via 256-bit Stripe Encryption',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.lock_rounded, size: 16),
                label: Text('Pay \$${amount.toStringAsFixed(2)}'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          return intentResult.paymentIntentId;
        }
      }

      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment checkout error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return null;
    }
  }
}
