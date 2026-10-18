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

  /// Server path of the cover image (`/api/tracks/{id}/cover`); turn into a URL with
  /// [coverImageFullUrl] or `ApiConfig.resolve`.
  String? get coverUrl => coverImageUrl ?? (hasCoverImage == true ? '/api/tracks/$id/cover' : null);

  /// Absolute cover URL, or null when the track has no artwork.
  String? get coverImageFullUrl => ApiConfig.resolveOrNull(coverUrl);

  bool get isBeat =>
      (genre ?? '').toLowerCase().contains('beat') || title.toLowerCase().contains('beat');

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

  /// Parses both the v2 list shape (TrackSummaryDTO: playCount, likeCount, coverUrl) and the
  /// detail/legacy shape (playsCount, likesCount, coverImageUrl). Image and video bytes are never
  /// read from JSON: covers load from their URL, which is cached and much smaller.
  factory Track.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
    return Track(
      id: toInt(json['id']),
      artistId: toInt(json['artistId']),
      artistEmail: json['artistEmail'] as String?,
      artistName: json['artistName'] as String?,
      features: json['features'] as String?,
      albumId: json['albumId'] is num ? (json['albumId'] as num).toInt() : null,
      albumTitle: json['albumTitle'] as String?,
      title: json['title'] as String? ?? 'Untitled Track',
      filePath: json['filePath'] as String?,
      genre: json['genre'] as String?,
      durationSeconds: json['durationSeconds'] is num ? (json['durationSeconds'] as num).toInt() : null,
      isPromoted: json['isPromoted'] as bool? ?? false,
      price: json['price'] is num ? (json['price'] as num).toDouble() : double.tryParse('${json['price'] ?? 0}') ?? 0.0,
      hasCoverImage: json['hasCoverImage'] as bool? ?? (json['coverUrl'] != null || json['coverImageUrl'] != null),
      coverImageUrl: (json['coverUrl'] ?? json['coverImageUrl'] ?? json['coverArtUrl']) as String?,
      likesCount: toInt(json['likeCount'] ?? json['likesCount']),
      playsCount: toInt(json['playCount'] ?? json['playsCount']),
      videoFilePath: json['videoFilePath'] as String?,
      mediaType: json['mediaType'] as String? ?? 'AUDIO',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  /// A beat listing from `/api/marketplace/items?category=beats` (MarketplaceItemDTO).
  factory Track.fromMarketplaceItem(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
    return Track(
      id: toInt(json['id']),
      artistId: toInt(json['sellerId']),
      artistName: json['sellerName'] as String?,
      title: json['title'] as String? ?? 'Untitled Beat',
      genre: json['genre'] as String?,
      price: json['price'] is num ? (json['price'] as num).toDouble() : double.tryParse('${json['price'] ?? 0}') ?? 0.0,
      coverImageUrl: json['coverArtUrl'] as String?,
      hasCoverImage: json['coverArtUrl'] != null,
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
      'likesCount': likesCount,
      'playsCount': playsCount,
      'videoFilePath': videoFilePath,
      'mediaType': mediaType,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
