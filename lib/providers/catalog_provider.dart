import 'package:flutter/foundation.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../models/track_comment.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import '../services/engagement_service.dart';

/// Tracks, beats, albums, likes and live play counts.
///
/// Lists load page by page from the server. Like and play counts come with each page (no
/// per-track requests), liked state comes from `/users/me/liked-track-ids`, and play counts
/// are replaced with the server's number every time the player reports a play.
class CatalogProvider extends ChangeNotifier {
  CatalogProvider({CatalogService? catalogService, EngagementService? engagementService})
      : _catalogService = catalogService ?? CatalogService(),
        _engagementService = engagementService ?? EngagementService();

  final CatalogService _catalogService;
  final EngagementService _engagementService;

  static const int _pageSize = 30;

  List<Track> _tracks = [];
  List<Track> _beats = [];
  List<Album> _albums = [];
  List<String> _dbGenres = [];
  String? _selectedGenre;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingBeats = false;
  bool _hasMore = true;
  int _nextPage = 0;
  String? _errorMessage;

  final Set<int> _likedTrackIds = {};
  final Map<int, int> _likeCounts = {};
  final Map<int, int> _playCounts = {};
  final Map<int, List<TrackComment>> _trackComments = {};

  List<Track> get allTracks => List.unmodifiable(_tracks);
  List<Track> get beats => List.unmodifiable(_beats);

  /// Tracks filtered by the selected genre and search text (title, artist, genre).
  List<Track> get tracks {
    final q = _searchQuery.trim().toLowerCase();
    return _tracks.where((t) {
      final matchesGenre = _selectedGenre == null ||
          _selectedGenre!.isEmpty ||
          _selectedGenre == 'All' ||
          (t.genre ?? '').toLowerCase() == _selectedGenre!.toLowerCase();
      final matchesSearch = q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          (t.artistName ?? '').toLowerCase().contains(q) ||
          (t.genre ?? '').toLowerCase().contains(q);
      return matchesGenre && matchesSearch;
    }).toList();
  }

  /// Most played first.
  List<Track> get trendingTracks {
    final sorted = List<Track>.from(_tracks)..sort((a, b) => getTrackPlays(b.id).compareTo(getTrackPlays(a.id)));
    return sorted.take(10).toList();
  }

  List<Album> get albums => _albums;
  String? get selectedGenre => _selectedGenre;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingBeats => _isLoadingBeats;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  bool isTrackLiked(int trackId) => _likedTrackIds.contains(trackId);
  int getTrackLikes(int trackId) => _likeCounts[trackId] ?? 0;
  int getTrackPlays(int trackId) => _playCounts[trackId] ?? 0;

  Track? trackById(int id) {
    for (final t in _tracks) {
      if (t.id == id) return t;
    }
    for (final t in _beats) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Sets the play count to the server's number (from the play-event response).
  void applyPlayCount(int trackId, int playCount) {
    if (_playCounts[trackId] == playCount) return;
    _playCounts[trackId] = playCount;
    notifyListeners();
  }

  /// Kept for older callers: optimistic +1 when no server count is available.
  void incrementTrackPlays(int trackId) => applyPlayCount(trackId, getTrackPlays(trackId) + 1);

  List<TrackComment> getCommentsForTrack(int trackId) => _trackComments[trackId] ?? [];

  List<String> get availableGenres {
    final set = <String>{'All', ..._dbGenres};
    for (final t in _tracks) {
      if (t.genre != null && t.genre!.isNotEmpty) set.add(t.genre!);
    }
    return set.toList();
  }

  void _absorbCounts(Iterable<Track> tracks) {
    for (final t in tracks) {
      _likeCounts[t.id] = t.likesCount;
      // Keep a newer live count if the player already updated it.
      _playCounts[t.id] = t.playsCount > (_playCounts[t.id] ?? 0) ? t.playsCount : (_playCounts[t.id] ?? t.playsCount);
    }
  }

  /// First page of tracks plus albums, genres and (when signed in) liked tracks.
  Future<void> loadCatalog({bool signedIn = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await _catalogService.getTracksPage(page: 0, size: _pageSize);
      _tracks = page.items;
      _nextPage = 1;
      _hasMore = page.hasNext;
      _absorbCounts(_tracks);

      // Secondary data: a failure here shouldn't hide the tracks.
      final results = await Future.wait([
        _catalogService.getAllAlbums().catchError((Object e) {
          debugPrint('[catalog] albums failed: $e');
          return <Album>[];
        }),
        _catalogService.getGenres().catchError((Object e) {
          debugPrint('[catalog] genres failed: $e');
          return <String>[];
        }),
        if (signedIn)
          _engagementService.getLikedTrackIds().catchError((Object e) {
            debugPrint('[catalog] liked ids failed: $e');
            return <int>{};
          }),
      ]);
      _albums = results[0] as List<Album>;
      _dbGenres = results[1] as List<String>;
      if (signedIn) {
        _likedTrackIds
          ..clear()
          ..addAll(results[2] as Set<int>);
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Next page for infinite scroll. Safe to call repeatedly.
  Future<void> loadMoreTracks() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _catalogService.getTracksPage(page: _nextPage, size: _pageSize);
      final known = _tracks.map((t) => t.id).toSet();
      final fresh = page.items.where((t) => !known.contains(t.id)).toList();
      _tracks.addAll(fresh);
      _absorbCounts(fresh);
      _nextPage++;
      _hasMore = page.hasNext;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadBeats({String? genre, String? search}) async {
    _isLoadingBeats = true;
    notifyListeners();
    try {
      _beats = await _catalogService.getBeats(genre: genre, search: search);
      // Beat listings carry no counts; use what the catalog already knows.
      for (final b in _beats) {
        final known = _tracks.where((t) => t.id == b.id);
        if (known.isNotEmpty) {
          _playCounts.putIfAbsent(b.id, () => known.first.playsCount);
          _likeCounts.putIfAbsent(b.id, () => known.first.likesCount);
        }
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoadingBeats = false;
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

  /// Optimistic like/unlike with rollback if the server call fails.
  Future<void> toggleLike(int trackId, [int? userId]) async {
    final alreadyLiked = _likedTrackIds.contains(trackId);
    final currentCount = _likeCounts[trackId] ?? 0;

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
        await _engagementService.unlikeTrack(trackId);
      } else {
        await _engagementService.likeTrack(trackId);
      }
    } on ApiException catch (e) {
      debugPrint('[catalog] like toggle failed trackId=$trackId: ${e.message}');
      if (alreadyLiked) {
        _likedTrackIds.add(trackId);
      } else {
        _likedTrackIds.remove(trackId);
      }
      _likeCounts[trackId] = currentCount;
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Clears per-user state on sign-out.
  void reset() {
    _likedTrackIds.clear();
    _trackComments.clear();
    _searchQuery = '';
    _selectedGenre = null;
    notifyListeners();
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
