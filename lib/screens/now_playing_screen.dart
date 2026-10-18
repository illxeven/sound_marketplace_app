import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/audio_player_provider.dart';
import '../widgets/media_widgets.dart';

/// Full-screen player: artwork, seek bar with buffering, transport controls, shuffle/repeat,
/// live play count, and the editable "Up next" queue.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => const NowPlayingScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final track = player.currentTrack;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing is playing', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    final artSize = (MediaQuery.sizeOf(context).width - 64).clamp(180.0, 380.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Now playing', style: TextStyle(fontSize: 15)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Add to playlist',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () => showAddToPlaylistSheet(context, track),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                child: Column(
                  children: [
                    Hero(tag: 'cover-${track.id}', child: CoverImage(url: track.coverImageFullUrl, size: artSize, radius: 20)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(track.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(track.artistDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  TrackStats(trackId: track.id),
                                  if (player.isPreview(track.id)) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningOrange.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('30s preview',
                                          style: TextStyle(color: AppTheme.warningOrange, fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        LikeButton(trackId: track.id, size: 28),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _SeekBar(),
                    const SizedBox(height: 8),
                    const _Controls(),
                    if (player.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(player.errorMessage!,
                            textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('Up next', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const Spacer(),
                        Text('${player.queue.length} in queue',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Drag to reorder, swipe to remove',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
                  ],
                ),
              ),
            ),
            const _QueueList(),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar();

  @override
  Widget build(BuildContext context) {
    final player = context.read<AudioPlayerProvider>();
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? player.duration;
        final totalMs = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
        return StreamBuilder<Duration>(
          stream: player.bufferedPositionStream,
          builder: (context, bufSnap) {
            final buffered = (bufSnap.data ?? Duration.zero).inMilliseconds.toDouble().clamp(0.0, totalMs);
            return StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final value = pos.inMilliseconds.toDouble().clamp(0.0, totalMs);
                return Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: LinearProgressIndicator(
                            value: buffered / totalMs,
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            color: Colors.white24,
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            inactiveTrackColor: Colors.transparent,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: value,
                            max: totalMs,
                            activeColor: AppTheme.secondaryCyan,
                            onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(formatDuration(pos), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          const Spacer(),
                          Text(formatDuration(total), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final repeatIcon = switch (player.repeatMode) {
      RepeatMode.one => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };
    final repeatLabel = switch (player.repeatMode) {
      RepeatMode.off => 'Repeat off',
      RepeatMode.all => 'Repeat all',
      RepeatMode.one => 'Repeat one',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: player.shuffleEnabled ? 'Shuffle on' : 'Shuffle off',
          icon: Icon(Icons.shuffle_rounded,
              color: player.shuffleEnabled ? AppTheme.secondaryCyan : AppTheme.textSecondary),
          onPressed: player.toggleShuffle,
        ),
        IconButton(
          tooltip: 'Previous',
          iconSize: 36,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: player.previous,
        ),
        SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            heroTag: 'np-play',
            backgroundColor: AppTheme.secondaryCyan,
            foregroundColor: Colors.black,
            tooltip: player.isPlaying ? 'Pause' : 'Play',
            onPressed: player.togglePlayPause,
            child: player.isBuffering
                ? const SizedBox(
                    width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                : Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40),
          ),
        ),
        IconButton(
          tooltip: 'Next',
          iconSize: 36,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: player.next,
        ),
        IconButton(
          tooltip: repeatLabel,
          icon: Icon(repeatIcon,
              color: player.repeatMode == RepeatMode.off ? AppTheme.textSecondary : AppTheme.secondaryCyan),
          onPressed: player.cycleRepeat,
        ),
      ],
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final queue = player.queue;
    final current = player.currentIndex;
    return SliverReorderableList(
      itemCount: queue.length,
      onReorder: (from, to) => player.moveInQueue(from, to > from ? to - 1 : to),
      itemBuilder: (context, i) {
        final t = queue[i];
        final isCurrent = i == current;
        return Dismissible(
          key: ValueKey('q-${t.id}-$i'),
          direction: isCurrent ? DismissDirection.none : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: AppTheme.errorRed.withValues(alpha: 0.6),
            child: const Icon(Icons.delete_outline_rounded),
          ),
          onDismissed: (_) => player.removeFromQueue(i),
          child: Material(
            color: isCurrent ? AppTheme.primaryPurple.withValues(alpha: 0.18) : Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: CoverImage(url: t.coverImageFullUrl, size: 44, radius: 6),
              title: Text(t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: isCurrent ? AppTheme.secondaryCyan : AppTheme.textPrimary)),
              subtitle: Text(t.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCurrent) PlayingBars(active: player.isPlaying),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle_rounded, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              onTap: () => player.skipToQueueItem(i),
            ),
          ),
        );
      },
    );
  }
}
