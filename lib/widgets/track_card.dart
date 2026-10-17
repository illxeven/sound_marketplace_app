import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/playlist_provider.dart';
import 'comment_bottom_sheet.dart';
import 'share_dialog.dart';
import '../screens/checkout_screen.dart';
import '../screens/profile_screen.dart';

class TrackCard extends StatelessWidget {
  final Track track;
  final List<Track>? playlistQueue;

  const TrackCard({
    super.key,
    required this.track,
    this.playlistQueue,
  });

  void _showTrackOptions(BuildContext context) {
    final playlistProv = context.read<PlaylistProvider>();
    final catalog = context.read<CatalogProvider>();
    final auth = context.read<AuthProvider>();
    final isLiked = catalog.isTrackLiked(track.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: _buildArtwork(),
                  ),
                ),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  track.artistAndFeaturesDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? AppTheme.accentPink : Colors.white70,
                ),
                title: Text(isLiked ? 'Unlike Track' : 'Like Track'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (auth.isAuthenticated) {
                    catalog.toggleLike(track.id, auth.currentUser!.id);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.white70),
                title: const Text('Share Track'),
                onTap: () {
                  Navigator.pop(ctx);
                  ShareDialog.show(
                    context,
                    title: track.title,
                    subtitle: track.artistAndFeaturesDisplay,
                    shareUrl: '${ApiConfig.baseUrl}/tracks/${track.id}',
                    itemType: 'Track',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70),
                title: const Text('View Comments'),
                onTap: () {
                  Navigator.pop(ctx);
                  CommentBottomSheet.show(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: Colors.white70),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistDialog(context, playlistProv);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_shopping_cart_rounded, color: AppTheme.secondaryCyan),
                title: Text(track.price > 0
                    ? 'Add to Cart (\$${track.price.toStringAsFixed(2)})'
                    : 'Add License to Cart (Free)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!auth.isAuthenticated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please log in to add items to your cart')),
                    );
                    return;
                  }
                  final ok = await context.read<CartProvider>().addToCart(
                        userId: auth.currentUser!.id,
                        trackId: track.id,
                        quantity: 1,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Added "${track.title}" to cart!' : 'Failed to add to cart'),
                        backgroundColor: ok ? AppTheme.successGreen : AppTheme.errorRed,
                      ),
                    );
                  }
                },
              ),
              if (track.price > 0)
                ListTile(
                  leading: const Icon(Icons.flash_on_rounded, color: AppTheme.accentPink),
                  title: Text('Buy Now with Stripe (\$${track.price.toStringAsFixed(2)})'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (!auth.isAuthenticated) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please log in to purchase tracks')),
                      );
                      return;
                    }
                    final chargeId = await CheckoutScreen.startCheckout(
                      context: context,
                      amount: track.price,
                      itemTitle: track.title,
                      itemType: 'track',
                      itemId: track.id,
                      user: auth.currentUser!,
                      metadata: {
                        'trackId': track.id.toString(),
                        'artistId': track.artistId.toString(),
                      },
                    );
                    if (chargeId != null && context.mounted) {
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: AppTheme.surfaceColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 28),
                              SizedBox(width: 10),
                              Text('Track Purchased!'),
                            ],
                          ),
                          content: Text(
                            'You have successfully purchased "${track.title}" via Stripe.\n\nStripe Reference: $chargeId',
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Great!'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, PlaylistProvider playlistProv) {
    final titleController = TextEditingController();
    bool isCreating = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.playlist_add, color: AppTheme.secondaryCyan),
              const SizedBox(width: 8),
              const Text('Add to Playlist'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCreating) ...[
                  const Text(
                    'Create New Playlist',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Playlist Title',
                      hintText: 'e.g., Chill Beats, Workout Mix',
                      prefixIcon: Icon(Icons.queue_music_rounded, color: AppTheme.primaryPurple),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setModalState(() {
                          isCreating = false;
                          titleController.clear();
                        }),
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                if (title.isEmpty) return;
                                final auth = context.read<AuthProvider>();
                                if (auth.currentUser == null) return;

                                setModalState(() => isSubmitting = true);
                                final newPl = await playlistProv.createPlaylist(
                                  userId: auth.currentUser!.id,
                                  title: title,
                                  trackIds: [track.id],
                                );
                                setModalState(() => isSubmitting = false);

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        newPl != null
                                            ? 'Created "${newPl.title}" and added "${track.title}"!'
                                            : 'Failed to create playlist',
                                      ),
                                      backgroundColor: newPl != null ? Colors.green : Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create & Add'),
                      ),
                    ],
                  ),
                ] else ...[
                  if (playlistProv.userPlaylists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'You don\'t have any playlists yet.\nCreate one right here to get started!',
                        style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlistProv.userPlaylists.length,
                        itemBuilder: (context, i) {
                          final pl = playlistProv.userPlaylists[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.playlist_play_rounded, color: AppTheme.secondaryCyan),
                            title: Text(pl.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${pl.tracks.length} tracks'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final success = await playlistProv.addTrackToPlaylist(pl.id, track.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Added "${track.title}" to ${pl.title}'
                                          : 'Failed to add track',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 4),
                  Center(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create New Playlist'),
                      onPressed: () => setModalState(() => isCreating = true),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtwork() {
    // 1. Prominently display cover_image_blob via Image.memory if available
    if (track.coverImageBlob != null && track.coverImageBlob!.isNotEmpty) {
      return Image.memory(
        track.coverImageBlob!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    // 2. Fall back to coverUrl via Image.network
    if (track.coverUrl != null && track.coverUrl!.isNotEmpty) {
      final fullUrl = track.coverUrl!.startsWith('http')
          ? track.coverUrl!
          : '${ApiConfig.baseUrl}${track.coverUrl!.startsWith('/') ? track.coverUrl! : '/${track.coverUrl!}'}';
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    // 3. Fallback gradient placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2050), Color(0xFF141226)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 38,
          color: AppTheme.secondaryCyan.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayer = context.watch<AudioPlayerProvider>();
    final auth = context.watch<AuthProvider>();
    final isCurrent = audioPlayer.currentTrack?.id == track.id;
    final isPlaying = isCurrent && audioPlayer.isPlaying;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!isCurrent) {
            context.read<CatalogProvider>().incrementTrackPlays(track.id);
          }
          audioPlayer.playTrack(
            track,
            playlistQueue: playlistQueue,
            userId: auth.currentUser?.id,
          );
        },
        onLongPress: () => _showTrackOptions(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Square Edge-to-Edge Cover Art Card (8px - 12px border radius)
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? AppTheme.primaryPurple
                        : Colors.white.withValues(alpha: 0.08),
                    width: isCurrent ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isCurrent
                          ? AppTheme.primaryPurple.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.25),
                      blurRadius: isCurrent ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildArtwork(),

                      // Video Badge Indicator
                      if (track.isVideo)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPink.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  'VIDEO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Active Playing Indicator Badge
                      if (isCurrent)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.secondaryCyan.withValues(alpha: 0.8),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 16,
                              color: AppTheme.secondaryCyan,
                            ),
                          ),
                        ),

                      // More options button (top right)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showTrackOptions(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.more_vert_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Track Title (Bold, clean white, ellipsis on overflow)
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 3),

            // 3. Artist Name & Features (Clickable to open Artist Profile & Storefront)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => ProfileScreen(
                      artistId: track.artistId,
                      artistName: track.artistDisplay,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  track.artistAndFeaturesDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 4. Metrics: Plays & Likes
            Builder(
              builder: (context) {
                final catalog = context.watch<CatalogProvider>();
                final likes = catalog.getTrackLikes(track.id) > 0
                    ? catalog.getTrackLikes(track.id)
                    : track.likesCount;
                final plays = catalog.getTrackPlays(track.id) > 0
                    ? catalog.getTrackPlays(track.id)
                    : track.playsCount;

                return Row(
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 13,
                      color: AppTheme.secondaryCyan.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$plays',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.favorite_rounded,
                      size: 11,
                      color: AppTheme.accentPink.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$likes',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
