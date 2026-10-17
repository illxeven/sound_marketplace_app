class Album {
  final int id;
  final int artistId;
  final String? artistEmail;
  final String title;
  final String? coverArtUrl;
  final bool? hasCoverImage;
  final DateTime? createdAt;

  Album({
    required this.id,
    required this.artistId,
    this.artistEmail,
    required this.title,
    this.coverArtUrl,
    this.hasCoverImage,
    this.createdAt,
  });

  String? get coverUrl => (hasCoverImage == true)
      ? '/albums/$id/cover'
      : coverArtUrl;

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as int,
      artistId: json['artistId'] as int? ?? 0,
      artistEmail: json['artistEmail'] as String?,
      title: json['title'] as String? ?? 'Untitled Album',
      coverArtUrl: json['coverArtUrl'] as String?,
      hasCoverImage: json['hasCoverImage'] as bool?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'artistId': artistId,
      'artistEmail': artistEmail,
      'title': title,
      'coverArtUrl': coverArtUrl,
      'hasCoverImage': hasCoverImage,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
