import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/api_client.dart';
import '../services/json_utils.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.get<Map<String, dynamic>>(
        '/orders',
        fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      final rawItems = extractItems(res.data);
      final items = rawItems.map((i) => (i as Map).cast<String, dynamic>()).toList();

      setState(() {
        _orders = items;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Order History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Orders',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : _errorMessage != null
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
                          onPressed: _loadOrders,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _orders.isEmpty
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
                              child: const Icon(Icons.shopping_bag_outlined, size: 54, color: Colors.white24),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'No orders placed yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your completed purchases for beats, tracks, and merchandise will appear here with live tracking updates.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      color: AppTheme.primaryPurple,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final o = _orders[index];
                          final orderId = o['id'];
                                                    final totalCents = (o['totalCents'] as num?)?.toInt() ?? 0;
                          final totalDollars = totalCents / 100.0;
                          final createdAtStr = o['createdAt'] as String?;
                          DateTime? createdAt;
                          if (createdAtStr != null) {
                            createdAt = DateTime.tryParse(createdAtStr);
                          }
                          final dateText = createdAt != null ? DateFormat.yMMMd().format(createdAt) : 'Recent';

                          final itemsRaw = o['items'];
                          List<Map<String, dynamic>> items = [];
                          if (itemsRaw is List) {
                            items = itemsRaw.map((i) => (i as Map).cast<String, dynamic>()).toList();
                          }

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
                                    Row(
                                      children: [
                                        Text(
                                          'Order #$orderId',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('• $dateText', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                    Text(
                                      '\$${totalDollars.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.secondaryCyan,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 1, color: Colors.white10),
                                const SizedBox(height: 10),
                                ...items.map((it) {
                                  final itemType = (it['itemType'] as String? ?? 'MERCHANDISE').toUpperCase();
                                  final isMerch = itemType == 'MERCHANDISE';
                                  final title = it['title'] ?? (isMerch ? 'Merchandise' : 'Track');
                                  final qty = it['quantity'] ?? 1;
                                  final itemUnitCents = (it['unitPriceCents'] as num?)?.toInt() ?? 0;
                                  final itemUnitDollars = itemUnitCents / 100.0;
                                  final fulfillmentStatus = (it['fulfillmentStatus'] as String? ?? 'PENDING').toUpperCase();
                                  final carrier = it['carrier'] as String?;
                                  final tracking = it['trackingNumber'] as String?;
                                  final shippedAtRaw = it['shippedAt'] as String?;
                                  DateTime? shippedAt;
                                  if (shippedAtRaw != null) {
                                    shippedAt = DateTime.tryParse(shippedAtRaw);
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '$title (x$qty)',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '\$${itemUnitDollars.toStringAsFixed(2)}',
                                              style: const TextStyle(fontSize: 13, color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                        // Requirement B3: Fulfillment status & tracking info for merchandise
                                        if (isMerch) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: fulfillmentStatus == 'SHIPPED' || fulfillmentStatus == 'DELIVERED'
                                                      ? AppTheme.successGreen.withValues(alpha: 0.2)
                                                      : Colors.orange.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: fulfillmentStatus == 'SHIPPED' || fulfillmentStatus == 'DELIVERED'
                                                        ? AppTheme.successGreen.withValues(alpha: 0.5)
                                                        : Colors.orange.withValues(alpha: 0.5),
                                                  ),
                                                ),
                                                child: Text(
                                                  fulfillmentStatus,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: fulfillmentStatus == 'SHIPPED' || fulfillmentStatus == 'DELIVERED'
                                                        ? AppTheme.successGreen
                                                        : Colors.orangeAccent,
                                                  ),
                                                ),
                                              ),
                                              if (tracking != null && tracking.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${carrier ?? 'Carrier'}: $tracking',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppTheme.secondaryCyan,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (shippedAt != null) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              'Shipped on ${DateFormat.yMMMd().format(shippedAt)}',
                                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
