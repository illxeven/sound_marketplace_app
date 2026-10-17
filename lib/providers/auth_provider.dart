import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_account.dart';
import '../services/api_client.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _prefKeyUser = 'sound_marketplace_active_user';

  final UserService _userService = UserService();

  UserAccount? _currentUser;
  List<UserAccount> _allUsers = [];
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;

  UserAccount? get currentUser => _currentUser;
  List<UserAccount> get allUsers => _allUsers;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Strict Authentication Guard
  bool get isAuthenticated => _currentUser != null;

  Future<void> initializeUser() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      // Check SharedPreferences first for cached active user session
      final prefs = await SharedPreferences.getInstance();
      final cachedJsonStr = prefs.getString(_prefKeyUser);

      if (cachedJsonStr != null && cachedJsonStr.trim().isNotEmpty) {
        try {
          final Map<String, dynamic> userMap = jsonDecode(cachedJsonStr);
          final cachedUser = UserAccount.fromJson(userMap);

          // Fast-boot: Immediately restore cached user and notify listeners
          _currentUser = cachedUser;
          ApiClient.setAuthUser(cachedUser.id);
          notifyListeners();

          // Background re-validation with a fast timeout (4 seconds)
          _userService.getUserById(cachedUser.id).timeout(
            const Duration(seconds: 4),
            onTimeout: () => cachedUser,
          ).then((freshUser) {
            if (freshUser != null && freshUser.isActive) {
              _currentUser = freshUser;
              ApiClient.setAuthUser(freshUser.id);
              _cacheUserSession(freshUser);
              notifyListeners();
            } else if (freshUser != null && !freshUser.isActive) {
              logout();
            }
          }).catchError((err) {
            debugPrint('Silent re-validation error (using cached session): $err');
          });
        } catch (cacheErr) {
          debugPrint('Failed to parse cached session: $cacheErr');
        }
      }

      // Preload user list in background without blocking initial launch
      _userService.getAllUsers().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <UserAccount>[],
      ).then((users) {
        _allUsers = users;
        notifyListeners();
      }).catchError((err) {
        debugPrint('Silent user list preload error: $err');
      });
    } catch (e) {
      debugPrint('Initialization error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _cacheUserSession(UserAccount user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyUser, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('Failed to save session to SharedPreferences: $e');
    }
  }

  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyUser);
    } catch (e) {
      debugPrint('Failed to clear session from SharedPreferences: $e');
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _userService.getUserByEmail(email.trim());
      if (user == null) {
        _errorMessage = 'No user found with email "$email"';
        return false;
      }
      if (!user.isEmailVerified) {
        _errorMessage = 'UNVERIFIED_EMAIL';
        return false;
      }
      _currentUser = user;
      ApiClient.setAuthUser(user.id);
      await _cacheUserSession(user);

      if (!_allUsers.any((u) => u.id == user.id)) {
        _allUsers.insert(0, user);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _currentUser = null;
    ApiClient.setAuthUser(null);
    _clearUserSession();
    notifyListeners();
  }

  void switchUser(UserAccount user) {
    _currentUser = user;
    ApiClient.setAuthUser(user.id);
    _cacheUserSession(user);
    notifyListeners();
  }

  Future<bool> register({
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newUser = await _userService.createUser(
        email: email.trim(),
        password: password,
        displayName: displayName?.trim(),
        country: country?.trim(),
        role: role,
        bio: bio?.trim(),
        termsAccepted: termsAccepted,
        avatarPath: avatarPath,
        avatarBytes: avatarBytes,
        avatarFilename: avatarFilename,
      );
      if (!_allUsers.any((u) => u.id == newUser.id)) {
        _allUsers.insert(0, newUser);
      }
      // If email requires verification (like on other sites), do NOT log in yet
      if (newUser.isEmailVerified) {
        _currentUser = newUser;
        ApiClient.setAuthUser(newUser.id);
        await _cacheUserSession(newUser);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchTermsOfService() async {
    return _userService.getActiveTermsOfService();
  }

  Future<bool> uploadAvatar({
    String? avatarPath,
    List<int>? avatarBytes,
    String? avatarFilename,
  }) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _userService.uploadAvatar(
        userId: _currentUser!.id,
        avatarPath: avatarPath,
        avatarBytes: avatarBytes,
        avatarFilename: avatarFilename,
      );
      final refreshed = await _userService.getUserById(_currentUser!.id);
      if (refreshed != null) {
        _currentUser = refreshed;
        await _cacheUserSession(refreshed);
        final idx = _allUsers.indexWhere((u) => u.id == refreshed.id);
        if (idx != -1) {
          _allUsers[idx] = refreshed;
        }
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? country,
  }) async {
    if (_currentUser == null) return false;
    try {
      await _userService.updateProfile(
        userId: _currentUser!.id,
        displayName: displayName,
        bio: bio,
        avatarUrl: avatarUrl,
        country: country,
      );
      final updated = UserAccount(
        id: _currentUser!.id,
        email: _currentUser!.email,
        displayName: displayName ?? _currentUser!.displayName,
        bio: bio ?? _currentUser!.bio,
        avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
        country: country ?? _currentUser!.country,
        roles: _currentUser!.roles,
        isActive: _currentUser!.isActive,
        createdAt: _currentUser!.createdAt,
      );
      _currentUser = updated;
      await _cacheUserSession(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> followUser(int targetUserId) async {
    if (_currentUser == null) return false;
    try {
      await _userService.followUser(
        followerId: _currentUser!.id,
        followedId: targetUserId,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String?> forgotPassword(String email) async {
    try {
      final token = await _userService.forgotPassword(email.trim());
      return token ?? '';
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    try {
      await _userService.resetPassword(token.trim(), newPassword);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> verifyEmail(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final verifiedUser = await _userService.verifyEmail(token.trim());
      _currentUser = verifiedUser;
      ApiClient.setAuthUser(verifiedUser.id);
      await _cacheUserSession(verifiedUser);
      final idx = _allUsers.indexWhere((u) => u.id == verifiedUser.id);
      if (idx != -1) {
        _allUsers[idx] = verifiedUser;
      } else {
        _allUsers.insert(0, verifiedUser);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerification(String email) async {
    try {
      await _userService.resendVerification(email.trim());
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> recoverUsername(String email) async {
    try {
      await _userService.recoverUsername(email.trim());
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }
}
