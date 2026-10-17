class UserReview {
  final int id;
  final int reviewerId;
  final String? reviewerEmail;
  final String? reviewerName;
  final int targetUserId;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  UserReview({
    required this.id,
    required this.reviewerId,
    this.reviewerEmail,
    this.reviewerName,
    required this.targetUserId,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  String get reviewerDisplay {
    if (reviewerName != null && reviewerName!.trim().isNotEmpty) {
      return reviewerName!.trim();
    }
    if (reviewerEmail != null && reviewerEmail!.isNotEmpty) {
      return reviewerEmail!.split('@').first;
    }
    return 'User #$reviewerId';
  }

  factory UserReview.fromJson(Map<String, dynamic> json) {
    return UserReview(
      id: (json['id'] as num).toInt(),
      reviewerId: (json['reviewerId'] as num).toInt(),
      reviewerEmail: json['reviewerEmail'] as String?,
      reviewerName: json['reviewerName'] as String?,
      targetUserId: (json['targetUserId'] as num).toInt(),
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reviewerId': reviewerId,
      'reviewerEmail': reviewerEmail,
      'reviewerName': reviewerName,
      'targetUserId': targetUserId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
