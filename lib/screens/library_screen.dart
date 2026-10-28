import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../services/api_client.dart';
import '../services/json_utils.dart';
import '../widgets/media_widgets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Track> _tracks = [];
  final Set<int> _downloadingTrackIds = {};

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.get<Map<String, dynamic>>(
        '/library',
        fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      final rawItems = extractItems(res.data);
      final tracks = rawItems
          .map((i) => Track.fromJson((i as Map).cast<String, dynamic>()))
          .toList();

      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadTrack(Track track) async {
    setState(() => _downloadingTrackIds.add(track.id));

    try {
      final res = await ApiClient.get<Map<String, dynamic>>(
        '/library/${track.id}/download',
        fromJsonT: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      final rawUrl = res.data?['url'] as String?;
      if (rawUrl == null || rawUrl.isEmpty) {
        throw ApiException('Server returned an empty download URL.');
      }

      final resolvedUrl = ApiConfig.resolve(rawUrl);
      final uri = Uri.parse(resolvedUrl);

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting master download for "${track.title}"...'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.message}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open download URL: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingTrackIds.remove(track.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Purchased Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Library',
            onPressed: _loadLibrary,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadLibrary,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _tracks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.music_off_rounded, size: 54, color: Colors.white24),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'No purchased audio yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'When you buy tracks or beats, they will appear here with full master audio downloads.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tracks.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        final isDownloading = _downloadingTrackIds.contains(track.id);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CoverImage(
                                  url: track.coverImageFullUrl,
                                  size: 54,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${track.artistDisplay}${track.genre != null ? ' • ${track.genre}' : ''}',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Play Button
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.secondaryCyan, size: 30),
                                tooltip: 'Play',
                                onPressed: () {
                                  context.read<AudioPlayerProvider>().playTrack(track, playlistQueue: _tracks);
                                },
                              ),
                              const SizedBox(width: 4),
                              // Download Button (Requirement B1)
                              ElevatedButton.icon(
                                key: Key('download_button_${track.id}'),
                                icon: isDownloading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.download_rounded, size: 16),
                                label: Text(isDownloading ? '...' : 'Download'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: isDownloading ? null : () => _downloadTrack(track),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
