import 'package:flutter/foundation.dart';

import '../models/user_account.dart';
import '../services/api_client.dart';
import '../services/token_store.dart';
import '../services/user_service.dart';

/// Sign-in state.
///
/// The session is a JWT access token plus a rotating refresh token kept in secure storage.
/// On launch the app refreshes the token and loads `/users/me`; it never trusts a cached
/// user object. Logging out revokes the refresh token on the server and clears every
/// provider that registered with [addSignOutListener].
class AuthProvider extends ChangeNotifier {
  AuthProvider({UserService? userService}) : _userService = userService ?? UserService() {
    ApiClient.onRefreshToken = _refreshAccessToken;
    ApiClient.onSessionExpired = () async {
      debugPrint('[auth] session expired; signing out');
      await logout();
    };
  }

  final UserService _userService;
  final List<VoidCallback> _signOutListeners = [];

  UserAccount? _currentUser;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorCode;

  UserAccount? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  /// Message for the last failed action, safe to show in red under the form.
  String? get errorMessage => _errorMessage;

  /// `EMAIL_NOT_VERIFIED`, `ACCOUNT_DISABLED`, or null.
  String? get errorCode => _errorCode;
  bool get needsEmailVerification => _errorCode == 'EMAIL_NOT_VERIFIED';

  /// Providers holding per-user data (cart, playlists, likes, player) register a reset here.
  void addSignOutListener(VoidCallback listener) => _signOutListeners.add(listener);

  @visibleForTesting
  void setUserForTesting(UserAccount? user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null && _errorCode == null) return;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
  }

  void _fail(Object e, String fallback) {
    if (e is ApiException) {
      _errorMessage = e.message;
      _errorCode = e.code;
    } else {
      _errorMessage = fallback;
      _errorCode = null;
      debugPrint('[auth] unexpected error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  /// Restores a previous session if a valid refresh token exists.
  Future<void> initializeUser() async {
    try {
      final refreshToken = await TokenStore.readRefresh();
      if (refreshToken == null) return;
      final session = await _userService.refresh(refreshToken);
      await _startSession(session);
      debugPrint('[auth] session restored userId=${session.user.id}');
    } on ApiException catch (e) {
      debugPrint('[auth] no session restored (status=${e.statusCode})');
      if (e.isUnauthorized) await TokenStore.clear();
      // Network errors keep the tokens so the next launch can try again.
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _startSession(AuthSession session) async {
    await TokenStore.save(accessToken: session.accessToken, refreshToken: session.refreshToken);
    ApiClient.setAccessToken(session.accessToken);
    _currentUser = session.user;
  }

  /// Used by ApiClient when the access token expires (single-flight).
  Future<String?> _refreshAccessToken() async {
    final refreshToken = await TokenStore.readRefresh();
    if (refreshToken == null) return null;
    try {
      final session = await _userService.refresh(refreshToken);
      await TokenStore.save(accessToken: session.accessToken, refreshToken: session.refreshToken);
      return session.accessToken;
    } on ApiException catch (e) {
      debugPrint('[auth] refresh failed status=${e.statusCode}');
      return null;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
    try {
      final session = await _userService.login(email.trim().toLowerCase(), password);
      await _startSession(session);
      return true;
    } catch (e) {
      _fail(e, "We couldn't sign you in. Please try again.");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final refreshToken = await TokenStore.readRefresh();
    final wasSignedIn = _currentUser != null;
    _currentUser = null;
    ApiClient.setAccessToken(null);
    await TokenStore.clear();
    for (final listener in _signOutListeners) {
      listener();
    }
    notifyListeners();
    if (wasSignedIn && refreshToken != null) {
      try {
        await _userService.logout(refreshToken);
      } on ApiException catch (e) {
        // Local sign-out already happened; the token expires on its own.
        debugPrint('[auth] server logout failed status=${e.statusCode}');
      }
    }
  }

  Future<void> refreshCurrentUser() async {
    try {
      _currentUser = await _userService.me();
      notifyListeners();
    } on ApiException catch (e) {
      debugPrint('[auth] could not reload profile: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Registration, verification and recovery
  // ---------------------------------------------------------------------------

  /// Creates the account. The user signs in after verifying their email.
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
    _errorCode = null;
    notifyListeners();
    try {
      await _userService.createUser(
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
      return true;
    } catch (e) {
      _fail(e, "We couldn't create your account. Please try again.");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Activates the account with the code from the email. The user then signs in.
  Future<bool> verifyEmail(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _userService.verifyEmail(code.trim());
      return true;
    } catch (e) {
      _fail(e, "We couldn't verify that code. Please try again.");
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
      _fail(e, "We couldn't send a new code. Please try again.");
      return false;
    }
  }

  /// Requests a reset code. Returns true when the request went through; the server answers the
  /// same way whether or not the email has an account.
  Future<bool> forgotPassword(String email) async {
    _errorMessage = null;
    try {
      await _userService.forgotPassword(email.trim());
      return true;
    } catch (e) {
      _fail(e, "We couldn't send the reset email. Please try again.");
      return false;
    }
  }

  Future<bool> resetPassword(String code, String newPassword) async {
    _errorMessage = null;
    try {
      await _userService.resetPassword(code.trim(), newPassword);
      return true;
    } catch (e) {
      _fail(e, "We couldn't reset your password. Please try again.");
      return false;
    }
  }

  Future<bool> recoverUsername(String email) async {
    try {
      await _userService.recoverUsername(email.trim());
      return true;
    } catch (e) {
      _fail(e, "We couldn't send the reminder. Please try again.");
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchTermsOfService() => _userService.getActiveTermsOfService();

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Future<bool> uploadAvatar({String? avatarPath, List<int>? avatarBytes, String? avatarFilename}) async {
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
      _currentUser = await _userService.me();
      return true;
    } catch (e) {
      _fail(e, "We couldn't update your photo. Please try again.");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({String? displayName, String? bio, String? avatarUrl, String? country}) async {
    if (_currentUser == null) return false;
    try {
      await _userService.updateProfile(
        userId: _currentUser!.id,
        displayName: displayName,
        bio: bio,
        avatarUrl: avatarUrl,
        country: country,
      );
      _currentUser = await _userService.me();
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e, "We couldn't save your profile. Please try again.");
      notifyListeners();
      return false;
    }
  }

  Future<bool> followUser(int targetUserId) async {
    if (_currentUser == null) return false;
    try {
      await _userService.followUser(followerId: _currentUser!.id, followedId: targetUserId);
      return true;
    } catch (e) {
      _fail(e, "We couldn't follow this artist. Please try again.");
      notifyListeners();
      return false;
    }
  }
}
