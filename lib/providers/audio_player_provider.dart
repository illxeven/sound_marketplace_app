import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/engagement_service.dart';

class AudioPlayerProvider extends ChangeNotifier {
  final EngagementService _engagementService = EngagementService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLooping = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;
  int? _activeUserId;
  void Function(int trackId)? onTrackPlayed;

  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _playerCompleteSub;

  AudioPlayerProvider() {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (d > Duration.zero) {
        _duration = d;
        notifyListeners();
      }
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (_currentTrack != null) {
        // Trigger play count increment on track completion/replay
        _engagementService.recordPlayback(_currentTrack!.id, _activeUserId).catchError((_) {});
        onTrackPlayed?.call(_currentTrack!.id);
      }
      if (_isLooping && _currentTrack != null) {
        replayTrack();
      } else {
        _isPlaying = false;
        _position = Duration.zero;
        notifyListeners();
        next();
      }
    });
  }

  bool get isLooping => _isLooping;
  void toggleLoop() {
    _isLooping = !_isLooping;
    notifyListeners();
  }

  Future<void> replayTrack() async {
    if (_currentTrack == null) return;
    _position = Duration.zero;
    _isPlaying = true;
    notifyListeners();
    // Record replay play count
    _engagementService.recordPlayback(_currentTrack!.id, _activeUserId).catchError((_) {});
    onTrackPlayed?.call(_currentTrack!.id);
    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.resume();
    } catch (_) {
      try {
        await _audioPlayer.play(UrlSource(_currentTrack!.streamUrl));
      } catch (_) {}
    }
  }

  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get errorMessage => _errorMessage;

  double get progress => _duration.inMilliseconds > 0
      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  Future<void> playTrack(Track track, {List<Track>? playlistQueue, int? userId}) async {
    _errorMessage = null;
    _activeUserId = userId;

    if (_currentTrack?.id == track.id) {
      await togglePlayPause();
      return;
    }

    _currentTrack = track;
    if (playlistQueue != null && playlistQueue.isNotEmpty) {
      _queue = playlistQueue;
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
    } else {
      _queue = [track];
      _currentIndex = 0;
    }

    _position = Duration.zero;
    if (track.durationSeconds != null && track.durationSeconds! > 0) {
      _duration = Duration(seconds: track.durationSeconds!);
    } else {
      _duration = const Duration(minutes: 3);
    }
    _isPlaying = true;
    notifyListeners();

    // Record playback on backend and notify local listeners
    _engagementService.recordPlayback(track.id, userId).catchError((_) {});
    onTrackPlayed?.call(track.id);

    final url = track.streamUrl;
    debugPrint('AudioPlayer: Streaming audio from: $url');

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('AudioPlayer error playing $url: $e');
      _errorMessage = 'Playback error: $e';
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_currentTrack == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_position > Duration.zero) {
          await _audioPlayer.resume();
        } else {
          await _audioPlayer.play(UrlSource(_currentTrack!.streamUrl));
        }
      }
    } catch (e) {
      debugPrint('AudioPlayer togglePlayPause error: $e');
      try {
        await _audioPlayer.play(UrlSource(_currentTrack!.streamUrl));
      } catch (_) {}
    }
  }

  Future<void> seek(Duration newPosition) async {
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (_duration > Duration.zero && newPosition > _duration) newPosition = _duration;
    _position = newPosition;
    notifyListeners();
    try {
      await _audioPlayer.seek(newPosition);
    } catch (e) {
      debugPrint('AudioPlayer seek error: $e');
    }
  }

  void next() {
    if (_queue.isEmpty || _currentIndex == -1) return;
    int nextIdx = (_currentIndex + 1) % _queue.length;
    playTrack(_queue[nextIdx], playlistQueue: _queue);
  }

  void previous() {
    if (_queue.isEmpty || _currentIndex == -1) return;
    int prevIdx = (_currentIndex - 1 + _queue.length) % _queue.length;
    playTrack(_queue[prevIdx], playlistQueue: _queue);
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _isPlaying = false;
    _position = Duration.zero;
    _currentTrack = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _playerCompleteSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
