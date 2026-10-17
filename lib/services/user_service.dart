import '../models/user_account.dart';
import 'api_client.dart';

class UserService {
  Future<List<UserAccount>> getAllUsers() async {
    final response = await ApiClient.get<List<UserAccount>>(
      '/users',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((item) => UserAccount.fromJson(item as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<UserAccount?> getUserById(int id) async {
    final response = await ApiClient.get<UserAccount>(
      '/users/$id',
      fromJsonT: (json) => UserAccount.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<UserAccount?> getUserByEmail(String email) async {
    final response = await ApiClient.get<UserAccount>(
      '/users/email/$email',
      fromJsonT: (json) => UserAccount.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<UserAccount> createUser({
    required String email,
    required String password,
    String? displayName,
    String? country,
    String? role,
    String? bio,
    bool termsAccepted = true,
    String? avatarPath,
    List<int>? avatarBytes,
    String? avatarFilename,
  }) async {
    if ((avatarPath != null && avatarPath.isNotEmpty) ||
        (avatarBytes != null && avatarBytes.isNotEmpty)) {
      final fields = <String, String>{
        'email': email,
        'password': password,
        'termsAccepted': termsAccepted.toString(),
        if (displayName != null) 'displayName': displayName,
        if (country != null) 'country': country,
        if (role != null) 'role': role,
        if (bio != null) 'bio': bio,
      };
      final response = await ApiClient.postMultipart<UserAccount>(
        '/auth/register-with-avatar',
        fileField: 'avatar',
        filePath: avatarPath,
        fileBytes: avatarBytes,
        filename: avatarFilename ?? 'avatar.jpg',
        fields: fields,
        fromJsonT: (json) => UserAccount.fromJson(json as Map<String, dynamic>),
      );
      if (response.data == null) {
        throw ApiException(response.message ?? 'Failed to create user with avatar');
      }
      return response.data!;
    }

    final response = await ApiClient.post<UserAccount>(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        'displayName': displayName,
        'country': country,
        if (role != null) 'role': role,
        if (bio != null) 'bio': bio,
        'termsAccepted': termsAccepted,
      },
      fromJsonT: (json) => UserAccount.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to create user');
    }
    return response.data!;
  }

  Future<Map<String, dynamic>?> getActiveTermsOfService() async {
    try {
      final response = await ApiClient.get<dynamic>(
        '/legal/active/TERMS_OF_SERVICE',
        fromJsonT: (json) => json,
      );
      if (response.data is List && (response.data as List).isNotEmpty) {
        return (response.data as List).first as Map<String, dynamic>;
      }
      // Fallback to /legal/active
      final fallback = await ApiClient.get<dynamic>(
        '/legal/active',
        fromJsonT: (json) => json,
      );
      if (fallback.data is List && (fallback.data as List).isNotEmpty) {
        return (fallback.data as List).first as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadAvatar({
    required int userId,
    String? avatarPath,
    List<int>? avatarBytes,
    String? avatarFilename,
  }) async {
    await ApiClient.postMultipart(
      '/users/$userId/avatar',
      fileField: 'avatar',
      filePath: avatarPath,
      fileBytes: avatarBytes,
      filename: avatarFilename ?? 'avatar.jpg',
    );
  }

  Future<void> updateProfile({
    required int userId,
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? country,
  }) async {
    await ApiClient.put(
      '/users/$userId/profile',
      body: {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (country != null) 'country': country,
      },
    );
  }

  Future<void> followUser({
    required int followerId,
    required int followedId,
  }) async {
    await ApiClient.post('/users/$followerId/follow/$followedId');
  }

  Future<String?> forgotPassword(String email) async {
    final response = await ApiClient.post<dynamic>(
      '/auth/forgot-password',
      body: {'email': email},
      fromJsonT: (json) => json,
    );
    if (response.data is Map) {
      final map = response.data as Map;
      return map['token']?.toString();
    }
    return null;
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await ApiClient.post(
      '/auth/reset-password',
      body: {
        'token': token.trim(),
        'newPassword': newPassword,
      },
    );
  }

  Future<void> recoverUsername(String email) async {
    await ApiClient.post('/auth/recover-username?email=$email');
  }

  Future<UserAccount> verifyEmail(String token) async {
    final response = await ApiClient.post<UserAccount>(
      '/auth/verify-email?token=$token',
      fromJsonT: (json) => UserAccount.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Verification failed');
    }
    return response.data!;
  }

  Future<Map<String, dynamic>?> getPublicProfile(int userId) async {
    final response = await ApiClient.get<Map<String, dynamic>>(
      '/users/$userId/public-profile',
      fromJsonT: (json) => json as Map<String, dynamic>,
    );
    return response.data;
  }

  Future<void> resendVerification(String email) async {
    await ApiClient.post('/auth/resend-verification?email=$email');
  }

  Future<List<dynamic>> getUserReviews(int userId) async {
    final response = await ApiClient.get<List<dynamic>>(
      '/users/$userId/reviews',
      fromJsonT: (json) {
        if (json is List) return json;
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<double> getUserAverageRating(int userId) async {
    final response = await ApiClient.get<dynamic>(
      '/users/$userId/rating',
      fromJsonT: (json) => json,
    );
    if (response.data is Map && response.data['averageRating'] != null) {
      return (response.data['averageRating'] as num).toDouble();
    }
    return 0.0;
  }

  Future<dynamic> addUserReview({
    required int targetUserId,
    required int reviewerId,
    required int rating,
    String? comment,
  }) async {
    final response = await ApiClient.post<dynamic>(
      '/users/$targetUserId/reviews',
      body: {
        'reviewerId': reviewerId,
        'rating': rating,
        'comment': comment,
      },
      fromJsonT: (json) => json,
    );
    return response.data;
  }

  Future<dynamic> updateUserReview({
    required int reviewId,
    required int reviewerId,
    required int rating,
    String? comment,
  }) async {
    final response = await ApiClient.put<dynamic>(
      '/users/reviews/$reviewId',
      body: {
        'reviewerId': reviewerId,
        'rating': rating,
        'comment': comment,
      },
      fromJsonT: (json) => json,
    );
    return response.data;
  }

  Future<void> deleteUserReview(int reviewId, int reviewerId) async {
    await ApiClient.delete('/users/reviews/$reviewId?reviewerId=$reviewerId');
  }
}
