import 'package:flutter/foundation.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../models/track_comment.dart';
import '../services/catalog_service.dart';
import '../services/engagement_service.dart';

class CatalogProvider extends ChangeNotifier {
  final CatalogService _catalogService = CatalogService();
  final EngagementService _engagementService = EngagementService();

  List<Track> _tracks = [];
  List<Album> _albums = [];
  List<String> _dbGenres = [];
  String? _selectedGenre;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  final Set<int> _likedTrackIds = {};
  final Map<int, int> _likeCounts = {};
  final Map<int, int> _playCounts = {};
  final Map<int, List<TrackComment>> _trackComments = {};

  List<Track> get tracks {
    return _tracks.where((t) {
      final matchesGenre =
          _selectedGenre == null ||
          _selectedGenre!.isEmpty ||
          _selectedGenre == 'All' ||
          (t.genre != null &&
              t.genre!.toLowerCase() == _selectedGenre!.toLowerCase());
      final matchesSearch =
          _searchQuery.isEmpty ||
          t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t.artistEmail != null &&
              t.artistEmail!.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ));
      return matchesGenre && matchesSearch;
    }).toList();
  }

  List<Album> get albums => _albums;
  String? get selectedGenre => _selectedGenre;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isTrackLiked(int trackId) => _likedTrackIds.contains(trackId);
  int getTrackLikes(int trackId) => _likeCounts[trackId] ?? 0;
  int getTrackPlays(int trackId) {
    if (_playCounts.containsKey(trackId)) {
      return _playCounts[trackId]!;
    }
    for (final t in _tracks) {
      if (t.id == trackId) return t.playsCount;
    }
    return 0;
  }

  void incrementTrackPlays(int trackId) {
    final current = getTrackPlays(trackId);
    _playCounts[trackId] = current + 1;
    final idx = _tracks.indexWhere((t) => t.id == trackId);
    if (idx != -1) {
      _tracks[idx] = _tracks[idx].copyWith(playsCount: current + 1);
    }
    notifyListeners();
  }

  List<TrackComment> getCommentsForTrack(int trackId) =>
      _trackComments[trackId] ?? [];

  List<String> get availableGenres {
    final set = <String>{'All'};
    if (_dbGenres.isNotEmpty) {
      set.addAll(_dbGenres);
    }
    for (var t in _tracks) {
      if (t.genre != null && t.genre!.isNotEmpty) {
        set.add(t.genre!);
      }
    }
    if (set.length == 1) {
      set.addAll([
        'Hip Hop & Rap (General)',
        'Electronic',
        'Pop',
        'R&B & Soul',
        'Rock',
        'Other',
      ]);
    }
    return set.toList();
  }

  Future<void> loadCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _catalogService.getAllTracks(),
        _catalogService.getAllAlbums(),
        _catalogService.getGenres().catchError((_) => <String>[]),
      ]);
      _tracks = results[0] as List<Track>;
      _albums = results[1] as List<Album>;
      _dbGenres = results[2] as List<String>;

      // Load like counts and play counts initialized from Track models
      for (var t in _tracks) {
        _likeCounts[t.id] = t.likesCount;
        _playCounts[t.id] = t.playsCount;
        _engagementService
            .getTrackLikesCount(t.id)
            .then((count) {
              _likeCounts[t.id] = count;
              notifyListeners();
            })
            .catchError((_) {});
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setGenre(String? genre) {
    _selectedGenre = (genre == 'All') ? null : genre;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> toggleLike(int trackId, int userId) async {
    final alreadyLiked = _likedTrackIds.contains(trackId);
    final currentCount = _likeCounts[trackId] ?? 0;

    // Optimistic update
    if (alreadyLiked) {
      _likedTrackIds.remove(trackId);
      _likeCounts[trackId] = currentCount > 0 ? currentCount - 1 : 0;
    } else {
      _likedTrackIds.add(trackId);
      _likeCounts[trackId] = currentCount + 1;
    }
    notifyListeners();

    try {
      if (alreadyLiked) {
        await _engagementService.unlikeTrack(trackId, userId);
      } else {
        await _engagementService.likeTrack(trackId, userId);
      }
    } catch (e) {
      // Revert on error
      if (alreadyLiked) {
        _likedTrackIds.add(trackId);
        _likeCounts[trackId] = currentCount;
      } else {
        _likedTrackIds.remove(trackId);
        _likeCounts[trackId] = currentCount;
      }
      notifyListeners();
    }
  }

  Future<void> loadComments(int trackId) async {
    try {
      final comments = await _engagementService.getComments(trackId);
      _trackComments[trackId] = comments;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> addComment(
    int trackId,
    int userId,
    String commentText, {
    int? parentCommentId,
  }) async {
    try {
      final comment = await _engagementService.addComment(
        trackId,
        userId,
        commentText,
        parentCommentId: parentCommentId,
      );
      final current = _trackComments[trackId] ?? [];
      _trackComments[trackId] = [comment, ...current];
      notifyListeners();
      // Reload in background to ensure canonical order and relations
      loadComments(trackId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateComment(int commentId, int trackId, int userId, String commentText) async {
    try {
      await _engagementService.updateComment(commentId, userId, commentText);
      await loadComments(trackId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteComment(int commentId, int trackId, int userId) async {
    try {
      await _engagementService.deleteComment(commentId, userId);
      await loadComments(trackId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> repostTrack(int trackId, int userId) async {
    try {
      await _engagementService.repostTrack(trackId, userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Track?> uploadTrack({
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
    _isLoading = true;
    notifyListeners();
    try {
      final track = await _catalogService.uploadTrack(
        artistId: artistId,
        albumId: albumId,
        title: title,
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
        videoPath: videoPath,
        videoBytes: videoBytes,
        videoName: videoName,
        mediaType: mediaType,
        coverArtPath: coverArtPath,
        coverArtBytes: coverArtBytes,
        coverArtName: coverArtName,
        genre: genre,
        price: price,
        artistName: artistName,
        features: features,
        durationSeconds: durationSeconds,
        isPromoted: isPromoted,
        uploadSource: uploadSource,
        uploaderUserId: uploaderUserId,
      );
      _tracks.insert(0, track);
      return track;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Track?> updateTrackCover({
    required int trackId,
    String? coverArtPath,
    List<int>? coverArtBytes,
    String? coverArtName,
  }) async {
    try {
      final updated = await _catalogService.updateTrackCover(
        trackId: trackId,
        coverArtPath: coverArtPath,
        coverArtBytes: coverArtBytes,
        coverArtName: coverArtName,
      );
      final idx = _tracks.indexWhere((t) => t.id == trackId);
      if (idx != -1) {
        _tracks[idx] = updated;
        notifyListeners();
      }
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Album?> createAlbum({
    required int artistId,
    required String title,
    String? coverArtUrl,
  }) async {
    try {
      final album = await _catalogService.createAlbum(
        artistId: artistId,
        title: title,
        coverArtUrl: coverArtUrl,
      );
      _albums.insert(0, album);
      notifyListeners();
      return album;
    } catch (e) {
      return null;
    }
  }
}
