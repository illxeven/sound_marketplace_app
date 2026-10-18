import 'package:flutter/foundation.dart';

import '../models/track_comment.dart';
import 'api_client.dart';
import 'json_utils.dart';

/// Result of reporting a play: whether the server counted it, and the track's new total.
class PlayEventResult {
  final bool counted;
  final int? playCount;

  const PlayEventResult({required this.counted, this.playCount});
}

/// Likes, comments, reposts and play counts.
///
/// The signed-in user is taken from the access token by the server. The `userId` parameters
/// are kept so existing callers compile, but they are no longer sent.
class EngagementService {
  Future<void> likeTrack(int trackId, [int? userId]) async {
    await ApiClient.post('/tracks/$trackId/like');
  }

  Future<void> unlikeTrack(int trackId, [int? userId]) async {
    await ApiClient.delete('/tracks/$trackId/like');
  }

  /// Ids of every track the signed-in user has liked.
  Future<Set<int>> getLikedTrackIds() async {
    final response = await ApiClient.get<Set<int>>(
      '/users/me/liked-track-ids',
      fromJsonT: (json) => extractItems(json).map(asInt).whereType<int>().toSet(),
    );
    return response.data ?? <int>{};
  }

  Future<int> getTrackLikesCount(int trackId) async {
    final response = await ApiClient.get<int>(
      '/tracks/$trackId/likes/count',
      fromJsonT: (json) => (json as num).toInt(),
    );
    return response.data ?? 0;
  }

  /// Reports that a track started, finished or replayed. The server ignores repeats that come
  /// too quickly (a real re-listen must be at least half the track, min 30 s, apart) and returns
  /// the current total so the UI can update immediately.
  Future<PlayEventResult> recordPlayEvent(int trackId) async {
    try {
      final response = await ApiClient.post<Map<String, dynamic>>(
        '/tracks/$trackId/play-event',
        fromJsonT: (json) => (json as Map).cast<String, dynamic>(),
      );
      final data = response.data ?? const {};
      return PlayEventResult(counted: data['recorded'] == true, playCount: asInt(data['playCount']));
    } on ApiException catch (e) {
      // A missed play count must never interrupt playback.
      debugPrint('[engagement] play-event failed trackId=$trackId status=${e.statusCode} requestId=${e.requestId}');
      return const PlayEventResult(counted: false);
    }
  }

  /// Kept for older callers; use [recordPlayEvent].
  Future<void> recordPlayback(int trackId, [int? userId]) async {
    await recordPlayEvent(trackId);
  }

  Future<TrackComment> addComment(
    int trackId,
    int userId,
    String commentText, {
    int? parentCommentId,
  }) async {
    final response = await ApiClient.post<TrackComment>(
      '/tracks/$trackId/comments',
      body: {
        'commentText': commentText,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      },
      fromJsonT: (json) => TrackComment.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to post comment');
    }
    return response.data!;
  }

  Future<List<TrackComment>> getComments(int trackId) async {
    final response = await ApiClient.get<List<TrackComment>>(
      '/tracks/$trackId/comments',
      fromJsonT: (json) =>
          extractItems(json).map((i) => TrackComment.fromJson(i as Map<String, dynamic>)).toList(),
    );
    return response.data ?? [];
  }

  Future<void> repostTrack(int trackId, [int? userId]) async {
    await ApiClient.post('/tracks/$trackId/repost');
  }

  Future<TrackComment> updateComment(int commentId, int userId, String commentText) async {
    final response = await ApiClient.put<TrackComment>(
      '/tracks/comments/$commentId',
      body: {'commentText': commentText},
      fromJsonT: (json) => TrackComment.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to update comment');
    }
    return response.data!;
  }

  Future<void> deleteComment(int commentId, [int? userId]) async {
    await ApiClient.delete('/tracks/comments/$commentId');
  }
}
