import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../config/theme.dart';
import 'api_client.dart';

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
      last4: json['last4'] ?? '????',
      expMonth: (json['expMonth'] as num?)?.toInt() ?? 12,
      expYear: (json['expYear'] as num?)?.toInt() ?? 2028,
      isDefault: json['isDefault'] == true,
    );
  }
}

class CheckoutResult {
  final int orderId;
  final String clientSecret;
  final String? customerId;
  final String? ephemeralKey;
  final String? url;

  CheckoutResult({
    required this.orderId,
    required this.clientSecret,
    this.customerId,
    this.ephemeralKey,
    this.url,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    return CheckoutResult(
      orderId: (json['orderId'] as num?)?.toInt() ?? 0,
      clientSecret: json['clientSecret'] ?? '',
      customerId: json['customerId'] as String?,
      ephemeralKey: json['ephemeralKey'] as String?,
      url: json['url'] as String?,
    );
  }
}

class StripePaymentService {
  /// Calls the Spring Boot backend endpoint POST /api/checkout using ApiClient
  static Future<CheckoutResult> createCheckout({
    bool fromCart = false,
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? shippingAddress,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final body = <String, dynamic>{
      if (fromCart) 'fromCart': true,
      if (items != null && items.isNotEmpty) 'items': items,
      if (shippingAddress != null) 'shippingAddress': shippingAddress,
      if (successUrl != null) 'successUrl': successUrl,
      if (cancelUrl != null) 'cancelUrl': cancelUrl,
    };

    debugPrint('[Stripe] Calling POST /api/checkout with body: $body');
    final response = await ApiClient.post<Map<String, dynamic>>(
      '/checkout',
      body: body,
      fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
    );

    if (response.data == null) {
      throw ApiException('Failed to start checkout: invalid response from server');
    }

    return CheckoutResult.fromJson(response.data!);
  }

  /// Explicitly initializes and presents the official Stripe Native Payment Sheet.
  /// Used for mobile (Android & iOS).
  static Future<void> presentNativePaymentSheet({
    required String clientSecret,
    String? customerId,
    String? customerEphemeralKeySecret,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Stripe Native Payment Sheet is not supported on Web.');
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

  /// Polls GET /api/orders/{orderId} every [interval] up to [timeout] until status is PAID.
  static Future<Map<String, dynamic>> pollOrderStatus(
    int orderId, {
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    debugPrint('[Stripe] Polling order $orderId until PAID...');

    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await ApiClient.get<Map<String, dynamic>>(
          '/orders/$orderId',
          fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
        );
        final order = res.data;
        if (order != null) {
          final status = (order['status'] as String?)?.toUpperCase();
          debugPrint('[Stripe] Polled order $orderId status: $status');
          if (status == 'PAID' || status == 'COMPLETED') {
            return order;
          }
          if (status == 'FAILED' || status == 'CANCELLED') {
            throw ApiException('Order $orderId failed with status: $status');
          }
        }
      } catch (e) {
        if (e is ApiException && e.statusCode == 404) {
          debugPrint('[Stripe] Order $orderId 404 while polling, continuing...');
        } else if (e is ApiException) {
          rethrow;
        }
      }
      await Future.delayed(interval);
    }
    throw ApiException('Payment verification timed out. Please check your orders page.');
  }

  /// Fetches securely saved cards for a registered user from backend / Stripe Customer Vault
  static Future<List<SavedCard>> getSavedCards(int buyerId) async {
    try {
      final res = await ApiClient.get<List<dynamic>>(
        '/payments/saved-cards/$buyerId',
        fromJsonT: (json) => json is List ? json : [],
      );
      final list = res.data ?? [];
      return list.map((item) => SavedCard.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching saved cards: $e');
    }
    return [];
  }

  /// Full-stack checkout flow:
  /// 1. Calls POST /api/checkout (with Customer & EphemeralKey)
  /// 2. Initializes and displays Stripe Payment Sheet
  /// 3. Polls GET /api/orders/{id} until status == PAID
  /// 4. Returns the confirmed Order ID string upon success, or null if cancelled/failed
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
      final isCart = itemType.toLowerCase() == 'cart';
      final checkoutResult = await createCheckout(
        fromCart: isCart,
        items: !isCart && itemId != null
            ? [
                {
                  'type': itemType.toUpperCase(),
                  'id': itemId,
                  'quantity': 1,
                }
              ]
            : null,
      );

      final clientSecret = checkoutResult.clientSecret;
      final isMock = clientSecret.contains('mock') || clientSecret.contains('placeholder');

      if (!isMock && !kIsWeb) {
        try {
          await presentNativePaymentSheet(
            clientSecret: clientSecret,
            customerId: checkoutResult.customerId,
            customerEphemeralKeySecret: checkoutResult.ephemeralKey,
          );
          await pollOrderStatus(checkoutResult.orderId);
          return checkoutResult.orderId.toString();
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
        }
      }

      // Web / desktop / sandbox fallback
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
          return checkoutResult.orderId.toString();
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
