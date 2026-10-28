import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/merchandise.dart';
import '../models/merchandise_review.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/share_dialog.dart';
import 'checkout_screen.dart';
import 'artist_storefront_screen.dart';
import 'home_screen.dart';

class MerchandiseDetailScreen extends StatefulWidget {
  final Merchandise item;

  const MerchandiseDetailScreen({super.key, required this.item});

  @override
  State<MerchandiseDetailScreen> createState() => _MerchandiseDetailScreenState();
}

class _MerchandiseDetailScreenState extends State<MerchandiseDetailScreen> {
  late Merchandise _item;
  bool _isLoadingReviews = false;
  bool _isSubmittingReview = false;
  int _userSelectedRating = 5;
  int _selectedImageIndex = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _showReviewForm = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviews();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoadingReviews = true);
    final mkt = context.read<MarketplaceProvider>();
    await mkt.loadReviews(_item.id);
    if (mounted) {
      // Refresh current item from provider if available
      final refreshed = mkt.getMerchandise(_item.id);
      if (refreshed != null) {
        setState(() {
          _item = refreshed;
          _isLoadingReviews = false;
        });
      } else {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  void _showCheckoutDialog() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in or create an account to purchase')),
      );
      return;
    }

    if (_item.isOutOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorry, this item is currently out of stock!'),
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
              _item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Seller: ${_item.sellerDisplay}',
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
                    '\$${_item.price.toStringAsFixed(2)} USD',
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
                  '${_item.stockQuantity} units left in stock',
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
              final chargeId = await CheckoutScreen.startCheckout(
                context: context,
                amount: _item.price,
                itemTitle: _item.title,
                itemType: 'merchandise',
                itemId: _item.id,
                user: auth.currentUser!,
                metadata: {
                  'merchandiseId': _item.id.toString(),
                  'sellerId': _item.sellerId.toString(),
                },
              );

              if (chargeId != null && mounted) {
                final mkt = context.read<MarketplaceProvider>();
                final payment = await mkt.purchaseItem(
                  buyerId: auth.currentUser!.id,
                  item: _item,
                  stripeChargeId: chargeId,
                );

                if (mounted) {
                  if (payment != null) {
                    setState(() {
                      _item = _item.copyWith(
                        stockQuantity: (_item.stockQuantity - 1).clamp(0, 999999),
                      );
                    });

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
                          'You successfully purchased "${_item.title}".\n\nRemaining Stock: ${_item.stockQuantity}\nStripe Payment ID: ${payment.stripeChargeId}\nStatus: ${payment.status}',
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
                      SnackBar(
                        content: Text('Payment record failed: ${mkt.errorMessage ?? "Unknown error"}'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review')),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);
    final mkt = context.read<MarketplaceProvider>();
    final result = await mkt.submitReview(
      merchandiseId: _item.id,
      userId: auth.currentUser!.id,
      rating: _userSelectedRating,
      comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isSubmittingReview = false);
      if (result != null) {
        _commentController.clear();
        setState(() {
          _showReviewForm = false;
          final refreshed = mkt.getMerchandise(_item.id);
          if (refreshed != null) {
            _item = refreshed;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully! Thank you for your feedback.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: ${mkt.errorMessage}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showEditMerchandiseDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final mkt = context.read<MarketplaceProvider>();
    final titleCtrl = TextEditingController(text: _item.title);
    final priceCtrl = TextEditingController(text: _item.price.toStringAsFixed(2));
    final stockCtrl = TextEditingController(text: _item.stockQuantity.toString());
    final descCtrl = TextEditingController(text: _item.description ?? '');
    final optCtrl = TextEditingController(text: _item.options ?? '');
    Uint8List? newImageBytes;
    String? newImageName;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppTheme.secondaryCyan, size: 26),
              SizedBox(width: 8),
              Text('Edit Merchandise'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Price (USD)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '\$ ',
                                filled: true,
                                fillColor: AppTheme.cardColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Stock Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppTheme.cardColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe this merchandise item...',
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Options / Specifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: optCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g., S, M, L, XL or WAV, MP3',
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Image replacement picker
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondaryCyan,
                      side: const BorderSide(color: AppTheme.secondaryCyan),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.image_outlined, size: 20),
                    label: Text(newImageName != null ? 'Selected: $newImageName' : 'Change Product Image'),
                    onPressed: () async {
                      try {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setDlgState(() {
                            newImageBytes = result.files.first.bytes;
                            newImageName = result.files.first.name;
                          });
                        }
                      } catch (e) {
                        debugPrint('Error picking file: $e');
                      }
                    },
                  ),
                  if (newImageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(newImageBytes!, height: 80, fit: BoxFit.cover),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleCtrl.text.trim();
                final newPrice = double.tryParse(priceCtrl.text.trim()) ?? _item.price;
                final newStock = int.tryParse(stockCtrl.text.trim()) ?? _item.stockQuantity;
                final newDesc = descCtrl.text.trim();
                final newOptions = optCtrl.text.trim();

                Navigator.pop(dlgCtx);

                final updated = await mkt.updateMerchandise(
                  id: _item.id,
                  title: newTitle.isNotEmpty ? newTitle : null,
                  price: newPrice,
                  stockQuantity: newStock,
                  description: newDesc,
                  options: newOptions,
                  imageBlob: newImageBytes,
                );

                if (mounted) {
                  if (updated != null) {
                    setState(() {
                      _item = updated;
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Merchandise updated successfully!'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to update: ${mkt.errorMessage}'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 18}) {
    List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      if (rating >= i) {
        stars.add(Icon(Icons.star_rounded, color: Colors.amber, size: size));
      } else if (rating >= i - 0.5) {
        stars.add(Icon(Icons.star_half_rounded, color: Colors.amber, size: size));
      } else {
        stars.add(Icon(Icons.star_outline_rounded, color: Colors.white24, size: size));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mkt = context.watch<MarketplaceProvider>();
    final List<MerchandiseReview> reviews = mkt.getReviewsFor(_item.id);
    final isSeller = auth.isAuthenticated && auth.currentUser?.id == _item.sellerId;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(_item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white70),
            tooltip: 'Share Merchandise',
            onPressed: () {
              ShareDialog.show(
                context,
                title: _item.title,
                subtitle: 'Available on Sound Marketplace for \$${_item.price.toStringAsFixed(2)}',
                shareUrl: '${ApiConfig.baseUrl}/merchandise/${_item.id}',
                itemType: 'Merchandise',
              );
            },
          ),
          if (isSeller)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppTheme.secondaryCyan),
              tooltip: 'Edit Merchandise',
              onPressed: _showEditMerchandiseDialog,
            ),
          IconButton(
            tooltip: 'Discover',
            icon: const Icon(Icons.explore_rounded, color: AppTheme.secondaryCyan),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (ctx) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Large Hero Product Image Card & Gallery
                Builder(
                  builder: (context) {
                    final allImgs = _item.allImages;
                    final displayImg = allImgs.isNotEmpty && _selectedImageIndex < allImgs.length
                        ? allImgs[_selectedImageIndex]
                        : (allImgs.isNotEmpty ? allImgs.first : null);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_item.isPending)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Pending review — this listing is only visible to you until approved by an admin.',
                                    style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (displayImg != null && displayImg.isNotEmpty)
                                    Image.memory(
                                      displayImg,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Container(
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
                                      child: const Center(
                                        child: Icon(
                                          Icons.inventory_2_rounded,
                                          size: 72,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  // Category Tag (top left)
                                  Positioned(
                                    top: 14,
                                    left: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Text(
                                        _item.displayCategory,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Stock Badge (top right)
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _item.isOutOfStock
                                            ? AppTheme.errorRed.withValues(alpha: 0.95)
                                            : (_item.stockQuantity < 5
                                                ? Colors.orange.withValues(alpha: 0.95)
                                                : AppTheme.successGreen.withValues(alpha: 0.95)),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _item.isOutOfStock ? Icons.cancel_rounded : Icons.check_circle_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _item.isOutOfStock
                                                ? 'OUT OF STOCK'
                                                : (_item.stockQuantity < 5
                                                    ? 'Only ${_item.stockQuantity} Left'
                                                    : '${_item.stockQuantity} in Stock'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (allImgs.length > 1) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 64,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: allImgs.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (ctx, i) {
                                final isSelected = i == _selectedImageIndex;
                                return InkWell(
                                  onTap: () => setState(() => _selectedImageIndex = i),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.secondaryCyan : Colors.white24,
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Image.memory(
                                        allImgs[i],
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 2. Title, Artist & Rating Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _item.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_item.sellerId != null)
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => ArtistStorefrontScreen(
                                      artistId: _item.sellerId!,
                                      artistName: _item.sellerDisplay,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_pin_rounded, size: 16, color: AppTheme.secondaryCyan),
                                  const SizedBox(width: 6),
                                  Text(
                                    'By ${_item.sellerDisplay}',
                                    style: const TextStyle(
                                      color: AppTheme.secondaryCyan,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              'By ${_item.sellerDisplay}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Price tag
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${_item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryCyan,
                          ),
                        ),
                        const Text(
                          'USD',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Star Rating Overview Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      _buildStars(_item.averageRating ?? 0.0, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _item.averageRating != null
                            ? '${_item.averageRating!.toStringAsFixed(1)} / 5.0'
                            : 'No ratings yet',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_item.reviewCount} ${_item.reviewCount == 1 ? 'review' : 'reviews'})',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      if (isSeller)
                        TextButton.icon(
                          onPressed: _showEditMerchandiseDialog,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Item'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.secondaryCyan,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Out of Stock Alert Banner
                if (_item.isOutOfStock)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Item Out of Stock',
                                style: TextStyle(
                                  color: AppTheme.errorRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'This merchandise is currently sold out and cannot be purchased at this time.',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // 5. Purchase & Add to Cart Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: _item.isOutOfStock ? Colors.white30 : AppTheme.secondaryCyan,
                          side: BorderSide(
                            color: _item.isOutOfStock ? Colors.white24 : AppTheme.secondaryCyan,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: Text(_item.isOutOfStock ? 'Sold Out' : 'Add to Cart'),
                        onPressed: _item.isOutOfStock
                            ? null
                            : () async {
                                if (!auth.isAuthenticated) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please log in to add items to your cart')),
                                  );
                                  return;
                                }
                                final ok = await context.read<CartProvider>().addToCart(
                                      userId: auth.currentUser!.id,
                                      merchandiseId: _item.id,
                                      quantity: 1,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Added "${_item.title}" to cart!' : 'Failed to add to cart'),
                                      backgroundColor: ok ? AppTheme.successGreen : AppTheme.errorRed,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _item.isOutOfStock ? Colors.grey.shade800 : AppTheme.primaryPurple,
                          foregroundColor: _item.isOutOfStock ? Colors.white38 : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.flash_on_rounded),
                        label: Text(
                          _item.isOutOfStock ? 'Out of Stock' : 'Buy Now (\$${_item.price.toStringAsFixed(2)})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _item.isOutOfStock ? null : _showCheckoutDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 6. Description & Details
                const Text(
                  'Description & Specifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _item.description?.isNotEmpty == true
                            ? _item.description!
                            : 'No detailed description provided for this merchandise.',
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white),
                      ),
                      if (_item.options != null && _item.options!.isNotEmpty) ...[
                        const Divider(height: 28, color: Colors.white10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available Options: ',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            Expanded(
                              child: Text(
                                _item.options!,
                                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Current Stock Quantity: ${_item.stockQuantity} units',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 7. Customer Reviews Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Reviews',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${reviews.length} ${_item.reviewCount == 1 ? 'review' : 'reviews'} - Average: ${_item.averageRating != null ? _item.averageRating!.toStringAsFixed(1) : "0.0"} / 5.0',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showReviewForm ? AppTheme.cardColor : AppTheme.secondaryCyan.withValues(alpha: 0.15),
                        foregroundColor: AppTheme.secondaryCyan,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(_showReviewForm ? Icons.close : Icons.rate_review_outlined, size: 18),
                      label: Text(_showReviewForm ? 'Cancel' : 'Write a Review'),
                      onPressed: () {
                        if (!auth.isAuthenticated) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please log in to write a review')),
                          );
                          return;
                        }
                        setState(() => _showReviewForm = !_showReviewForm);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Write Review Form Expandable Box
                if (_showReviewForm)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rate this merchandise:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(5, (index) {
                            final starVal = index + 1;
                            return IconButton(
                              icon: Icon(
                                _userSelectedRating >= starVal ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: Colors.amber,
                                size: 32,
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() => _userSelectedRating = starVal);
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _commentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Share your thoughts, quality review, or impressions...',
                            filled: true,
                            fillColor: AppTheme.cardColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isSubmittingReview
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isSubmittingReview ? null : _submitReview,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Review List
                if (_isLoadingReviews)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: AppTheme.secondaryCyan),
                    ),
                  )
                else if (reviews.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.star_outline_rounded, size: 40, color: Colors.white24),
                        const SizedBox(height: 10),
                        const Text(
                          'No reviews yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Be the first verified customer to share a review!',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final rev = reviews[idx];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.4),
                                      child: Text(
                                        rev.userDisplayName.isNotEmpty ? rev.userDisplayName[0].toUpperCase() : 'U',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      rev.userDisplayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                _buildStars(rev.rating.toDouble(), size: 16),
                              ],
                            ),
                            if (rev.comment != null && rev.comment!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                rev.comment!,
                                style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.white),
                              ),
                            ],
                            const SizedBox(height: 6),
                            if (rev.createdAt != null)
                              Text(
                                '${rev.createdAt!.year}-${rev.createdAt!.month.toString().padLeft(2, '0')}-${rev.createdAt!.day.toString().padLeft(2, '0')}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
