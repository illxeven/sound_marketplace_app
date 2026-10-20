class UserAccount {
  final int id;
  final String email;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final bool? hasAvatarImage;
  final String? country;
  final List<String> roles;
  final bool isActive;
  final bool isEmailVerified;
  final DateTime? createdAt;

  UserAccount({
    required this.id,
    required this.email,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.hasAvatarImage,
    this.country,
    this.roles = const [],
    this.isActive = true,
    this.isEmailVerified = false,
    this.createdAt,
  });

  String get effectiveName =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : email.split('@').first;

  String? get avatarUrlComputed => (hasAvatarImage == true)
      ? '/users/$id/avatar'
      : avatarUrl;

  bool get isArtistOrProducer {
    if (roles.isEmpty) return false;
    return roles.any((r) {
      final clean = r.toLowerCase().replaceAll('_', '');
      return clean.contains('artist') ||
          clean.contains('producer') ||
          clean.contains('admin');
    });
  }

  bool get isArtist {
    if (roles.isEmpty) return false;
    return roles.any((r) {
      final clean = r.toLowerCase().replaceAll('_', '');
      return clean.contains('artist') || clean.contains('admin');
    });
  }

  bool get canUploadMerchandise => isArtistOrProducer;

  bool get canUploadTracks => isArtistOrProducer;

  bool get isConsumer => !isArtistOrProducer;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    List<String> parsedRoles = [];
    if (json['roles'] is List) {
      parsedRoles = (json['roles'] as List).map((r) => r.toString()).toList();
    }

    bool parseBool(dynamic val, bool fallback) {
      if (val == null) return fallback;
      if (val is bool) return val;
      if (val is num) return val == 1;
      if (val is String) return val.toLowerCase() == 'true' || val == '1';
      return fallback;
    }

    int parseId(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return UserAccount(
      id: parseId(json['id']),
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      hasAvatarImage: parseBool(json['hasAvatarImage'], false),
      country: json['country'] as String?,
      roles: parsedRoles,
      isActive: parseBool(json['isActive'], true),
      isEmailVerified: parseBool(json['isEmailVerified'], false),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'hasAvatarImage': hasAvatarImage,
      'country': country,
      'roles': roles,
      'isActive': isActive,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
