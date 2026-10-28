import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/user_account.dart';
import '../providers/cart_provider.dart';
import '../services/api_client.dart';
import '../services/stripe_payment_service.dart';

class CheckoutScreen extends StatefulWidget {
  final double amount;
  final String itemTitle;
  final String itemType;
  final int? itemId;
  final UserAccount user;
  final Map<String, String>? metadata;
  final bool? hasMerchandise;

  const CheckoutScreen({
    super.key,
    required this.amount,
    required this.itemTitle,
    required this.itemType,
    this.itemId,
    required this.user,
    this.metadata,
    this.hasMerchandise,
  });

  static Future<String?> startCheckout({
    required BuildContext context,
    required double amount,
    required String itemTitle,
    required String itemType,
    int? itemId,
    required UserAccount user,
    Map<String, String>? metadata,
    bool? hasMerchandise,
  }) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => CheckoutScreen(
          amount: amount,
          itemTitle: itemTitle,
          itemType: itemType,
          itemId: itemId,
          user: user,
          metadata: metadata,
          hasMerchandise: hasMerchandise,
        ),
      ),
    );
  }

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shippingFormKey = GlobalKey<FormState>();

  final _cardNumberController = TextEditingController();
  final _expController = TextEditingController();
  final _cvcController = TextEditingController();
  final _zipController = TextEditingController();
  final _nameController = TextEditingController();

  // Shipping Address controllers for merchandise orders
  final _shipFullNameController = TextEditingController();
  final _shipLine1Controller = TextEditingController();
  final _shipLine2Controller = TextEditingController();
  final _shipCityController = TextEditingController();
  final _shipRegionController = TextEditingController();
  final _shipPostalCodeController = TextEditingController();
  final _shipCountryCodeController = TextEditingController();
  final _shipPhoneController = TextEditingController();

  bool _saveCardForFuture = true;
  bool _isProcessing = false;
  String? _serverErrorMessage;
  List<SavedCard> _savedCards = [];
  SavedCard? _selectedSavedCard;
  bool _isLoadingCards = true;

  bool get _requiresShipping {
    if (widget.hasMerchandise != null) return widget.hasMerchandise!;
    if (widget.itemType.toLowerCase() == 'merchandise') return true;
    if (widget.itemType.toLowerCase() == 'cart') {
      try {
        final cartProv = Provider.of<CartProvider>(context, listen: false);
        if (cartProv.items.any((i) => i.isMerchandise)) return true;
      } catch (_) {}
    }
    return false;
  }

  Map<String, dynamic>? _buildShippingAddress() {
    if (!_requiresShipping) return null;
    return {
      'fullName': _shipFullNameController.text.trim(),
      'line1': _shipLine1Controller.text.trim(),
      if (_shipLine2Controller.text.trim().isNotEmpty) 'line2': _shipLine2Controller.text.trim(),
      'city': _shipCityController.text.trim(),
      if (_shipRegionController.text.trim().isNotEmpty) 'region': _shipRegionController.text.trim(),
      'postalCode': _shipPostalCodeController.text.trim(),
      'countryCode': _shipCountryCodeController.text.trim().toUpperCase(),
      if (_shipPhoneController.text.trim().isNotEmpty) 'phone': _shipPhoneController.text.trim(),
    };
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.effectiveName;
    _shipFullNameController.text = widget.user.effectiveName;
    final country = widget.user.country?.trim() ?? '';
    _shipCountryCodeController.text = country.length == 2 ? country.toUpperCase() : 'US';
    _loadSavedCards();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expController.dispose();
    _cvcController.dispose();
    _zipController.dispose();
    _nameController.dispose();
    _shipFullNameController.dispose();
    _shipLine1Controller.dispose();
    _shipLine2Controller.dispose();
    _shipCityController.dispose();
    _shipRegionController.dispose();
    _shipPostalCodeController.dispose();
    _shipCountryCodeController.dispose();
    _shipPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCards() async {
    try {
      final cards = await StripePaymentService.getSavedCards(widget.user.id);
      if (mounted) {
        setState(() {
          _savedCards = cards;
          _isLoadingCards = false;
          if (cards.isNotEmpty) {
            _selectedSavedCard = cards.firstWhere((c) => c.isDefault, orElse: () => cards.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCards = false);
    }
  }

  void _fillStripeTestCard() {
    setState(() {
      _selectedSavedCard = null;
      _cardNumberController.text = '4242 4242 4242 4242';
      _expController.text = '12/34';
      _cvcController.text = '123';
      _zipController.text = '90210';
      _saveCardForFuture = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filled with official Stripe Test Card details!'),
        backgroundColor: AppTheme.secondaryCyan,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Native Mobile Payment Sheet Flow (iOS & Android)
  Future<void> _payWithNativeStripePaymentSheet() async {
    if (_requiresShipping && !(_shippingFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _serverErrorMessage = null;
    });

    try {
      debugPrint('[Checkout] Starting Native Stripe Payment Sheet flow...');
      final isCart = widget.itemType.toLowerCase() == 'cart';
      final checkoutResult = await StripePaymentService.createCheckout(
        fromCart: isCart,
        items: !isCart && widget.itemId != null
            ? [
                {
                  'type': widget.itemType.toUpperCase(),
                  'id': widget.itemId,
                  'quantity': 1,
                }
              ]
            : null,
        shippingAddress: _buildShippingAddress(),
      );

      debugPrint('[Checkout] Presenting Stripe Payment Sheet for Order: ${checkoutResult.orderId}');
      await StripePaymentService.presentNativePaymentSheet(
        clientSecret: checkoutResult.clientSecret,
        customerId: checkoutResult.customerId,
        customerEphemeralKeySecret: checkoutResult.ephemeralKey,
      );

      debugPrint('[Checkout] Polling order ${checkoutResult.orderId}...');
      await StripePaymentService.pollOrderStatus(checkoutResult.orderId);

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context, checkoutResult.orderId.toString());
      }
    } on StripeException catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        if (e.error.code == FailureCode.Canceled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment cancelled by user'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          final msg = e.error.localizedMessage ?? e.error.code.name;
          setState(() => _serverErrorMessage = 'Stripe Error: $msg');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stripe Error: $msg'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _serverErrorMessage = e.message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _serverErrorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Sheet error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  /// In-app card processing / Web test checkout with immediate checkout & order polling
  Future<void> _processPayment() async {
    if (_requiresShipping && !(_shippingFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedSavedCard == null && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _serverErrorMessage = null;
    });

    try {
      debugPrint('[Checkout] Starting checkout via POST /api/checkout...');
      final isCart = widget.itemType.toLowerCase() == 'cart';
      final checkoutResult = await StripePaymentService.createCheckout(
        fromCart: isCart,
        items: !isCart && widget.itemId != null
            ? [
                {
                  'type': widget.itemType.toUpperCase(),
                  'id': widget.itemId,
                  'quantity': 1,
                }
              ]
            : null,
        shippingAddress: _buildShippingAddress(),
      );

      debugPrint('[Checkout] Order created: ${checkoutResult.orderId}');

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context, checkoutResult.orderId.toString());
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _serverErrorMessage = e.message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _serverErrorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processing failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Checkout'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Order Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryPurple.withValues(alpha: 0.25),
                      AppTheme.cardColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.itemType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppTheme.secondaryCyan,
                          ),
                        ),
                        const Row(
                          children: [
                            Icon(Icons.shield_rounded, size: 14, color: AppTheme.successGreen),
                            SizedBox(width: 4),
                            Text(
                              'Stripe Protected',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.itemTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount:', style: TextStyle(color: AppTheme.textSecondary)),
                        Flexible(
                          child: Text(
                            '\$${widget.amount.toStringAsFixed(2)} USD',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryCyan,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Shipping Address Form (required for merchandise items)
              if (_requiresShipping) ...[
                Container(
                  key: const Key('shipping_address_section'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                  ),
                  child: Form(
                    key: _shippingFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, color: AppTheme.secondaryCyan, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Shipping Address',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Required for physical merchandise delivery.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('shipping_full_name'),
                          controller: _shipFullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            hintText: 'John Doe',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('shipping_line1'),
                          controller: _shipLine1Controller,
                          decoration: const InputDecoration(
                            labelText: 'Street Address Line 1 *',
                            hintText: '123 Main St',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Street address is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('shipping_line2'),
                          controller: _shipLine2Controller,
                          decoration: const InputDecoration(
                            labelText: 'Apartment, Suite, Unit (optional)',
                            hintText: 'Apt 4B',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                key: const Key('shipping_city'),
                                controller: _shipCityController,
                                decoration: const InputDecoration(
                                  labelText: 'City *',
                                  hintText: 'New York',
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'City is required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                key: const Key('shipping_region'),
                                controller: _shipRegionController,
                                decoration: const InputDecoration(
                                  labelText: 'State / Region',
                                  hintText: 'NY',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                key: const Key('shipping_postal_code'),
                                controller: _shipPostalCodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Postal / ZIP Code *',
                                  hintText: '10001',
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Postal code is required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                key: const Key('shipping_country_code'),
                                controller: _shipCountryCodeController,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Country Code *',
                                  hintText: 'US',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (v.trim().length != 2) return '2 letters (e.g. US)';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('shipping_phone'),
                          controller: _shipPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number (optional)',
                            hintText: '+1 555-0199',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Server Error Message (shown in red under the form)
              if (_serverErrorMessage != null) ...[
                Container(
                  key: const Key('checkout_server_error_banner'),
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _serverErrorMessage!,
                          key: const Key('checkout_server_error_text'),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Native Stripe Payment Sheet button for mobile (iOS & Android)
              if (!kIsWeb) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _payWithNativeStripePaymentSheet,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: const Color(0xFF635BFF), // Stripe brand purple/indigo
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.payment_rounded, color: Colors.white),
                    label: const Text(
                      'Open Stripe Payment Sheet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white12)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR ENTER CARD DETAILS BELOW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 2. Saved Payment Methods (if any exist)
              if (_isLoadingCards)
                const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
              else if (_savedCards.isNotEmpty) ...[
                const Text(
                  'Saved Payment Methods',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ..._savedCards.map((card) {
                  final isSelected = _selectedSavedCard?.id == card.id;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSavedCard = isSelected ? null : card;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryPurple.withValues(alpha: 0.15)
                            : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.secondaryCyan : Colors.white12,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.credit_card_rounded,
                            color: isSelected ? AppTheme.secondaryCyan : Colors.white70,
                            size: 26,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${card.brand.toUpperCase()} ending in ${card.last4}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Expires ${card.expMonth.toString().padLeft(2, '0')}/${card.expYear}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryCyan, size: 22)
                          else
                            const Icon(Icons.radio_button_off_rounded, color: Colors.white24, size: 22),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white12)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR USE A NEW CARD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 3. New Card Form
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Debit / Credit Card',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _fillStripeTestCard,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: AppTheme.secondaryCyan),
                    label: const Text(
                      'Use Stripe Test Card',
                      style: TextStyle(fontSize: 12, color: AppTheme.secondaryCyan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Cardholder Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Cardholder Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (val) {
                        if (_selectedSavedCard != null) return null;
                        return (val == null || val.trim().isEmpty) ? 'Please enter name on card' : null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Card Number
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        _CardNumberFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '4242 4242 4242 4242',
                        prefixIcon: const Icon(Icons.credit_card_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.help_outline_rounded, size: 18),
                          tooltip: 'Supports Visa, Mastercard, AMEX, Discover debit/credit cards',
                          onPressed: () {},
                        ),
                      ),
                      onChanged: (val) {
                        if (_selectedSavedCard != null) {
                          setState(() => _selectedSavedCard = null);
                        }
                      },
                      validator: (val) {
                        if (_selectedSavedCard != null) return null;
                        final clean = (val ?? '').replaceAll(' ', '');
                        return clean.length < 15 ? 'Enter a valid 15-16 digit card number' : null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Exp Date & CVC & Zip
                    Row(
                      children: [
                        // Expiration
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _expController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              _CardExpFormatter(),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'MM / YY',
                              hintText: '12/34',
                            ),
                            validator: (val) {
                              if (_selectedSavedCard != null) return null;
                              return (val == null || !val.contains('/') || val.length < 5)
                                  ? 'MM/YY'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // CVC
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cvcController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'CVC',
                              hintText: '123',
                            ),
                            validator: (val) {
                              if (_selectedSavedCard != null) return null;
                              return (val == null || val.length < 3) ? 'CVC' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // ZIP
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _zipController,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'ZIP / Postal',
                              hintText: '90210',
                            ),
                            validator: (val) {
                              if (_selectedSavedCard != null) return null;
                              return (val == null || val.trim().isEmpty) ? 'ZIP' : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Save Card Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _saveCardForFuture,
                      activeColor: AppTheme.secondaryCyan,
                      title: const Text(
                        'Save card securely for future purchases',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'Card is encrypted in Stripe\'s PCI-DSS vault. You won\'t have to re-enter it next time.',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                      onChanged: (val) {
                        setState(() => _saveCardForFuture = val ?? true);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Pay Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('checkout_pay_button'),
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(
                    _isProcessing
                        ? 'Processing Payment...'
                        : (_selectedSavedCard != null
                            ? 'Pay \$${widget.amount.toStringAsFixed(2)} with ${_selectedSavedCard!.brand.toUpperCase()} (${_selectedSavedCard!.last4})'
                            : 'Pay \$${widget.amount.toStringAsFixed(2)} Now'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 13, color: Colors.white38),
                    const SizedBox(width: 5),
                    Text(
                      '256-Bit Encrypted via Stripe Payments',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(' ', '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _CardExpFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll('/', '');
    if (text.length > 2) {
      text = '${text.substring(0, 2)}/${text.substring(2)}';
    }
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
