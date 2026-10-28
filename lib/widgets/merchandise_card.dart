import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/merchandise.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/marketplace_provider.dart';
import '../screens/artist_storefront_screen.dart';
import '../screens/merchandise_detail_screen.dart';

class MerchandiseCard extends StatelessWidget {
  final Merchandise item;

  const MerchandiseCard({super.key, required this.item});

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => MerchandiseDetailScreen(item: item),
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create an account to purchase')),
      );
      return;
    }

    if (item.isOutOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is currently out of stock!'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shopping_bag_outlined, color: AppTheme.secondaryCyan),
            SizedBox(width: 10),
            Text('Confirm Order'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Seller: ${item.sellerDisplay}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount:', style: TextStyle(color: AppTheme.textSecondary)),
                  Text(
                    '\$${item.price.toStringAsFixed(2)} USD',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryCyan,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '${item.stockQuantity} units remaining',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppTheme.successGreen),
                const SizedBox(width: 6),
                Text(
                  'Secured by Stripe Sandbox',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final mkt = context.read<MarketplaceProvider>();
              final payment = await mkt.purchaseItem(
                buyerId: auth.currentUser!.id,
                item: item,
              );

              if (context.mounted) {
                if (payment != null) {
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: AppTheme.surfaceColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 28),
                          SizedBox(width: 10),
                          Text('Purchase Complete!'),
                        ],
                      ),
                      content: Text(
                        'You successfully purchased "${item.title}".\n\nStripe Charge ID: ${payment.stripeChargeId}\nStatus: ${payment.status}',
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Great!'),
                        ),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment failed: ${mkt.errorMessage}')),
                  );
                }
              }
            },
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductArtwork() {
    if (item.imageBlob != null && item.imageBlob!.isNotEmpty) {
      return Image.memory(
        item.imageBlob!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    if (item.coverImageUrl != null && item.coverImageUrl!.isNotEmpty) {
      final url = item.coverImageUrl!.startsWith('http')
          ? item.coverImageUrl!
          : ApiConfig.resolve(item.coverImageUrl!);
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withValues(alpha: 0.8),
            AppTheme.accentPink.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          size: 52,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _navigateToDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Larger Square Product Image Card (Matching TrackCard's AspectRatio 1.0)
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildProductArtwork(),

                    // Category Badge (top right)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          item.displayCategory,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Inventory Stock Status Badge (top left)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.isOutOfStock
                              ? AppTheme.errorRed.withValues(alpha: 0.95)
                              : (item.stockQuantity < 5
                                  ? Colors.orange.withValues(alpha: 0.9)
                                  : Colors.black87),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.isOutOfStock
                                ? AppTheme.errorRed
                                : (item.stockQuantity < 5 ? Colors.orange : Colors.white12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isOutOfStock ? Icons.cancel_rounded : Icons.inventory_2_outlined,
                              size: 11,
                              color: item.isOutOfStock ? Colors.white : AppTheme.secondaryCyan,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.isOutOfStock
                                  ? 'Out of Stock'
                                  : (item.stockQuantity < 5 ? '${item.stockQuantity} left' : '${item.stockQuantity} in stock'),
                              style: TextStyle(
                                fontSize: 10,
                                color: item.isOutOfStock ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Pending Review Badge (bottom left)
                    if (item.isPending)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade900,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_empty_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Pending review',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Quick Detail Tap overlay hint (bottom gradient)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Info Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 3),

                  // Artist/Seller Link
                  if (item.sellerId != null)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => ArtistStorefrontScreen(
                              artistId: item.sellerId!,
                              artistName: item.sellerDisplay,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          'By ${item.sellerDisplay}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.secondaryCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      'By ${item.sellerDisplay}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),

                  const SizedBox(height: 6),

                  // Star Rating Summary Line
                  Row(
                    children: [
                      Icon(
                        item.averageRating != null ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: item.averageRating != null ? Colors.amber : Colors.white24,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.averageRating != null
                            ? item.averageRating!.toStringAsFixed(1)
                            : 'New',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: item.averageRating != null ? Colors.amber : Colors.white54,
                        ),
                      ),
                      if (item.reviewCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${item.reviewCount})',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Price and Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryCyan,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                            tooltip: item.isOutOfStock ? 'Out of stock' : 'Add to Cart',
                            color: item.isOutOfStock ? Colors.white24 : AppTheme.secondaryCyan,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: item.isOutOfStock
                                ? null
                                : () async {
                                    final auth = context.read<AuthProvider>();
                                    if (!auth.isAuthenticated) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please log in to add items to your cart')),
                                      );
                                      return;
                                    }
                                    final ok = await context.read<CartProvider>().addToCart(
                                          userId: auth.currentUser!.id,
                                          merchandiseId: item.id,
                                          quantity: 1,
                                        );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok ? 'Added "${item.title}" to cart!' : 'Failed to add to cart'),
                                          backgroundColor: ok ? AppTheme.successGreen : AppTheme.errorRed,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: item.isOutOfStock ? Colors.grey.shade800 : AppTheme.primaryPurple,
                              foregroundColor: item.isOutOfStock ? Colors.white38 : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: item.isOutOfStock ? () => _navigateToDetail(context) : () => _showCheckoutDialog(context),
                            child: Text(item.isOutOfStock ? 'Sold Out' : 'Get'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
