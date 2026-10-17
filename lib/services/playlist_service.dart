import '../models/playlist.dart';
import 'api_client.dart';

class PlaylistService {
  Future<List<Playlist>> getPublicPlaylists() async {
    final response = await ApiClient.get<List<Playlist>>(
      '/playlists',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => Playlist.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<List<Playlist>> getUserPlaylists(int userId) async {
    final response = await ApiClient.get<List<Playlist>>(
      '/playlists/user/$userId',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => Playlist.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<Playlist> createPlaylist({
    required int userId,
    required String title,
    bool isPublic = true,
    List<int> trackIds = const [],
  }) async {
    final response = await ApiClient.post<Playlist>(
      '/playlists',
      body: {
        'userId': userId,
        'title': title,
        'isPublic': isPublic,
        'trackIds': trackIds,
      },
      fromJsonT: (json) => Playlist.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to create playlist');
    }
    return response.data!;
  }

  Future<Playlist> addTrackToPlaylist(int playlistId, int trackId) async {
    final response = await ApiClient.post<Playlist>(
      '/playlists/$playlistId/tracks/$trackId',
      fromJsonT: (json) => Playlist.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to add track to playlist');
    }
    return response.data!;
  }
}
