import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/merchandise_card.dart';
import 'cart_screen.dart';
import 'create_merchandise_screen.dart';
import '../config/api_config.dart';
import 'home_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<MarketplaceProvider>().loadMarketplace(auth.currentUser?.id);
    });
  }

  void _navigateToCreateMerchandise() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    if (user == null || !user.canUploadMerchandise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access Denied: Only users with the "Artist" role are permitted to upload merchandise items.',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const CreateMerchandiseScreen()),
    ).then((_) {
      if (!mounted) return;
      final currentUser = context.read<AuthProvider>().currentUser;
      context.read<MarketplaceProvider>().loadMarketplace(currentUser?.id);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchandise Store'),
        actions: [
          IconButton(
            tooltip: 'Jump to Discover',
            icon: const Icon(Icons.explore_rounded, color: AppTheme.secondaryCyan),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (ctx) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
          Consumer<CartProvider>(
            builder: (context, cart, _) => Badge(
              isLabelVisible: cart.totalItems > 0,
              label: Text('${cart.totalItems}'),
              backgroundColor: AppTheme.accentPink,
              offset: const Offset(-4, 4),
              child: IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Shopping Cart',
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  if (auth.currentUser != null) {
                    context.read<CartProvider>().loadCart(auth.currentUser!.id);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const CartScreen()),
                  );
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_business_rounded),
            tooltip: 'Sell Merchandise',
            onPressed: _navigateToCreateMerchandise,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              final auth = context.read<AuthProvider>();
              context.read<MarketplaceProvider>().loadMarketplace(
                auth.currentUser?.id,
              );
            },
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.currentUser;
              if (user == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryPurple,
                        backgroundImage: (user.avatarUrlComputed != null && user.avatarUrlComputed!.isNotEmpty)
                            ? NetworkImage(
                                user.avatarUrlComputed!.startsWith('http')
                                    ? user.avatarUrlComputed!
                                    : ApiConfig.resolve(user.avatarUrlComputed!),
                              )
                            : null,
                        child: (user.avatarUrlComputed == null || user.avatarUrlComputed!.isEmpty)
                            ? Text(
                                user.displayName?.isNotEmpty == true
                                    ? user.displayName![0].toUpperCase()
                                    : user.email[0].toUpperCase(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 85),
                        child: Text(
                          user.effectiveName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<MarketplaceProvider>(
        builder: (context, mkt, child) {
          if (mkt.isLoading && mkt.merchandiseList.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryPurple),
            );
          }

          // Exclude sound kits so Marketplace exclusively houses merchandise
          final merchOnlyList = mkt.merchandiseList.where((m) {
            final grpName = (m.groupTypeName ?? '').toLowerCase();
            final catName = (m.categoryName ?? m.merchandiseTypeName ?? '').toLowerCase();
            final title = m.title.toLowerCase();

            final isAudioPack = grpName.contains('music') ||
                grpName.contains('audio') ||
                catName.contains('sound kit') ||
                catName.contains('sample') ||
                catName.contains('beat') ||
                catName.contains('loop') ||
                catName.contains('preset') ||
                title.contains('kit') ||
                title.contains('sample');

            return !isAudioPack;
          }).toList();

          final width = MediaQuery.of(context).size.width;
          final crossAxisCount = width > 1100 ? 4 : (width > 700 ? 3 : 2);

          return RefreshIndicator(
            color: AppTheme.primaryPurple,
            onRefresh: () async {
              final auth = context.read<AuthProvider>();
              await mkt.loadMarketplace(auth.currentUser?.id);
            },
            child: CustomScrollView(
              slivers: [
                // Info Banner
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.checkroom_rounded, color: AppTheme.secondaryCyan, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Official artist apparel, accessories, posters, and physical releases.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Items Grid
                if (merchOnlyList.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 52,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No physical merchandise listed yet',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _navigateToCreateMerchandise,
                            icon: const Icon(Icons.add),
                            label: const Text('List Merchandise Item'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = merchOnlyList[index];
                        return MerchandiseCard(item: item);
                      }, childCount: merchOnlyList.length),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }
}
