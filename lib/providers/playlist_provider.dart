import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';

class PlaylistProvider extends ChangeNotifier {
  final PlaylistService _playlistService = PlaylistService();

  List<Playlist> _publicPlaylists = [];
  List<Playlist> _userPlaylists = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Playlist> get publicPlaylists => _publicPlaylists;
  List<Playlist> get userPlaylists => _userPlaylists;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadPlaylists(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _playlistService.getPublicPlaylists(),
        _playlistService.getUserPlaylists(userId),
      ]);
      _publicPlaylists = results[0];
      _userPlaylists = results[1];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Playlist?> createPlaylist({
    required int userId,
    required String title,
    bool isPublic = true,
    List<int> trackIds = const [],
  }) async {
    try {
      final playlist = await _playlistService.createPlaylist(
        userId: userId,
        title: title,
        isPublic: isPublic,
        trackIds: trackIds,
      );
      _userPlaylists.insert(0, playlist);
      if (isPublic) {
        _publicPlaylists.insert(0, playlist);
      }
      notifyListeners();
      return playlist;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> addTrackToPlaylist(int playlistId, int trackId) async {
    try {
      final updated = await _playlistService.addTrackToPlaylist(playlistId, trackId);
      final idxPublic = _publicPlaylists.indexWhere((p) => p.id == playlistId);
      if (idxPublic != -1) _publicPlaylists[idxPublic] = updated;

      final idxUser = _userPlaylists.indexWhere((p) => p.id == playlistId);
      if (idxUser != -1) _userPlaylists[idxUser] = updated;

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
