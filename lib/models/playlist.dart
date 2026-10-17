import 'track.dart';

class Playlist {
  final int id;
  final int userId;
  final String? userEmail;
  final String title;
  final bool isPublic;
  final List<Track> tracks;
  final DateTime? createdAt;

  Playlist({
    required this.id,
    required this.userId,
    this.userEmail,
    required this.title,
    this.isPublic = true,
    this.tracks = const [],
    this.createdAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var rawTracks = json['tracks'] as List<dynamic>? ?? [];
    List<Track> parsedTracks = rawTracks
        .map((t) => Track.fromJson(t as Map<String, dynamic>))
        .toList();

    return Playlist(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? 0,
      userEmail: json['userEmail'] as String?,
      title: json['title'] as String? ?? 'Untitled Playlist',
      isPublic: json['isPublic'] as bool? ?? true,
      tracks: parsedTracks,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'title': title,
      'isPublic': isPublic,
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
