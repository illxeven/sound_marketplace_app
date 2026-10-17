import 'dart:convert';
import 'dart:typed_data';
import '../config/api_config.dart';

class Track {
  final int id;
  final int artistId;
  final String? artistEmail;
  final String? artistName;
  final String? features;
  final int? albumId;
  final String? albumTitle;
  final String title;
  final String? filePath;
  final String? genre;
  final int? durationSeconds;
  final bool isPromoted;
  final double price;
  final bool? hasCoverImage;
  final String? coverImageUrl;
  final Uint8List? coverImageBlob;
  final int likesCount;
  final int playsCount;
  final String? videoFilePath;
  final Uint8List? videoBlob;
  final String mediaType;
  final DateTime? createdAt;

  Track({
    required this.id,
    required this.artistId,
    this.artistEmail,
    this.artistName,
    this.features,
    this.albumId,
    this.albumTitle,
    required this.title,
    this.filePath,
    this.genre,
    this.durationSeconds,
    this.isPromoted = false,
    this.price = 0.0,
    this.hasCoverImage,
    this.coverImageUrl,
    this.coverImageBlob,
    this.likesCount = 0,
    this.playsCount = 0,
    this.videoFilePath,
    this.videoBlob,
    this.mediaType = 'AUDIO',
    this.createdAt,
  });

  bool get isVideo => mediaType.toUpperCase() == 'VIDEO' || (videoFilePath != null && videoFilePath!.isNotEmpty) || videoBlob != null;

  bool get isFree => price <= 0.0;

  String? get coverUrl => (hasCoverImage == true)
      ? (coverImageUrl ?? '/tracks/$id/cover')
      : coverImageUrl;

  String get streamUrl {
    if (filePath != null &&
        (filePath!.startsWith('http://') || filePath!.startsWith('https://'))) {
      return filePath!;
    }
    String base = ApiConfig.baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return '$base/tracks/$id/stream';
  }

  String get artistDisplay {
    if (artistName != null && artistName!.trim().isNotEmpty) {
      if (features != null && features!.trim().isNotEmpty) {
        return '${artistName!} feat. ${features!}';
      }
      return artistName!;
    }
    if (artistEmail != null && artistEmail!.isNotEmpty) {
      return artistEmail!.split('@').first;
    }
    return 'Artist #$artistId';
  }

  /// Clean artist name and features display (e.g. "R3iin (Reiin), K.F.M.")
  String get artistAndFeaturesDisplay {
    final base = (artistName != null && artistName!.trim().isNotEmpty)
        ? artistName!.trim()
        : ((artistEmail != null && artistEmail!.isNotEmpty)
            ? artistEmail!.split('@').first
            : 'Artist #$artistId');

    if (features != null && features!.trim().isNotEmpty) {
      final feat = features!.trim();
      // If features doesn't already start with "feat" or similar
      if (feat.toLowerCase().startsWith('feat') || feat.toLowerCase().startsWith('with')) {
        return '$base $feat';
      }
      return '$base, $feat';
    }
    return base;
  }

  static Uint8List? _parseBlob(dynamic val) {
    if (val == null) return null;
    if (val is Uint8List) return val;
    if (val is List<int>) return Uint8List.fromList(val);
    if (val is List) {
      try {
        return Uint8List.fromList(val.map((e) => (e as num).toInt()).toList());
      } catch (_) {}
    }
    if (val is String && val.isNotEmpty) {
      try {
        String clean = val;
        if (clean.contains(',')) {
          clean = clean.split(',').last;
        }
        return base64Decode(clean);
      } catch (_) {}
    }
    return null;
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as int,
      artistId: json['artistId'] as int? ?? 0,
      artistEmail: json['artistEmail'] as String?,
      artistName: json['artistName'] as String?,
      features: json['features'] as String?,
      albumId: json['albumId'] as int?,
      albumTitle: json['albumTitle'] as String?,
      title: json['title'] as String? ?? 'Untitled Track',
      filePath: json['filePath'] as String?,
      genre: json['genre'] as String? ?? 'Electronic',
      durationSeconds: json['durationSeconds'] as int?,
      isPromoted: json['isPromoted'] as bool? ?? false,
      price: (json['price'] != null) ? (json['price'] as num).toDouble() : 0.0,
      hasCoverImage: json['hasCoverImage'] as bool?,
      coverImageUrl: json['coverImageUrl'] as String?,
      coverImageBlob: _parseBlob(json['cover_image_blob'] ?? json['coverImageBlob']),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      playsCount: (json['playsCount'] as num?)?.toInt() ?? 0,
      videoFilePath: json['videoFilePath'] as String?,
      videoBlob: _parseBlob(json['video_blob'] ?? json['videoBlob']),
      mediaType: json['mediaType'] as String? ?? 'AUDIO',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Track copyWith({
    int? id,
    int? artistId,
    String? artistEmail,
    String? artistName,
    String? features,
    int? albumId,
    String? albumTitle,
    String? title,
    String? filePath,
    String? genre,
    int? durationSeconds,
    bool? isPromoted,
    double? price,
    bool? hasCoverImage,
    String? coverImageUrl,
    Uint8List? coverImageBlob,
    int? likesCount,
    int? playsCount,
    String? videoFilePath,
    Uint8List? videoBlob,
    String? mediaType,
    DateTime? createdAt,
  }) {
    return Track(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      artistEmail: artistEmail ?? this.artistEmail,
      artistName: artistName ?? this.artistName,
      features: features ?? this.features,
      albumId: albumId ?? this.albumId,
      albumTitle: albumTitle ?? this.albumTitle,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      genre: genre ?? this.genre,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isPromoted: isPromoted ?? this.isPromoted,
      price: price ?? this.price,
      hasCoverImage: hasCoverImage ?? this.hasCoverImage,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      coverImageBlob: coverImageBlob ?? this.coverImageBlob,
      likesCount: likesCount ?? this.likesCount,
      playsCount: playsCount ?? this.playsCount,
      videoFilePath: videoFilePath ?? this.videoFilePath,
      videoBlob: videoBlob ?? this.videoBlob,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'artistId': artistId,
      'artistEmail': artistEmail,
      'artistName': artistName,
      'features': features,
      'albumId': albumId,
      'albumTitle': albumTitle,
      'title': title,
      'filePath': filePath,
      'genre': genre,
      'durationSeconds': durationSeconds,
      'isPromoted': isPromoted,
      'price': price,
      'hasCoverImage': hasCoverImage,
      'coverImageUrl': coverImageUrl,
      'coverImageBlob': coverImageBlob != null ? base64Encode(coverImageBlob!) : null,
      'likesCount': likesCount,
      'playsCount': playsCount,
      'videoFilePath': videoFilePath,
      'videoBlob': videoBlob != null ? base64Encode(videoBlob!) : null,
      'mediaType': mediaType,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
