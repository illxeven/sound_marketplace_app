import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_client.dart';
import '../services/json_utils.dart';

class SellerSalesScreen extends StatefulWidget {
  const SellerSalesScreen({super.key});

  @override
  State<SellerSalesScreen> createState() => _SellerSalesScreenState();
}

class _SellerSalesScreenState extends State<SellerSalesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _sales = [];
  int _page = 0;
  bool _hasNext = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.get<Map<String, dynamic>>(
        '/orders/sales', queryParameters: {'page': '$_page', 'size': '20'},
        fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      final data = res.data;
      final rawItems = extractItems(data);
      final items = rawItems.map((i) => (i as Map).cast<String, dynamic>()).toList();

      setState(() {
        if (refresh || _page == 0) {
          _sales = items;
        } else {
          _sales.addAll(items);
        }
        _hasNext = pageHasNext(data);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _showFulfillmentDialog(Map<String, dynamic> sale) async {
    final orderItemId = sale['orderItemId'];
    final currentCarrier = sale['carrier'] as String? ?? 'USPS';
    final currentTracking = sale['trackingNumber'] as String? ?? '';

    final carrierController = TextEditingController(text: currentCarrier);
    final trackingController = TextEditingController(text: currentTracking);
    String status = 'SHIPPED';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.local_shipping_rounded, color: AppTheme.secondaryCyan),
              SizedBox(width: 8),
              Text('Mark Order Shipped'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item: "${sale['itemTitle'] ?? 'Merchandise'}"',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Buyer: ${sale['buyerDisplayName'] ?? 'Customer'}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text('Fulfillment Status *', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: status,
                  dropdownColor: AppTheme.cardColor,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SHIPPED', child: Text('SHIPPED')),
                    DropdownMenuItem(value: 'DELIVERED', child: Text('DELIVERED')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => status = val);
                    }
                  },
                ),
                const SizedBox(height: 14),
                const Text('Shipping Carrier *', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('carrier_field'),
                  controller: carrierController,
                  decoration: InputDecoration(
                    hintText: 'e.g. USPS, FedEx, UPS, DHL',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Tracking Number *', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('tracking_number_field'),
                  controller: trackingController,
                  decoration: InputDecoration(
                    hintText: 'e.g. 9400 1000 0000 0000 0000 00',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
              onPressed: () {
                if (carrierController.text.trim().isEmpty || trackingController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter both carrier and tracking number.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save Fulfillment'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiClient.put<Map<String, dynamic>>(
        '/orders/items/$orderItemId/fulfillment',
        body: {
          'status': status,
          'carrier': carrierController.text.trim(),
          'trackingNumber': trackingController.text.trim(),
        },
        fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order marked as $status! Tracking number saved.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadSales(refresh: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update fulfillment: ${e.message}'),
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
        title: const Text('My Sales & Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Sales',
            onPressed: () => _loadSales(refresh: true),
          ),
        ],
      ),
      body: _isLoading && _sales.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : _errorMessage != null && _sales.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _loadSales(refresh: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _sales.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.store_mall_directory_outlined, size: 54, color: Colors.white24),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'No sales recorded yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'When buyers purchase your tracks, beats, or merchandise, the sales records and shipping addresses will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadSales(refresh: true),
                      color: AppTheme.primaryPurple,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sales.length + (_hasNext ? 1 : 0),
                        separatorBuilder: (ctx, i) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          if (index >= _sales.length) {
                            return Center(
                              child: TextButton(
                                onPressed: () {
                                  _page++;
                                  _loadSales();
                                },
                                child: const Text('Load More'),
                              ),
                            );
                          }

                          final s = _sales[index];
                          final itemTitle = s['itemTitle'] ?? 'Merchandise';
                          final buyer = s['buyerDisplayName'] ?? 'Buyer #${s['buyerId'] ?? '?'}';
                          final itemType = (s['itemType'] as String? ?? 'MERCHANDISE').toUpperCase();
                          final qty = s['quantity'] ?? 1;
                          final totalCents = (s['totalPriceCents'] as num?)?.toInt() ?? 0;
                          final totalDollars = totalCents / 100.0;
                          final status = (s['fulfillmentStatus'] as String? ?? 'PENDING').toUpperCase();
                          final carrier = s['carrier'] as String?;
                          final tracking = s['trackingNumber'] as String?;
                                                    final isMerch = itemType == 'MERCHANDISE';

                          final addr = s['shippingAddress'] as Map<String, dynamic>?;

                          final isShipped = status == 'SHIPPED' || status == 'DELIVERED';

                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isShipped
                                            ? AppTheme.successGreen.withValues(alpha: 0.2)
                                            : Colors.orange.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isShipped
                                              ? AppTheme.successGreen.withValues(alpha: 0.6)
                                              : Colors.orange.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isShipped ? AppTheme.successGreen : Colors.orangeAccent,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '\$${totalDollars.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.secondaryCyan,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  itemTitle,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Buyer: $buyer • Qty: $qty • Order #${s['orderId']}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                                if (isMerch && addr != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.location_on_outlined, size: 14, color: AppTheme.secondaryCyan),
                                            SizedBox(width: 4),
                                            Text(
                                              'Shipping Address:',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${addr['fullName'] ?? ''}\n${addr['line1'] ?? ''}${addr['line2'] != null ? ', ${addr['line2']}' : ''}\n${addr['city'] ?? ''}, ${addr['region'] ?? ''} ${addr['postalCode'] ?? ''}\n${addr['countryCode'] ?? ''}${addr['phone'] != null ? ' • Phone: ${addr['phone']}' : ''}',
                                          style: const TextStyle(fontSize: 12, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (tracking != null && tracking.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.markunread_mailbox_outlined, size: 14, color: AppTheme.successGreen),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Carrier: ${carrier ?? 'Standard'} • Tracking: $tracking',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.successGreen, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                                if (isMerch && status != 'DELIVERED') ...[
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      key: Key('mark_shipped_button_${s['orderItemId']}'),
                                      icon: const Icon(Icons.local_shipping_outlined, size: 16),
                                      label: Text(isShipped ? 'Update Tracking Info' : 'Mark Shipped'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isShipped ? AppTheme.surfaceColor : AppTheme.primaryPurple,
                                        foregroundColor: Colors.white,
                                        side: isShipped ? const BorderSide(color: AppTheme.secondaryCyan) : BorderSide.none,
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _showFulfillmentDialog(s),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
