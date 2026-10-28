import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/audio_player_provider.dart';
import '../screens/now_playing_screen.dart';
import 'media_widgets.dart';

/// Bar above the bottom navigation. Tap to open the full player.
/// The progress line listens to the position stream directly, so nothing else rebuilds per tick.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return Material(
      color: AppTheme.surfaceColor,
      child: InkWell(
        onTap: () => NowPlayingScreen.open(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snap) {
                final total = player.duration.inMilliseconds;
                final pos = (snap.data ?? Duration.zero).inMilliseconds;
                return LinearProgressIndicator(
                  value: total > 0 ? (pos / total).clamp(0.0, 1.0) : 0,
                  minHeight: 2,
                  backgroundColor: Colors.white10,
                  color: AppTheme.secondaryCyan,
                );
              },
            ),
            if (player.errorMessage != null)
              Container(
                color: Colors.amber.shade900.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 13, color: Colors.amberAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        player.errorMessage!,
                        key: const Key('mini_player_error_text'),
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: player.clearError,
                      child: const Icon(Icons.close, size: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Hero(tag: 'cover-${track.id}', child: CoverImage(url: track.coverImageFullUrl, size: 44, radius: 8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            Flexible(
                              child: Text(track.artistDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            TrackStats(trackId: track.id, compact: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  LikeButton(trackId: track.id),
                  IconButton(
                    tooltip: 'Previous',
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: player.previous,
                  ),
                  IconButton(
                    tooltip: player.isPlaying ? 'Pause' : 'Play',
                    iconSize: 34,
                    icon: player.isBuffering
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            color: AppTheme.secondaryCyan),
                    onPressed: player.togglePlayPause,
                  ),
                  IconButton(
                    tooltip: 'Next',
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: player.next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
