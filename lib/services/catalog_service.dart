import '../models/album.dart';
import '../models/track.dart';
import 'api_client.dart';

class CatalogService {
  Future<List<Track>> getAllTracks() async {
    final response = await ApiClient.get<List<Track>>(
      '/tracks',
      fromJsonT: (json) {
        if (json is List) {
          return json
              .map((i) => Track.fromJson(i as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<List<Track>> getTracksByGenre(String genre) async {
    final response = await ApiClient.get<List<Track>>(
      '/tracks/genre/$genre',
      fromJsonT: (json) {
        if (json is List) {
          return json
              .map((i) => Track.fromJson(i as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<List<String>> getGenres() async {
    final response = await ApiClient.get<List<String>>(
      '/genres',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => i.toString()).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<List<Track>> getTracksByArtist(int artistId) async {
    final response = await ApiClient.get<List<Track>>(
      '/tracks/artist/$artistId',
      fromJsonT: (json) {
        if (json is List) {
          return json
              .map((i) => Track.fromJson(i as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<Track?> getTrackById(int id) async {
    final response = await ApiClient.get<Track>(
      '/tracks/$id',
      fromJsonT: (json) => Track.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<Track> createTrack({
    required int artistId,
    int? albumId,
    required String title,
    required String filePath,
    required String genre,
    required double price,
    String? artistName,
    String? features,
    int? durationSeconds,
    bool? isPromoted,
    String uploadSource = 'PROFILE_PAGE',
    int? uploaderUserId,
  }) async {
    final response = await ApiClient.post<Track>(
      '/tracks',
      body: {
        'artistId': artistId,
        'albumId': albumId,
        'title': title,
        'filePath': filePath,
        'genre': genre,
        'price': price,
        if (artistName != null) 'artistName': artistName,
        if (features != null) 'features': features,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (isPromoted != null) 'isPromoted': isPromoted,
        'uploadSource': uploadSource,
        'uploaderUserId': uploaderUserId ?? artistId,
      },
      fromJsonT: (json) => Track.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to upload track');
    }
    return response.data!;
  }

  Future<Track> uploadTrack({
    required int artistId,
    int? albumId,
    required String title,
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
    String? videoPath,
    List<int>? videoBytes,
    String? videoName,
    String mediaType = 'AUDIO',
    String? coverArtPath,
    List<int>? coverArtBytes,
    String? coverArtName,
    required String genre,
    required double price,
    String? artistName,
    String? features,
    int? durationSeconds,
    bool? isPromoted,
    String uploadSource = 'PROFILE_PAGE',
    int? uploaderUserId,
  }) async {
    // If an audio file or video file or bytes are provided, upload directly to the backend storage endpoint
    if ((filePath != null && filePath.isNotEmpty) ||
        (fileBytes != null && fileBytes.isNotEmpty) ||
        (videoPath != null && videoPath.isNotEmpty) ||
        (videoBytes != null && videoBytes.isNotEmpty)) {
      final fields = <String, String>{
        'title': title,
        'artistId': artistId.toString(),
        'genre': genre,
        'price': price.toString(),
        'mediaType': mediaType,
        'uploadSource': uploadSource,
        'uploaderUserId': (uploaderUserId ?? artistId).toString(),
        if (artistName != null && artistName.isNotEmpty)
          'artistName': artistName,
        if (features != null && features.isNotEmpty) 'features': features,
        if (albumId != null) 'albumId': albumId.toString(),
        if (durationSeconds != null)
          'durationSeconds': durationSeconds.toString(),
        if (isPromoted != null) 'isPromoted': isPromoted.toString(),
      };

      final filesList = <MultipartFileItem>[];

      if ((filePath != null && filePath.isNotEmpty) || (fileBytes != null && fileBytes.isNotEmpty)) {
        String name =
            fileName ??
            (filePath != null
                ? filePath.split(RegExp(r'[\\/]')).last
                : 'track.mp3');
        filesList.add(
          MultipartFileItem(
            field: 'audioFile',
            filePath: filePath,
            fileBytes: fileBytes,
            filename: name,
          ),
        );
      }

      if ((videoPath != null && videoPath.isNotEmpty) || (videoBytes != null && videoBytes.isNotEmpty)) {
        String vName =
            videoName ??
            (videoPath != null
                ? videoPath.split(RegExp(r'[\\/]')).last
                : 'video.mp4');
        filesList.add(
          MultipartFileItem(
            field: 'videoFile',
            filePath: videoPath,
            fileBytes: videoBytes,
            filename: vName,
          ),
        );
      }

      if ((coverArtPath != null && coverArtPath.isNotEmpty) ||
          (coverArtBytes != null && coverArtBytes.isNotEmpty)) {
        filesList.add(
          MultipartFileItem(
            field: 'coverArt',
            filePath: coverArtPath,
            fileBytes: coverArtBytes,
            filename: coverArtName ?? 'cover.jpg',
          ),
        );
      }

      final response = await ApiClient.postMultipart<Track>(
        '/tracks/upload',
        files: filesList,
        fields: fields,
        fromJsonT: (json) => Track.fromJson(json as Map<String, dynamic>),
      );

      if (response.data == null) {
        throw ApiException(
          response.message ?? 'Failed to upload track to backend storage',
        );
      }
      return response.data!;
    } else {
      return createTrack(
        artistId: artistId,
        albumId: albumId,
        title: title,
        filePath: filePath ?? '',
        genre: genre,
        price: price,
        artistName: artistName,
        features: features,
        durationSeconds: durationSeconds,
        isPromoted: isPromoted,
        uploadSource: uploadSource,
        uploaderUserId: uploaderUserId,
      );
    }
  }

  Future<Track> updateTrackCover({
    required int trackId,
    String? coverArtPath,
    List<int>? coverArtBytes,
    String? coverArtName,
  }) async {
    final response = await ApiClient.postMultipart<Track>(
      '/tracks/$trackId/cover',
      fileField: 'coverArt',
      filePath: coverArtPath,
      fileBytes: coverArtBytes,
      filename: coverArtName ?? 'cover.jpg',
      fromJsonT: (json) => Track.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<List<Album>> getAllAlbums() async {
    final response = await ApiClient.get<List<Album>>(
      '/albums',
      fromJsonT: (json) {
        if (json is List) {
          return json
              .map((i) => Album.fromJson(i as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<Album> createAlbum({
    required int artistId,
    required String title,
    String? coverArtUrl,
  }) async {
    final response = await ApiClient.post<Album>(
      '/albums',
      body: {'artistId': artistId, 'title': title, 'coverArtUrl': coverArtUrl},
      fromJsonT: (json) => Album.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to create album');
    }
    return response.data!;
  }
}
