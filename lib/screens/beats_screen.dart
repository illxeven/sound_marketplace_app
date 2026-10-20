import '../widgets/universal_app_header.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/comment_bottom_sheet.dart';
import '../widgets/media_widgets.dart';
import 'cart_screen.dart';

/// Beats for sale: preview, like, queue, comment and add to cart.
/// Bloomee-inspired sleek cover cards, play indicators, and clean responsive grid.
class BeatsScreen extends StatefulWidget {
  const BeatsScreen({super.key});

  @override
  State<BeatsScreen> createState() => _BeatsScreenState();
}

class _BeatsScreenState extends State<BeatsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _genre = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalog = context.read<CatalogProvider>();
      if (catalog.beats.isEmpty) catalog.loadBeats();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() => context.read<CatalogProvider>().loadBeats(genre: _genre, search: _search.text);

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reload();
    });
  }

  Future<void> _addToCart(Track beat) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add beats to your cart')),
      );
      return;
    }
    final cart = context.read<CartProvider>();
    final ok = await cart.addToCart(userId: user.id, trackId: beat.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '"${beat.title}" added to cart' : (cart.errorMessage ?? "Couldn't add to cart.")),
      backgroundColor: ok ? AppTheme.successGreen : AppTheme.errorRed,
      action: ok
          ? SnackBarAction(
              label: 'View cart',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            )
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final beats = catalog.beats;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200 ? 5 : (width >= 900 ? 4 : (width >= 600 ? 3 : 2));
    final genres = <String>{'All', ...beats.map((b) => b.genre).whereType<String>()}.toList();

    return Scaffold(
      appBar: UniversalAppHeader(
        title: 'Beats',
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) => Badge(
              isLabelVisible: cart.totalItems > 0,
              label: Text('${cart.totalItems}'),
              offset: const Offset(-4, 4),
              child: IconButton(
                tooltip: 'Cart',
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.secondaryCyan,
        onRefresh: () async => _reload(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search beats by title or producer',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: genres.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final g = genres[i];
                    final sel = g == _genre;
                    return ChoiceChip(
                      label: Text(g),
                      selected: sel,
                      showCheckmark: false,
                      selectedColor: AppTheme.secondaryCyan,
                      backgroundColor: AppTheme.surfaceColor,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        color: sel ? Colors.black : AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      onSelected: (_) {
                        setState(() => _genre = g);
                        _reload();
                      },
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (catalog.isLoadingBeats && beats.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: AppTheme.secondaryCyan)),
              )
            else if (beats.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('No beats match your filters yet.', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 14,
                    childAspectRatio: width < 600 ? 0.64 : 0.68,
                  ),
                  itemCount: beats.length,
                  itemBuilder: (_, i) {
                    final beat = beats[i];
                    return BloomeeBeatCard(
                      beat: beat,
                      onPlay: () => context.read<AudioPlayerProvider>().playTrack(beat, playlistQueue: beats),
                      onAddToCart: () => _addToCart(beat),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

/// BloomeeTunes-inspired bold cover card with corner tag, play indicator badge, and clean action row.
class BloomeeBeatCard extends StatelessWidget {
  const BloomeeBeatCard({
    super.key,
    required this.beat,
    required this.onPlay,
    required this.onAddToCart,
  });

  final Track beat;
  final VoidCallback onPlay;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final isCurrent = context.select<AudioPlayerProvider, bool>((p) => p.currentTrack?.id == beat.id);
    final isPlaying = context.select<AudioPlayerProvider, bool>((p) => p.currentTrack?.id == beat.id && p.isPlaying);
    final priceLabel = beat.isFree ? 'Free' : NumberFormat.simpleCurrency().format(beat.price);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPlay,
      onLongPress: () => showTrackActions(context, beat),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? AppTheme.secondaryCyan.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.06),
            width: isCurrent ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bold cover artwork with Bloomee corner tag and circular play badge
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(url: beat.coverImageFullUrl, radius: 14),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bloomee tag pill (Top Left Price)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: beat.isFree ? AppTheme.successGreen : AppTheme.primaryPurple,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Text(
                          priceLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Optional Genre/Tag (Top Right)
                    if (beat.genre != null && beat.genre!.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            beat.genre!,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
                          ),
                        ),
                      ),
                    // Floating circular play indicator (Bloomee style)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: GestureDetector(
                        onTap: onPlay,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent ? AppTheme.secondaryCyan : Colors.white.withValues(alpha: 0.95),
                            boxShadow: [
                              BoxShadow(
                                color: (isCurrent ? AppTheme.secondaryCyan : Colors.black).withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isPlaying
                                ? const PlayingBars(color: Colors.black, size: 16)
                                : const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            // Title
            Text(
              beat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: isCurrent ? AppTheme.secondaryCyan : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            // Producer/Artist
            Text(
              beat.artistDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            // Clean action row: TrackStats, Comment icon, Add to Cart
            Row(
              children: [
                Expanded(
                  child: TrackStats(trackId: beat.id, compact: true),
                ),
                IconButton(
                  tooltip: 'Comments & replies',
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppTheme.textSecondary,
                  onPressed: () => CommentBottomSheet.show(context, beat),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: beat.isFree ? 'Free beat' : 'Add to cart',
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: beat.isFree ? Colors.white24 : AppTheme.secondaryCyan,
                  onPressed: beat.isFree ? null : onAddToCart,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
