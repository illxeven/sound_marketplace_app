import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/merchandise.dart';
import '../providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/merchandise_card.dart';
import 'create_merchandise_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class ArtistStorefrontScreen extends StatefulWidget {
  final int artistId;
  final String artistName;

  const ArtistStorefrontScreen({
    super.key,
    required this.artistId,
    required this.artistName,
  });

  @override
  State<ArtistStorefrontScreen> createState() => _ArtistStorefrontScreenState();
}

class _ArtistStorefrontScreenState extends State<ArtistStorefrontScreen> {
  bool _isLoading = true;
  String? _error;
  List<Merchandise> _items = [];

  @override
  void initState() {
    super.initState();
    _loadArtistItems();
  }

  Future<void> _loadArtistItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final mkt = context.read<MarketplaceProvider>();
      final items = await mkt.getMerchandiseBySeller(widget.artistId);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1100 ? 4 : (width > 700 ? 3 : 2);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.artistName}\'s Storefront'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded, color: AppTheme.secondaryCyan),
            tooltip: 'View Artist Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => ProfileScreen(
                    artistId: widget.artistId,
                    artistName: widget.artistName,
                  ),
                ),
              );
            },
          ),
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
          if (auth.currentUser?.id == widget.artistId)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppTheme.secondaryCyan),
              tooltip: 'List New Merchandise',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (ctx) => const CreateMerchandiseScreen()),
                );
                if (created == true) {
                  _loadArtistItems();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Storefront',
            onPressed: _loadArtistItems,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryPurple),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                      const SizedBox(height: 12),
                      Text('Error: $_error', style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadArtistItems,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                size: 54,
                                color: Colors.white24,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${widget.artistName} hasn\'t listed any merchandise yet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Check back later for exclusive drops, apparel, and physical releases!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primaryPurple,
                      onRefresh: _loadArtistItems,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2E1A47), Color(0xFF1B1633)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppTheme.primaryPurple,
                                    child: Text(
                                      widget.artistName.isNotEmpty
                                          ? widget.artistName[0].toUpperCase()
                                          : 'A',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.artistName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_items.length} item${_items.length == 1 ? '' : 's'} available in official merch catalog',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                                  final item = _items[index];
                                  return MerchandiseCard(item: item);
                                },
                                childCount: _items.length,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ),
                    ),
    );
  }
}
