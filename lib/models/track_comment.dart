class TrackComment {
  final int id;
  final int? userId;
  final int? trackId;
  final String commentText;
  final int? parentCommentId;
  final String? userDisplayName;
  final DateTime? createdAt;

  TrackComment({
    required this.id,
    this.userId,
    this.trackId,
    required this.commentText,
    this.parentCommentId,
    this.userDisplayName,
    this.createdAt,
  });

  factory TrackComment.fromJson(Map<String, dynamic> json) {
    return TrackComment(
      id: json['id'] as int,
      userId: json['userId'] as int?,
      trackId: json['trackId'] as int?,
      commentText: json['commentText'] as String? ?? '',
      parentCommentId: json['parentCommentId'] as int?,
      userDisplayName: json['userDisplayName'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'trackId': trackId,
      'commentText': commentText,
      'parentCommentId': parentCommentId,
      'userDisplayName': userDisplayName,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  bool get isReply => parentCommentId != null;
}
