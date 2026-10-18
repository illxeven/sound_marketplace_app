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
import '../screens/profile_screen.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track>? playlistQueue;

  const TrackTile({
    super.key,
    required this.track,
    this.playlistQueue,
  });

  void _showAddToPlaylistDialog(BuildContext context) {
    final playlistProv = context.read<PlaylistProvider>();
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

  @override
  Widget build(BuildContext context) {
    final audioPlayer = context.watch<AudioPlayerProvider>();
    final catalog = context.watch<CatalogProvider>();
    final auth = context.watch<AuthProvider>();

    final isCurrent = audioPlayer.currentTrack?.id == track.id;
    final isLiked = catalog.isTrackLiked(track.id);
    final likeCount = catalog.getTrackLikes(track.id);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.primaryPurple.withValues(alpha: 0.12) : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AppTheme.primaryPurple : Colors.white.withValues(alpha: 0.05),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            audioPlayer.playTrack(
              track,
              playlistQueue: playlistQueue,
              userId: auth.currentUser?.id,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Track Cover Art / Play Indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (track.coverUrl != null)
                          Image.network(
                            track.coverUrl!.startsWith('http')
                                ? track.coverUrl!
                                : ApiConfig.resolve(track.coverUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isCurrent ? AppTheme.primaryPurple : Colors.white.withValues(alpha: 0.08),
                              child: const Icon(Icons.music_note, color: Colors.white38),
                            ),
                          )
                        else
                          Container(
                            color: isCurrent ? AppTheme.primaryPurple : Colors.white.withValues(alpha: 0.08),
                            child: const Icon(Icons.music_note, color: Colors.white38),
                          ),
                        Container(
                          color: (track.coverUrl != null && !isCurrent)
                              ? Colors.black26
                              : (isCurrent ? Colors.black45 : Colors.transparent),
                          child: Icon(
                            isCurrent && audioPlayer.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: isCurrent ? AppTheme.secondaryCyan : Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Track Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isCurrent ? AppTheme.secondaryCyan : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: InkWell(
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
                              child: Text(
                                track.artistDisplay,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          if (track.isVideo) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.accentPink.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.accentPink.withValues(alpha: 0.5), width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_rounded, size: 10, color: AppTheme.accentPink),
                                  SizedBox(width: 2),
                                  Text(
                                    'VIDEO',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentPink,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (track.genre != null && track.genre!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                track.genre!,
                                style: const TextStyle(fontSize: 10, color: Colors.white70),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 13,
                            color: AppTheme.secondaryCyan.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 1),
                          Builder(
                            builder: (context) {
                              final catalog = context.watch<CatalogProvider>();
                              final plays = catalog.getTrackPlays(track.id) > 0
                                  ? catalog.getTrackPlays(track.id)
                                  : track.playsCount;
                              return Text(
                                '$plays',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: track.isFree
                        ? AppTheme.successGreen.withValues(alpha: 0.15)
                        : AppTheme.primaryPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    track.isFree ? 'FREE' : '\$${track.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: track.isFree ? AppTheme.successGreen : AppTheme.primaryPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Like Button & Counter
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? AppTheme.accentPink : Colors.white38,
                    size: 20,
                  ),
                  tooltip: 'Like ($likeCount)',
                  onPressed: () {
                    if (auth.currentUser != null) {
                      catalog.toggleLike(track.id, auth.currentUser!.id);
                    }
                  },
                ),
                // Comment Button
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white38,
                    size: 19,
                  ),
                  tooltip: 'Comments',
                  onPressed: () => CommentBottomSheet.show(context, track),
                ),
                // More / Add to Playlist
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
                  color: AppTheme.cardColor,
                  onSelected: (val) async {
                    if (val == 'playlist') {
                      _showAddToPlaylistDialog(context);
                    } else if (val == 'cart') {
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
                    } else if (val == 'repost') {
                      if (auth.currentUser != null) {
                        catalog.repostTrack(track.id, auth.currentUser!.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reposted "${track.title}"!')),
                        );
                      }
                    } else if (val == 'share') {
                      ShareDialog.show(
                        context,
                        title: track.title,
                        subtitle: 'Track by ${track.artistDisplay}',
                        shareUrl: '${ApiConfig.baseUrl}/tracks/${track.id}',
                        itemType: 'Track',
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'cart',
                      child: Row(
                        children: [
                          Icon(Icons.add_shopping_cart_rounded, color: AppTheme.secondaryCyan, size: 18),
                          SizedBox(width: 10),
                          Text('Add to Cart'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'playlist',
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add, color: AppTheme.secondaryCyan, size: 18),
                          SizedBox(width: 10),
                          Text('Add to Playlist'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'repost',
                      child: Row(
                        children: [
                          Icon(Icons.repeat_rounded, color: AppTheme.primaryPurple, size: 18),
                          SizedBox(width: 10),
                          Text('Repost Track'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded, color: AppTheme.secondaryCyan, size: 18),
                          SizedBox(width: 10),
                          Text('Share Track'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
