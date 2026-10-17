import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../providers/audio_player_provider.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, player, child) {
        final track = player.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Audio progress scrubber
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: AppTheme.primaryPurple,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: AppTheme.secondaryCyan,
                  ),
                  child: Slider(
                    value: player.position.inSeconds.toDouble().clamp(
                          0.0,
                          player.duration.inSeconds.toDouble().clamp(1.0, 9999.0),
                        ),
                    max: player.duration.inSeconds.toDouble().clamp(1.0, 9999.0),
                    onChanged: (val) {
                      player.seek(Duration(seconds: val.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      // Album Art Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primaryPurple, AppTheme.secondaryCyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: track.coverUrl != null
                              ? Image.network(
                                  track.coverUrl!.startsWith('http')
                                      ? track.coverUrl!
                                      : '${ApiConfig.baseUrl}${track.coverUrl!.startsWith('/') ? track.coverUrl! : '/${track.coverUrl!}'}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                )
                              : const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                  size: 26,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title & Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${track.artistDisplay} • ${_formatDuration(player.position)} / ${_formatDuration(player.duration)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.secondaryCyan,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Controls
                      IconButton(
                        tooltip: player.isLooping ? 'Repeat: On' : 'Repeat: Off',
                        icon: Icon(
                          player.isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                          color: player.isLooping ? AppTheme.secondaryCyan : Colors.white38,
                          size: 20,
                        ),
                        onPressed: player.toggleLoop,
                      ),
                      IconButton(
                        tooltip: 'Replay from start',
                        icon: const Icon(Icons.replay_rounded, color: Colors.white70, size: 20),
                        onPressed: player.replayTrack,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70),
                        onPressed: player.previous,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: player.togglePlayPause,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white70),
                        onPressed: player.next,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                        onPressed: player.stop,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
