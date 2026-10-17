class MerchandiseReview {
  final int id;
  final int merchandiseId;
  final int userId;
  final String? userEmail;
  final String userDisplayName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  MerchandiseReview({
    required this.id,
    required this.merchandiseId,
    required this.userId,
    this.userEmail,
    required this.userDisplayName,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory MerchandiseReview.fromJson(Map<String, dynamic> json) {
    return MerchandiseReview(
      id: (json['id'] as num).toInt(),
      merchandiseId: (json['merchandiseId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      userEmail: json['userEmail'] as String?,
      userDisplayName: json['userDisplayName'] as String? ?? 'Music Fan',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchandiseId': merchandiseId,
      'userId': userId,
      'userEmail': userEmail,
      'userDisplayName': userDisplayName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
