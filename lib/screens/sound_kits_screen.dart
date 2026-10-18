import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/merchandise_card.dart';
import 'cart_screen.dart';
import 'create_merchandise_screen.dart';
import '../config/api_config.dart';
import 'home_screen.dart';

class SoundKitsScreen extends StatefulWidget {
  const SoundKitsScreen({super.key});

  @override
  State<SoundKitsScreen> createState() => _SoundKitsScreenState();
}

class _SoundKitsScreenState extends State<SoundKitsScreen> {
  String _selectedSubCategory = 'All';

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
            'Access Denied: Only users with the "Artist" role are permitted to upload sound kits and samples.',
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
        title: const Text('Sound Kits & Samples'),
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
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Upload Sound Kit',
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
                        backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                            ? NetworkImage(
                                user.avatarUrl!.startsWith('http')
                                    ? user.avatarUrl!
                                    : ApiConfig.resolve(user.avatarUrl!),
                              )
                            : null,
                        child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
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

          // Filter exclusively for Sound Kits, Sample Packs, Loops, and Audio Tools
          final allSoundKits = mkt.merchandiseList.where((m) {
            final grpName = (m.groupTypeName ?? '').toLowerCase();
            final catName = (m.categoryName ?? m.merchandiseTypeName ?? '').toLowerCase();
            final title = m.title.toLowerCase();

            return grpName.contains('music') ||
                grpName.contains('audio') ||
                catName.contains('sound kit') ||
                catName.contains('sample') ||
                catName.contains('beat') ||
                catName.contains('loop') ||
                catName.contains('preset') ||
                catName.contains('vocal') ||
                title.contains('kit') ||
                title.contains('sample') ||
                title.contains('loop');
          }).toList();

          final filteredKits = _selectedSubCategory == 'All'
              ? allSoundKits
              : allSoundKits.where((m) {
                  final cat = (m.categoryName ?? '').toLowerCase();
                  final title = m.title.toLowerCase();
                  final sub = _selectedSubCategory.toLowerCase();
                  return cat.contains(sub) || title.contains(sub);
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
                // Sound Kit Filter Chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ChoiceChip(
                            label: const Text('All Sound Kits'),
                            selected: _selectedSubCategory == 'All',
                            onSelected: (_) => setState(() => _selectedSubCategory = 'All'),
                            selectedColor: AppTheme.secondaryCyan.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Drum Kits'),
                            selected: _selectedSubCategory == 'Drum',
                            onSelected: (_) => setState(() => _selectedSubCategory = 'Drum'),
                            selectedColor: AppTheme.secondaryCyan.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Loops & Melodies'),
                            selected: _selectedSubCategory == 'Loop',
                            onSelected: (_) => setState(() => _selectedSubCategory = 'Loop'),
                            selectedColor: AppTheme.secondaryCyan.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Presets & FX'),
                            selected: _selectedSubCategory == 'Preset',
                            onSelected: (_) => setState(() => _selectedSubCategory = 'Preset'),
                            selectedColor: AppTheme.secondaryCyan.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Sound Kits Grid
                if (filteredKits.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.album_rounded,
                              size: 48,
                              color: AppTheme.secondaryCyan,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No Sound Kits found',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Be the first producer to publish samples, loops, or drum kits!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _navigateToCreateMerchandise,
                            icon: const Icon(Icons.add),
                            label: const Text('Upload Sound Kit'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = filteredKits[index];
                          return MerchandiseCard(item: item);
                        },
                        childCount: filteredKits.length,
                      ),
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
