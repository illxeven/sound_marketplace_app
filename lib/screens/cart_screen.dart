import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/cart.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cartProv = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shopping_cart_outlined, color: AppTheme.secondaryCyan),
            const SizedBox(width: 8),
            const Text('My Shopping Cart'),
          ],
        ),
        actions: [
          if (cartProv.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
              tooltip: 'Clear Cart',
              onPressed: () {
                if (auth.currentUser != null) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surfaceColor,
                      title: const Text('Clear Shopping Cart?'),
                      content: const Text('All items will be removed from your current cart.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                          onPressed: () {
                            Navigator.pop(ctx);
                            cartProv.clearCart(auth.currentUser!.id);
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              if (auth.currentUser != null) {
                cartProv.loadCart(auth.currentUser!.id);
              }
            },
          ),
        ],
      ),
      body: auth.currentUser == null
          ? const Center(
              child: Text(
                'Please sign in to view your shopping cart.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : cartProv.isLoading && cartProv.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                )
              : cartProv.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.remove_shopping_cart_outlined,
                                size: 54,
                                color: Colors.white24,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Your cart is empty',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Explore tracks, beats, loops, sound kits, and artist merchandise to add items to your cart!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Continue Shopping'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: cartProv.items.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final item = cartProv.items[i];
                              return _CartItemTile(
                                item: item,
                                userId: auth.currentUser!.id,
                              );
                            },
                          ),
                        ),
                        // Cart Checkout Bottom Panel
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 15,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtotal (${cartProv.totalItems} items):',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '\$${cartProv.subtotal.toStringAsFixed(2)} USD',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.secondaryCyan,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.payment_rounded),
                                    label: const Text('Proceed to Checkout'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final user = auth.currentUser;
                                      if (user == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please log in to complete checkout')),
                                        );
                                        return;
                                      }

                                       final chargeId = await CheckoutScreen.startCheckout(
                                         context: context,
                                         amount: cartProv.subtotal,
                                         itemTitle: 'Sound Marketplace Cart (${cartProv.totalItems} items)',
                                         itemType: 'cart',
                                         user: user,
                                         metadata: {
                                           'cartItemsCount': cartProv.totalItems.toString(),
                                           'buyerEmail': user.email,
                                         },
                                       );

                                      if (chargeId != null && context.mounted) {
                                        final totalPaid = cartProv.subtotal;
                                        final itemsCount = cartProv.totalItems;
                                        await cartProv.clearCart(user.id);
                                        if (!context.mounted) return;

                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: AppTheme.surfaceColor,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            title: const Row(
                                              children: [
                                                Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 28),
                                                SizedBox(width: 10),
                                                Text('Order Confirmed!'),
                                              ],
                                            ),
                                            content: Text(
                                              'Your payment of \$${totalPaid.toStringAsFixed(2)} for $itemsCount items was processed successfully via Stripe.\n\nStripe Reference: $chargeId',
                                            ),
                                            actions: [
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text('Continue Shopping'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final int userId;

  const _CartItemTile({
    required this.item,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final cartProv = context.read<CartProvider>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Item Image / Artwork thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              height: 58,
              child: _buildThumbnail(),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isMerchandise
                            ? AppTheme.primaryPurple.withValues(alpha: 0.3)
                            : AppTheme.secondaryCyan.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.isMerchandise ? 'MERCH' : 'TRACK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.isMerchandise ? AppTheme.accentPink : AppTheme.secondaryCyan,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.displaySubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${item.unitPrice.toStringAsFixed(2)} each',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Quantity controls & Remove
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                tooltip: 'Remove',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => cartProv.removeItem(userId: userId, cartItemId: item.id),
              ),
              const SizedBox(height: 8),
              if (item.isMerchandise)
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          if (item.quantity > 1) {
                            cartProv.updateQuantity(
                              userId: userId,
                              cartItemId: item.id,
                              quantity: item.quantity - 1,
                            );
                          } else {
                            cartProv.removeItem(userId: userId, cartItemId: item.id);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Icon(Icons.remove, size: 14, color: Colors.white70),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          cartProv.updateQuantity(
                            userId: userId,
                            cartItemId: item.id,
                            quantity: item.quantity + 1,
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Icon(Icons.add, size: 14, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  '\$${item.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.secondaryCyan,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    if (item.isMerchandise) {
      if (item.merchandiseImageBlob != null && item.merchandiseImageBlob!.isNotEmpty) {
        return Image.memory(item.merchandiseImageBlob!, fit: BoxFit.cover);
      }
      return Container(
        color: AppTheme.surfaceColor,
        child: const Icon(Icons.storefront_rounded, color: AppTheme.secondaryCyan, size: 28),
      );
    } else {
      if (item.trackCoverBlob != null && item.trackCoverBlob!.isNotEmpty) {
        return Image.memory(item.trackCoverBlob!, fit: BoxFit.cover);
      }
      if (item.trackCoverUrl != null && item.trackCoverUrl!.isNotEmpty) {
        final fullUrl = item.trackCoverUrl!.startsWith('http')
            ? item.trackCoverUrl!
            : ApiConfig.resolve(item.trackCoverUrl!);
        return Image.network(
          fullUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAudioIcon(),
        );
      }
      return _buildFallbackAudioIcon();
    }
  }

  Widget _buildFallbackAudioIcon() {
    return Container(
      color: AppTheme.surfaceColor,
      child: const Icon(Icons.music_note_rounded, color: AppTheme.secondaryCyan, size: 28),
    );
  }
}
