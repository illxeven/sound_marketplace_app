import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../config/api_config.dart';
import '../models/track.dart';
import '../services/api_client.dart';
import '../services/engagement_service.dart';
import '../services/playback_service.dart';

/// Repeat setting shown in the UI.
enum RepeatMode { off, all, one }

/// Music player: queue, background playback, lock-screen controls and live play counts.
///
/// Built on just_audio (the same engine as the Bloomee player): the whole queue is one
/// playlist source, so the next track is prepared ahead of time and starts without a gap.
/// Position updates are exposed as streams; the provider only notifies listeners when the
/// track, play state, queue or modes change, so the UI isn't rebuilt several times a second.
class AudioPlayerProvider extends ChangeNotifier {
  AudioPlayerProvider({
    AudioPlayer? player,
    EngagementService? engagementService,
    PlaybackService? playbackService,
  })  : _player = player ?? AudioPlayer(),
        _engagement = engagementService ?? EngagementService(),
        _playback = playbackService ?? PlaybackService() {
    _subscriptions.addAll([
      _player.playerStateStream.listen(_onPlayerState),
      _player.currentIndexStream.listen(_onIndexChanged),
      _player.positionStream.listen(_detectRestart),
      _player.playbackEventStream.listen((_) {}, onError: _onPlaybackError),
    ]);
    _configureSession();
  }

  final AudioPlayer _player;
  final EngagementService _engagement;
  final PlaybackService _playback;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  ConcatenatingAudioSource? _playlist;
  final List<Track> _queue = [];
  final Map<int, PlayUrl> _urls = {};

  int? _lastIndex;
  Duration _lastPosition = Duration.zero;
  bool _wasPlaying = false;
  ProcessingState _processingState = ProcessingState.idle;
  String? _errorMessage;

  /// Called with the server's new total after each counted play (wire to CatalogProvider).
  void Function(int trackId, int playCount)? onPlayCount;

  /// Kept for older callers; fires whenever a play is reported.
  void Function(int trackId)? onTrackPlayed;

  // ---------------------------------------------------------------------------
  // State for the UI
  // ---------------------------------------------------------------------------

  List<Track> get queue => List.unmodifiable(_queue);
  int? get currentIndex => _player.currentIndex;

  Track? get currentTrack {
    final i = _player.currentIndex;
    return (i == null || i < 0 || i >= _queue.length) ? null : _queue[i];
  }

  bool get isPlaying => _player.playing && _processingState != ProcessingState.completed;
  bool get isBuffering =>
      _processingState == ProcessingState.loading || _processingState == ProcessingState.buffering;
  String? get errorMessage => _errorMessage;

  /// Snapshot values; for a moving seek bar use [positionStream] / [bufferedPositionStream].
  Duration get position => _player.position;
  Duration get duration =>
      _player.duration ??
      (currentTrack?.durationSeconds != null ? Duration(seconds: currentTrack!.durationSeconds!) : Duration.zero);
  double get progress =>
      duration.inMilliseconds > 0 ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0) : 0.0;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get shuffleEnabled => _player.shuffleModeEnabled;

  RepeatMode get repeatMode {
    switch (_player.loopMode) {
      case LoopMode.one:
        return RepeatMode.one;
      case LoopMode.all:
        return RepeatMode.all;
      case LoopMode.off:
        return RepeatMode.off;
    }
  }

  bool get isLooping => repeatMode == RepeatMode.one;

  /// True when the current track plays a 30-second preview (paid and not bought).
  bool isPreview(int trackId) => _urls[trackId]?.isPreview ?? false;

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  Future<void> _configureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      // Pause when headphones are unplugged.
      _subscriptions.add(session.becomingNoisyEventStream.listen((_) => _player.pause()));
    } on Exception catch (e) {
      debugPrint('[player] audio session setup failed: $e');
    }
  }

  /// Plays [track]. With [playlistQueue] the whole list becomes the queue, starting at [track].
  /// Tapping the current track toggles play/pause. [userId] is no longer needed (kept for callers).
  Future<void> playTrack(Track track, {List<Track>? playlistQueue, int? userId}) async {
    if (currentTrack?.id == track.id) {
      await togglePlayPause();
      return;
    }
    final tracks = (playlistQueue != null && playlistQueue.isNotEmpty) ? playlistQueue : [track];
    var start = tracks.indexWhere((t) => t.id == track.id);
    if (start < 0) start = 0;
    await playQueue(tracks, startIndex: start);
  }

  /// Replaces the queue and starts playing at [startIndex].
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _errorMessage = null;
    try {
      final urls = await _playback.getPlayUrls(tracks.map((t) => t.id).toList());
      _urls.addAll(urls);
      final playable = tracks.where((t) => urls.containsKey(t.id)).toList();
      if (playable.isEmpty) {
        _errorMessage = 'These tracks are not available to play right now.';
        notifyListeners();
        return;
      }
      final startId = tracks[startIndex.clamp(0, tracks.length - 1)].id;
      final start = playable.indexWhere((t) => t.id == startId).clamp(0, playable.length - 1);

      _queue
        ..clear()
        ..addAll(playable);
      _playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: playable.map(_sourceFor).toList(),
      );
      _lastIndex = null; // the index listener reports the first play
      await _player.setAudioSource(_playlist!, initialIndex: start, initialPosition: Duration.zero);
      notifyListeners();
      unawaited(_player.play());
      debugPrint('[player] queue set size=${playable.length} start=$start trackId=${playable[start].id}');
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } on PlayerException catch (e) {
      _errorMessage = "This track couldn't be played (${e.message ?? 'player error'}).";
      debugPrint('[player] setAudioSource failed code=${e.code} message=${e.message}');
      notifyListeners();
    }
  }

  AudioSource _sourceFor(Track t) {
    final signed = _urls[t.id]!;
    return AudioSource.uri(
      Uri.parse(ApiConfig.resolve(signed.url)),
      tag: MediaItem(
        id: '${t.id}',
        title: signed.isPreview ? '${t.title} (preview)' : t.title,
        artist: t.artistDisplay,
        album: t.albumTitle,
        artUri: t.coverImageFullUrl != null ? Uri.parse(t.coverImageFullUrl!) : null,
        duration: t.durationSeconds != null ? Duration(seconds: t.durationSeconds!) : null,
      ),
    );
  }

  Future<void> togglePlayPause() async {
    if (_queue.isEmpty) return;
    if (_player.playing && _processingState != ProcessingState.completed) {
      await _player.pause();
      return;
    }
    if (_processingState == ProcessingState.completed) {
      // Finished: starting again counts as a new play.
      await _player.seek(Duration.zero, index: _player.currentIndex);
      _reportPlay(currentTrack);
    }
    unawaited(_player.play());
  }

  Future<void> seek(Duration position) async {
    final max = duration;
    final target = position < Duration.zero ? Duration.zero : (max > Duration.zero && position > max ? max : position);
    await _player.seek(target);
  }

  Future<void> next() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_queue.isNotEmpty && repeatMode == RepeatMode.off) {
      await _player.seek(Duration.zero, index: 0);
    }
    if (!_player.playing) unawaited(_player.play());
  }

  /// Restarts the current track after 3 seconds, otherwise goes to the previous one.
  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await replayTrack();
      return;
    }
    await _player.seekToPrevious();
  }

  /// Starts the current track over and counts it as a new play.
  Future<void> replayTrack() async {
    if (currentTrack == null) return;
    await _player.seek(Duration.zero);
    _reportPlay(currentTrack);
    if (!_player.playing) unawaited(_player.play());
  }

  /// Cycles repeat: off -> all -> one -> off.
  Future<void> cycleRepeat() async {
    const order = [LoopMode.off, LoopMode.all, LoopMode.one];
    await _player.setLoopMode(order[(order.indexOf(_player.loopMode) + 1) % order.length]);
    notifyListeners();
  }

  /// Kept for older callers: toggles "repeat one".
  Future<void> toggleLoop() async {
    await _player.setLoopMode(_player.loopMode == LoopMode.one ? LoopMode.off : LoopMode.one);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    final enable = !_player.shuffleModeEnabled;
    if (enable) await _player.shuffle();
    await _player.setShuffleModeEnabled(enable);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Queue editing (from the Now Playing screen)
  // ---------------------------------------------------------------------------

  Future<bool> _ensureUrl(Track t) async {
    final existing = _urls[t.id];
    if (existing != null && !existing.expiresWithin(const Duration(minutes: 10))) return true;
    try {
      _urls.addAll(await _playback.getPlayUrls([t.id]));
      return _urls.containsKey(t.id);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Plays [track] right after the current one.
  Future<void> playNext(Track track) async {
    if (_playlist == null || _queue.isEmpty) {
      await playQueue([track]);
      return;
    }
    if (!await _ensureUrl(track)) return;
    final at = (_player.currentIndex ?? -1) + 1;
    _queue.insert(at, track);
    await _playlist!.insert(at, _sourceFor(track));
    notifyListeners();
  }

  /// Adds [track] to the end of the queue.
  Future<void> addToQueue(Track track) async {
    if (_playlist == null || _queue.isEmpty) {
      await playQueue([track]);
      return;
    }
    if (!await _ensureUrl(track)) return;
    _queue.add(track);
    await _playlist!.add(_sourceFor(track));
    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    if (_playlist == null || index < 0 || index >= _queue.length) return;
    if (index == _player.currentIndex && _queue.length == 1) {
      await stop();
      return;
    }
    _queue.removeAt(index);
    await _playlist!.removeAt(index);
    notifyListeners();
  }

  Future<void> moveInQueue(int from, int to) async {
    if (_playlist == null || from == to || from < 0 || from >= _queue.length) return;
    final target = to.clamp(0, _queue.length - 1);
    final track = _queue.removeAt(from);
    _queue.insert(target, track);
    await _playlist!.move(from, target);
    notifyListeners();
  }

  /// Jumps to a track already in the queue.
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) unawaited(_player.play());
  }

  Future<void> stop() async {
    await _player.stop();
    _queue.clear();
    _playlist = null;
    _lastIndex = null;
    notifyListeners();
  }

  /// Sign-out: stop and forget the queue.
  void reset() => unawaited(stop());

  // ---------------------------------------------------------------------------
  // Play counting
  // ---------------------------------------------------------------------------

  void _onPlayerState(PlayerState state) {
    final changed = state.playing != _wasPlaying || state.processingState != _processingState;
    _wasPlaying = state.playing;
    _processingState = state.processingState;
    if (changed) notifyListeners();
  }

  void _onIndexChanged(int? index) {
    if (index == null || index == _lastIndex) return;
    _lastIndex = index;
    _lastPosition = Duration.zero;
    if (index >= 0 && index < _queue.length) _reportPlay(_queue[index]);
    unawaited(_refreshUpcomingUrl(index + 1));
    notifyListeners();
  }

  /// Repeat-one and "repeat all" with a single track loop back to 0 without changing index;
  /// treat a jump from near the end to the start as a replay.
  void _detectRestart(Duration position) {
    final d = _player.duration;
    final wasNearEnd = d != null && d > Duration.zero && _lastPosition >= d - const Duration(seconds: 2);
    if (wasNearEnd && position < const Duration(seconds: 2) && _player.currentIndex == _lastIndex) {
      _reportPlay(currentTrack);
    }
    _lastPosition = position;
  }

  void _reportPlay(Track? track) {
    if (track == null) return;
    onTrackPlayed?.call(track.id);
    unawaited(_engagement.recordPlayEvent(track.id).then((result) {
      if (result.playCount != null) onPlayCount?.call(track.id, result.playCount!);
      debugPrint('[player] play reported trackId=${track.id} counted=${result.counted} total=${result.playCount}');
    }));
  }

  /// Signed URLs last 2 hours; refresh the next track's URL if it's about to expire.
  Future<void> _refreshUpcomingUrl(int index) async {
    if (_playlist == null || index < 0 || index >= _queue.length) return;
    final t = _queue[index];
    final signed = _urls[t.id];
    if (signed != null && !signed.expiresWithin(const Duration(minutes: 15))) return;
    if (!await _ensureUrl(t)) return;
    if (index < _playlist!.length && _queue.length > index && _queue[index].id == t.id) {
      await _playlist!.removeAt(index);
      await _playlist!.insert(index, _sourceFor(t));
      debugPrint('[player] refreshed signed URL trackId=${t.id}');
    }
  }

  void _onPlaybackError(Object error, StackTrace stack) {
    final track = currentTrack;
    _errorMessage = "Couldn't play ${track?.title ?? 'this track'}. Skipping to the next one.";
    debugPrint('[player] playback error trackId=${track?.id}: $error');
    notifyListeners();
    if (_player.hasNext) unawaited(_player.seekToNext());
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
