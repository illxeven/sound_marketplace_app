import 'api_client.dart';
import 'json_utils.dart';

/// A signed, expiring stream URL for one track (`/api/tracks/play-urls`).
class PlayUrl {
  final int trackId;
  final String url;

  /// Epoch seconds after which the server rejects the URL.
  final int expiresAt;

  /// True when the listener hasn't bought a paid track: the URL plays a 30-second preview.
  final bool isPreview;

  const PlayUrl({required this.trackId, required this.url, required this.expiresAt, required this.isPreview});

  factory PlayUrl.fromJson(Map<String, dynamic> json) => PlayUrl(
        trackId: asInt(json['trackId']) ?? 0,
        url: json['url'] as String,
        expiresAt: asInt(json['expiresAt']) ?? 0,
        isPreview: json['isPreview'] == true,
      );

  bool expiresWithin(Duration d) =>
      DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000).isBefore(DateTime.now().add(d));
}

class PlaybackService {
  /// Signed URLs for several tracks in one request.
  Future<Map<int, PlayUrl>> getPlayUrls(List<int> trackIds) async {
    if (trackIds.isEmpty) return {};
    final response = await ApiClient.post<List<PlayUrl>>(
      '/tracks/play-urls',
      body: {'ids': trackIds},
      fromJsonT: (json) =>
          extractItems(json).map((i) => PlayUrl.fromJson((i as Map).cast<String, dynamic>())).toList(),
    );
    return {for (final p in response.data ?? const <PlayUrl>[]) p.trackId: p};
  }
}
