import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Service to persist and synchronize player state and play queue across devices.
class PlayerSyncService {
  Future<bool> _hasToken() async {
    final token = await TokenStore.readAccess();
    return token != null && token.isNotEmpty;
  }

  /// Saves player state (position, shuffle, repeat mode) to the server.
  Future<void> savePlayerState({
    int? currentPosition,
    int? positionMs,
    bool? shuffle,
    String? repeatMode,
  }) async {
    if (!await _hasToken()) return;
    try {
      await ApiClient.put(
        '/player/state',
        body: {
          if (currentPosition != null) 'currentPosition': currentPosition,
          if (positionMs != null) 'positionMs': positionMs,
          if (shuffle != null) 'shuffle': shuffle,
          if (repeatMode != null) 'repeatMode': repeatMode,
        },
      );
    } catch (e) {
      debugPrint('[player_sync] savePlayerState error: $e');
    }
  }

  /// Syncs entire queue to the server.
  Future<void> syncQueue(List<int> trackIds) async {
    if (!await _hasToken()) return;
    try {
      await ApiClient.post(
        '/queue',
        body: trackIds.map((id) => {'trackId': id, 'source': 'MANUAL'}).toList(),
      );
    } catch (e) {
      debugPrint('[player_sync] syncQueue error: $e');
    }
  }

  /// Adds a single track to the end of the server queue.
  Future<void> addToQueue(int trackId, {String? source, int? sourceId}) async {
    if (!await _hasToken()) return;
    try {
      await ApiClient.post(
        '/queue/add',
        body: {
          'trackId': trackId,
          if (source != null) 'source': source,
          if (sourceId != null) 'sourceId': sourceId,
        },
      );
    } catch (e) {
      debugPrint('[player_sync] addToQueue error: $e');
    }
  }

  /// Inserts a track right after the current playing position.
  Future<void> playNext(int trackId, {int? currentPosition, String? source, int? sourceId}) async {
    if (!await _hasToken()) return;
    try {
      await ApiClient.post(
        '/queue/play-next',
        queryParameters: currentPosition != null ? {'currentPosition': currentPosition} : null,
        body: {
          'trackId': trackId,
          if (source != null) 'source': source,
          if (sourceId != null) 'sourceId': sourceId,
        },
      );
    } catch (e) {
      debugPrint('[player_sync] playNext error: $e');
    }
  }

  /// Reorders items in the queue on the server.
  Future<void> moveInQueue(int from, int to) async {
    if (!await _hasToken()) return;
    try {
      await ApiClient.put(
        '/queue/move',
        body: {'fromPosition': from, 'toPosition': to},
      );
    } catch (e) {
      debugPrint('[player_sync] moveInQueue error: $e');
    }
  }

  /// Removes item at position from server queue.
  Future<void> removeFromQueue(int position) async {
    if (!await _hasToken()) return;
    try {
      await ApiClient.delete('/queue/$position');
    } catch (e) {
      debugPrint('[player_sync] removeFromQueue error: $e');
    }
  }

  /// Clears user queue on server.
  Future<void> clearQueue() async {
    if (!await _hasToken()) return;
    try {
      await ApiClient.delete('/queue');
    } catch (e) {
      debugPrint('[player_sync] clearQueue error: $e');
    }
  }
}
