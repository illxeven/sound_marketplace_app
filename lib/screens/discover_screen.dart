import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/media_widgets.dart';

/// Discover: greeting + search, genre chips, "Trending" and "New releases" shelves, a
/// "Beats for sale" shelf, then every track in an endless list.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, this.onOpenBeats});

  /// Switches the home tab to Beats ("See all" on the beats shelf).
  final VoidCallback? onOpenBeats;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalog = context.read<CatalogProvider>();
      if (catalog.allTracks.isEmpty) catalog.loadCatalog();
      if (catalog.beats.isEmpty) catalog.loadBeats();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent * 0.8) {
      context.read<CatalogProvider>().loadMoreTracks();
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<CatalogProvider>().setSearchQuery(q);
    });
  }

  void _play(Track t, List<Track> list) => context.read<AudioPlayerProvider>().playTrack(t, playlistQueue: list);

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final name = context.select<AuthProvider, String?>((a) => a.currentUser?.effectiveName);
    final filtering = catalog.searchQuery.trim().isNotEmpty || catalog.selectedGenre != null;
    final results = catalog.tracks;
    final cardWidth = MediaQuery.sizeOf(context).width >= 900 ? 180.0 : 150.0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.secondaryCyan,
          onRefresh: () async {
            await Future.wait([catalog.loadCatalog(), catalog.loadBeats()]);
          },
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      Text(name ?? 'Discover',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _search,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search songs, artists, genres',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _search.clear();
                                    catalog.setSearchQuery('');
                                    setState(() {});
                                  },
                                ),
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _GenreChips(catalog: catalog)),
              if (catalog.errorMessage != null && catalog.allTracks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(message: catalog.errorMessage!, onRetry: catalog.loadCatalog),
                )
              else if (catalog.isLoading && catalog.allTracks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.secondaryCyan)),
                )
              else if (filtering) ...[
                _SectionHeader(title: results.isEmpty ? 'No matches' : '${results.length} results'),
                SliverList.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) => TrackRow(track: results[i], onTap: () => _play(results[i], results)),
                ),
              ] else ...[
                if (catalog.trendingTracks.isNotEmpty) ...[
                  const _SectionHeader(title: 'Trending now'),
                  _Shelf(tracks: catalog.trendingTracks, cardWidth: cardWidth, onPlay: _play),
                ],
                if (catalog.allTracks.isNotEmpty) ...[
                  const _SectionHeader(title: 'New releases'),
                  _Shelf(tracks: catalog.allTracks.take(12).toList(), cardWidth: cardWidth, onPlay: _play),
                ],
                if (catalog.beats.isNotEmpty) ...[
                  _SectionHeader(title: 'Beats for sale', onSeeAll: widget.onOpenBeats),
                  _Shelf(tracks: catalog.beats.take(12).toList(), cardWidth: cardWidth, onPlay: _play, showPrice: true),
                ],
                const _SectionHeader(title: 'All tracks'),
                SliverList.builder(
                  itemCount: catalog.allTracks.length,
                  itemBuilder: (_, i) => TrackRow(
                    track: catalog.allTracks[i],
                    index: i,
                    onTap: () => _play(catalog.allTracks[i], catalog.allTracks),
                  ),
                ),
                if (catalog.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.catalog});
  final CatalogProvider catalog;

  @override
  Widget build(BuildContext context) {
    final genres = catalog.availableGenres;
    final selected = catalog.selectedGenre ?? 'All';
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = genres[i];
          final isSel = g == selected;
          return ChoiceChip(
            label: Text(g),
            selected: isSel,
            onSelected: (_) => catalog.setGenre(g),
            selectedColor: AppTheme.secondaryCyan,
            labelStyle: TextStyle(color: isSel ? Colors.black : AppTheme.textPrimary, fontWeight: FontWeight.w600),
            backgroundColor: AppTheme.surfaceColor,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('See all')),
            ],
          ),
        ),
      );
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.tracks, required this.cardWidth, required this.onPlay, this.showPrice = false});
  final List<Track> tracks;
  final double cardWidth;
  final void Function(Track, List<Track>) onPlay;
  final bool showPrice;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: SizedBox(
          height: cardWidth + 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => MediaCard(
              track: tracks[i],
              width: cardWidth,
              showPrice: showPrice,
              onTap: () => onPlay(tracks[i], tracks),
            ),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
}
