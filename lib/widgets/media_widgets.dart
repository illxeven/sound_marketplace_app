import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/playlist_provider.dart';
import 'comment_bottom_sheet.dart';

/// Compact counts: 950, 1.2K, 3.4M.
String formatCount(int n) => NumberFormat.compact().format(n);

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Cover art from the server, cached on disk, with a gradient placeholder.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.url, this.size, this.radius = 12, this.icon = Icons.music_note_rounded});

  final String? url;
  final double? size;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2050), Color(0xFF141226)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, color: AppTheme.secondaryCyan.withValues(alpha: 0.6), size: (size ?? 120) * 0.35),
    );
    // Decode at display size (x device pixel ratio) instead of full resolution.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: size != null ? (size! * dpr).round() : null,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            ),
    );
  }
}

/// Animated equalizer bars marking the track that is playing.
class PlayingBars extends StatefulWidget {
  const PlayingBars({super.key, this.active = true, this.color = AppTheme.secondaryCyan, this.size = 16});

  final bool active;
  final Color color;
  final double size;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const phases = [0.0, 0.35, 0.7];
    return Semantics(
      label: widget.active ? 'Playing' : 'Paused',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final p in phases)
                Container(
                  width: widget.size / 4.5,
                  height: widget.size *
                      (widget.active ? 0.3 + 0.7 * (0.5 + 0.5 * _wave((_c.value + p) % 1.0)) : 0.35),
                  decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _wave(double t) => t < 0.5 ? (t * 4 - 1) : (3 - t * 4);
}

/// Small "▶ 1.2K   ♥ 85" counters.
class TrackStats extends StatelessWidget {
  const TrackStats({super.key, required this.trackId, this.compact = false});

  final int trackId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final plays = context.select<CatalogProvider, int>((c) => c.getTrackPlays(trackId));
    final likes = context.select<CatalogProvider, int>((c) => c.getTrackLikes(trackId));
    const style = TextStyle(color: AppTheme.textSecondary, fontSize: 11.5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_arrow_rounded, size: 14, color: AppTheme.textSecondary),
        Text(formatCount(plays), style: style),
        if (!compact) ...[
          const SizedBox(width: 10),
          const Icon(Icons.favorite_rounded, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 2),
          Text(formatCount(likes), style: style),
        ],
      ],
    );
  }
}

/// Heart toggle wired to CatalogProvider.
class LikeButton extends StatelessWidget {
  const LikeButton({super.key, required this.trackId, this.size = 22});

  final int trackId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final liked = context.select<CatalogProvider, bool>((c) => c.isTrackLiked(trackId));
    return IconButton(
      tooltip: liked ? 'Unlike' : 'Like',
      iconSize: size,
      icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? AppTheme.accentPink : AppTheme.textSecondary),
      onPressed: () => context.read<CatalogProvider>().toggleLike(trackId),
    );
  }
}

/// Large square card for horizontal shelves (Bloomee-style explore rows).
class MediaCard extends StatelessWidget {
  const MediaCard({super.key, required this.track, required this.onTap, this.width = 150, this.showPrice = false});

  final Track track;
  final VoidCallback onTap;
  final double width;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final isCurrent = context.select<AudioPlayerProvider, bool>((p) => p.currentTrack?.id == track.id);
    final isPlaying = context.select<AudioPlayerProvider, bool>((p) => p.currentTrack?.id == track.id && p.isPlaying);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: () => showTrackActions(context, track),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverImage(url: track.coverImageFullUrl, size: width, radius: 14),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: isCurrent ? Border.all(color: AppTheme.secondaryCyan, width: 2) : null,
                      gradient: const LinearGradient(
                        colors: [Colors.transparent, Color(0xAA000000)],
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: isCurrent ? AppTheme.secondaryCyan : Colors.white,
                    child: isPlaying
                        ? const PlayingBars(color: Colors.black, size: 14)
                        : const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                  ),
                ),
                if (showPrice && !track.isFree)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _PriceChip(price: track.price),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: isCurrent ? AppTheme.secondaryCyan : AppTheme.textPrimary,
                )),
            Text(track.artistDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(child: TrackStats(trackId: track.id, compact: true)),
                IconButton(
                  tooltip: 'Comments',
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  color: AppTheme.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => CommentBottomSheet.show(context, track),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.price});
  final double price;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppTheme.primaryPurple, borderRadius: BorderRadius.circular(20)),
        child: Text(NumberFormat.simpleCurrency().format(price),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Colors.white)),
      );
}

/// List row: cover, title/artist, live counts, like button and an actions menu.
class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.onTap,
    this.index,
    this.trailing,
    this.showPrice = false,
  });

  final Track track;
  final VoidCallback onTap;
  final int? index;
  final Widget? trailing;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final isCurrent = context.select<AudioPlayerProvider, bool>((p) => p.currentTrack?.id == track.id);
    final isPlaying = context.select<AudioPlayerProvider, bool>((p) => p.currentTrack?.id == track.id && p.isPlaying);
    return InkWell(
      onTap: onTap,
      onLongPress: () => showTrackActions(context, track),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (index != null)
              SizedBox(
                width: 28,
                child: isCurrent
                    ? PlayingBars(active: isPlaying, size: 14)
                    : Text('${index! + 1}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
              ),
            Stack(
              alignment: Alignment.center,
              children: [
                CoverImage(url: track.coverImageFullUrl, size: 52, radius: 8),
                if (isCurrent && index == null)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: PlayingBars(active: isPlaying)),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? AppTheme.secondaryCyan : AppTheme.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(track.artistDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                  const SizedBox(height: 3),
                  TrackStats(trackId: track.id),
                ],
              ),
            ),
            if (showPrice && !track.isFree) _PriceChip(price: track.price),
            IconButton(
              tooltip: 'Comments',
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AppTheme.textSecondary),
              onPressed: () => CommentBottomSheet.show(context, track),
            ),
            if (trailing != null) trailing! else LikeButton(trackId: track.id),
            IconButton(
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
              onPressed: () => showTrackActions(context, track),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: play next, add to queue, add to playlist, like.
Future<void> showTrackActions(BuildContext context, Track track) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surfaceColor,
    showDragHandle: true,
    builder: (sheet) {
      final player = sheet.read<AudioPlayerProvider>();
      void done(String message) {
        Navigator.pop(sheet);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CoverImage(url: track.coverImageFullUrl, size: 44, radius: 6),
              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(track.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.queue_play_next_rounded),
              title: const Text('Play next'),
              onTap: () async {
                await player.playNext(track);
                done('"${track.title}" plays next');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue_rounded),
              title: const Text('Add to queue'),
              onTap: () async {
                await player.addToQueue(track);
                done('Added to queue');
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(sheet);
                showAddToPlaylistSheet(context, track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Comments & replies'),
              onTap: () {
                Navigator.pop(sheet);
                CommentBottomSheet.show(context, track);
              },
            ),
            Builder(builder: (ctx) {
              final liked = ctx.select<CatalogProvider, bool>((c) => c.isTrackLiked(track.id));
              return ListTile(
                leading: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: liked ? AppTheme.accentPink : null),
                title: Text(liked ? 'Remove from liked' : 'Like'),
                onTap: () {
                  ctx.read<CatalogProvider>().toggleLike(track.id);
                  Navigator.pop(sheet);
                },
              );
            }),
          ],
        ),
      );
    },
  );
}

/// Pick one of the user's playlists or create a new one with this track.
Future<void> showAddToPlaylistSheet(BuildContext context, Track track) async {
  final user = context.read<AuthProvider>().currentUser;
  if (user == null) return;
  final playlists = context.read<PlaylistProvider>();
  if (playlists.userPlaylists.isEmpty) await playlists.loadPlaylists(user.id);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surfaceColor,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final mine = sheet.watch<PlaylistProvider>().userPlaylists;
      void report(bool ok, String okText) {
        Navigator.pop(sheet);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? okText : (playlists.errorMessage ?? "Couldn't update the playlist.")),
          backgroundColor: ok ? AppTheme.successGreen : AppTheme.errorRed,
        ));
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Add to playlist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryPurple,
                  child: Icon(Icons.add_rounded, color: Colors.white),
                ),
                title: const Text('New playlist'),
                onTap: () async {
                  final name = await _askPlaylistName(sheet);
                  if (name == null) return;
                  final created = await playlists.createPlaylist(userId: user.id, title: name, trackIds: [track.id]);
                  if (sheet.mounted) report(created != null, 'Created "$name"');
                },
              ),
              for (final p in mine)
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded, color: AppTheme.secondaryCyan),
                  title: Text(p.title),
                  subtitle: Text('${p.tracks.length} tracks'),
                  onTap: () async {
                    final ok = await playlists.addTrackToPlaylist(p.id, track.id);
                    if (sheet.mounted) report(ok, 'Added to "${p.title}"');
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> _askPlaylistName(BuildContext context) {
  final controller = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: InputDecoration(labelText: 'Name', errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                setState(() => error = 'Give your playlist a name');
                return;
              }
              Navigator.pop(ctx, name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}
