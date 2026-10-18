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
import '../widgets/media_widgets.dart';
import 'cart_screen.dart';

/// Beats for sale: preview, like, queue and add to cart.
/// Grid on wide screens, list on phones; the beat that is playing is highlighted.
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
    if (user == null) return;
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
    final columns = width >= 1200 ? 5 : (width >= 900 ? 4 : (width >= 600 ? 3 : 0));
    final genres = <String>{'All', ...beats.map((b) => b.genre).whereType<String>()}.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beats', style: TextStyle(fontWeight: FontWeight.w900)),
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search beats by title or producer',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      labelStyle: TextStyle(color: sel ? Colors.black : AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      onSelected: (_) {
                        setState(() => _genre = g);
                        _reload();
                      },
                    );
                  },
                ),
              ),
            ),
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
            else if (columns == 0)
              SliverList.builder(
                itemCount: beats.length,
                itemBuilder: (_, i) => TrackRow(
                  track: beats[i],
                  showPrice: true,
                  onTap: () => context.read<AudioPlayerProvider>().playTrack(beats[i], playlistQueue: beats),
                  trailing: _BuyButton(beat: beats[i], onAdd: () => _addToCart(beats[i])),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.58,
                  ),
                  itemCount: beats.length,
                  itemBuilder: (_, i) => LayoutBuilder(
                    builder: (context, c) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MediaCard(
                          track: beats[i],
                          width: c.maxWidth,
                          showPrice: true,
                          onTap: () => context.read<AudioPlayerProvider>().playTrack(beats[i], playlistQueue: beats),
                        ),
                        const SizedBox(height: 6),
                        _BuyButton(beat: beats[i], onAdd: () => _addToCart(beats[i]), expanded: true),
                      ],
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({required this.beat, required this.onAdd, this.expanded = false});
  final Track beat;
  final VoidCallback onAdd;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final label = beat.isFree ? 'Free' : NumberFormat.simpleCurrency().format(beat.price);
    final button = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryPurple,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: beat.isFree ? null : onAdd,
      icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
