import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/track.dart';
import '../providers/catalog_provider.dart';
import '../widgets/track_card.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _genreAutocompleteController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadCatalog();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _genreAutocompleteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: AppTheme.secondaryCyan,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Sound Marketplace'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Catalog',
            onPressed: () => context.read<CatalogProvider>().loadCatalog(),
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
                                    : '${ApiConfig.baseUrl}${user.avatarUrl!.startsWith('/') ? user.avatarUrl! : '/${user.avatarUrl!}'}',
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
                        constraints: const BoxConstraints(maxWidth: 90),
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
      body: Consumer<CatalogProvider>(
        builder: (context, catalog, child) {
          final isFiltering =
              _searchController.text.trim().isNotEmpty ||
              (catalog.selectedGenre != null && catalog.selectedGenre != 'All');

          final List<Track> allTracks = catalog.tracks;
          final List<Track> recommendedTracks = allTracks.take(8).toList();

          return RefreshIndicator(
            color: AppTheme.primaryPurple,
            onRefresh: catalog.loadCatalog,
            child: CustomScrollView(
              slivers: [
                // Search Field
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tracks, artists, genres...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    catalog.setSearchQuery('');
                                  },
                                )
                                : null,
                      ),
                      onChanged: catalog.setSearchQuery,
                    ),
                  ),
                ),

                // Autocomplete Genre Dropdown Selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return catalog.availableGenres;
                        }
                        return catalog.availableGenres.where((String genre) {
                          return genre.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          );
                        });
                      },
                      onSelected: (String selection) {
                        catalog.setGenre(selection);
                      },
                      fieldViewBuilder: (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        // Sync controller if provider value changes externally
                        if (textEditingController.text.isEmpty &&
                            catalog.selectedGenre != null) {
                          textEditingController.text = catalog.selectedGenre!;
                        }
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Filter by Genre',
                            hintText: 'Select or type a genre...',
                            prefixIcon: const Icon(
                              Icons.filter_list_rounded,
                              color: AppTheme.secondaryCyan,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                textEditingController.clear();
                                catalog.setGenre('All');
                              },
                            ),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            color: const Color(0xFF1E1E2C),
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 200,
                              width: 300,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(
                                    index,
                                  );
                                  return ListTile(
                                    title: Text(
                                      option,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () {
                                      onSelected(option);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Loading State
                if (catalog.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  )
                // Error State
                else if (catalog.errorMessage != null && catalog.tracks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 48,
                              color: Colors.white38,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              catalog.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: catalog.loadCatalog,
                              child: const Text('Retry Connection'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                // Empty State
                else if (catalog.tracks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.music_off_rounded,
                            size: 48,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No tracks found',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _genreAutocompleteController.clear();
                              catalog.setGenre('All');
                              catalog.setSearchQuery('');
                            },
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    ),
                  )
                // Content with "More of what you like" and Responsive Grid
                else ...[
                  // 1. "More of what you like" Carousel
                  if (!isFiltering && recommendedTracks.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppTheme.secondaryCyan,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'More of what you like',
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 245,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: recommendedTracks.length,
                          separatorBuilder:
                              (ctx, i) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final track = recommendedTracks[index];
                            return SizedBox(
                              width: 152,
                              child: TrackCard(
                                track: track,
                                playlistQueue: allTracks,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],

                  // 2. Main Discovery Grid Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isFiltering
                                ? (catalog.selectedGenre != null &&
                                        catalog.selectedGenre != 'All'
                                    ? '${catalog.selectedGenre} Tracks'
                                    : 'Search Results')
                                : 'Explore All Sounds',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${allTracks.length} tracks',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Responsive Grid Layout of Square Track Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.69,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final track = allTracks[index];
                        return TrackCard(
                          track: track,
                          playlistQueue: allTracks,
                        );
                      }, childCount: allTracks.length),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }
}
