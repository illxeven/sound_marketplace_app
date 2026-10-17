import '../models/track_comment.dart';
import 'api_client.dart';

class EngagementService {
  Future<void> likeTrack(int trackId, int userId) async {
    await ApiClient.post(
      '/tracks/$trackId/like',
      queryParameters: {'userId': userId},
    );
  }

  Future<void> unlikeTrack(int trackId, int userId) async {
    await ApiClient.delete(
      '/tracks/$trackId/like',
      queryParameters: {'userId': userId},
    );
  }

  Future<int> getTrackLikesCount(int trackId) async {
    final response = await ApiClient.get<int>(
      '/tracks/$trackId/likes/count',
      fromJsonT: (json) => (json as num).toInt(),
    );
    return response.data ?? 0;
  }

  Future<TrackComment> addComment(
    int trackId,
    int userId,
    String commentText, {
    int? parentCommentId,
  }) async {
    final Map<String, dynamic> body = {
      'commentText': commentText,
    };
    if (parentCommentId != null) {
      body['parentCommentId'] = parentCommentId;
    }
    final response = await ApiClient.post<TrackComment>(
      '/tracks/$trackId/comments',
      queryParameters: {'userId': userId},
      body: body,
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
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => TrackComment.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<void> repostTrack(int trackId, int userId) async {
    await ApiClient.post(
      '/tracks/$trackId/repost',
      queryParameters: {'userId': userId},
    );
  }

  Future<void> recordPlayback(int trackId, [int? userId]) async {
    final Map<String, dynamic> params = {};
    if (userId != null) {
      params['userId'] = userId;
    }
    await ApiClient.post(
      '/tracks/$trackId/playback',
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<TrackComment> updateComment(int commentId, int userId, String commentText) async {
    final response = await ApiClient.put<TrackComment>(
      '/tracks/comments/$commentId',
      queryParameters: {'userId': userId},
      body: {'commentText': commentText},
      fromJsonT: (json) => TrackComment.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to update comment');
    }
    return response.data!;
  }

  Future<void> deleteComment(int commentId, int userId) async {
    await ApiClient.delete(
      '/tracks/comments/$commentId',
      queryParameters: {'userId': userId},
    );
  }
}
