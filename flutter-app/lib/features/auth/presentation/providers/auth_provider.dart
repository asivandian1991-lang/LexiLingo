import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lexilingo_app/core/di/service_locator.dart';
import 'package:lexilingo_app/core/error/failures.dart';
import 'package:lexilingo_app/core/services/google_sign_in_service.dart';
import 'package:lexilingo_app/core/services/purchases_service.dart';
import 'package:lexilingo_app/core/services/session_expired_service.dart';
import 'package:lexilingo_app/core/services/user_scope_service.dart';
import 'package:lexilingo_app/core/usecase/usecase.dart';
import 'package:lexilingo_app/features/auth/domain/entities/user_entity.dart';
import 'package:lexilingo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:lexilingo_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:lexilingo_app/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:lexilingo_app/features/auth/domain/usecases/sign_in_with_email_password_usecase.dart';
import 'package:lexilingo_app/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:lexilingo_app/features/auth/domain/usecases/register_usecase.dart';


class AuthProvider extends ChangeNotifier {
  final SignInWithGoogleUseCase signInWithGoogleUseCase;
  final SignInWithEmailPasswordUseCase signInWithEmailPasswordUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final RegisterUseCase registerUseCase;
  final AuthRepository authRepository;
  final GoogleSignInService googleSignInService;

  UserEntity? _user;
  bool _isLoading = false;
  bool _isCheckingAuth = true;
  bool _isJustLoggedIn = false;
  String? _errorMessage;
  late final StreamSubscription<void> _sessionExpiredSub;

  AuthProvider({
    required this.signInWithGoogleUseCase,
    required this.signInWithEmailPasswordUseCase,
    required this.signOutUseCase,
    required this.getCurrentUserUseCase,
    required this.registerUseCase,
    required this.authRepository,
    required this.googleSignInService,
  }) {
    _checkCurrentUser();
    _sessionExpiredSub = SessionExpiredService.instance.onSessionExpired.listen(
      (_) => _onSessionExpired(),
    );
  }

  void _onSessionExpired() {
    _user = null;
    _errorMessage = null;
    _isJustLoggedIn = false;
    UserScopeService.clearActiveUserId();
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionExpiredSub.cancel();
    super.dispose();
  }

  // Getters
  UserEntity? get user => _user;
  UserEntity? get currentUser => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth;
  bool get isJustLoggedIn => _isJustLoggedIn;
  String? get errorMessage => _errorMessage;


  List<String> _splitDisplayName(String? displayName) {
    final normalized = (displayName ?? '').trim();
    if (normalized.isEmpty) return const ['', ''];
    final parts = normalized.split(RegExp(r'\\s+'));
    if (parts.length == 1) return [parts.first, ''];
    return [parts.first, parts.sublist(1).join(' ')];
  }

  UserEntity _userEntityFromFirebase(firebase_auth.User firebaseUser) {
    final email = (firebaseUser.email ?? '').trim().toLowerCase();
    final displayName = (firebaseUser.displayName ?? '').trim();
    final username = email.contains('@') ? email.split('@').first : firebaseUser.uid;

    return UserEntity(
      id: firebaseUser.uid,
      email: email,
      username: username,
      displayName: displayName.isEmpty ? username : displayName,
      provider: firebaseUser.providerData.isNotEmpty
          ? firebaseUser.providerData.first.providerId
          : 'firebase',
      isVerified: firebaseUser.emailVerified,
      isOnboardingCompleted: false,
      nativeLanguage: 'en',
      targetLanguage: 'en',
      createdAt:
          firebaseUser.metadata.creationTime ?? DateTime.now(),
      updatedAt: firebaseUser.metadata.lastSignInTime,
    );
  }

  Future<void> _adoptFirebaseUser(firebase_auth.User firebaseUser) async {
    final names = _splitDisplayName(firebaseUser.displayName);
    await _upsertFirebaseIdentity(
      firebaseUser: firebaseUser,
      firstName: names[0],
      lastName: names[1],
      email: firebaseUser.email ?? '',
    );
    _user = _userEntityFromFirebase(firebaseUser);
    _errorMessage = null;
    _isJustLoggedIn = true;
    await UserScopeService.setActiveUserId(firebaseUser.uid);
  }

  Future<void> _upsertFirebaseIdentity({
    required firebase_auth.User firebaseUser,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
    final existing = await ref.get();

    final data = <String, dynamic>{
      'uid': firebaseUser.uid,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim().toLowerCase(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
  }

  // Clear just logged in flag (call after welcome screen)
  void clearJustLoggedIn() {
    _isJustLoggedIn = false;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    final result = await getCurrentUserUseCase(NoParams());
    result.fold((failure) => _errorMessage = _getFailureMessage(failure), (
      user,
    ) {
      _user = user;
      _errorMessage = null;
    });
    notifyListeners();
  }

  // Check current user on app start.
  // Firebase Auth is the source of truth for app authentication.
  Future<void> _checkCurrentUser() async {
    try {
      _isCheckingAuth = true;
      notifyListeners();

      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _user = null;
        _errorMessage = null;
        await UserScopeService.clearActiveUserId();
        return;
      }

      await firebaseUser.reload();
      final refreshedUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) {
        _user = null;
        _errorMessage = null;
        await UserScopeService.clearActiveUserId();
        return;
      }

      final isPasswordUser = refreshedUser.providerData.any(
        (provider) => provider.providerId == 'password',
      );
      if (isPasswordUser && !refreshedUser.emailVerified) {
        _user = null;
        _errorMessage = null;
        await UserScopeService.clearActiveUserId();
        return;
      }

      await _adoptFirebaseUser(refreshedUser);
      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint("Firebase auth check error: $e");
      _errorMessage = null;
      _user = null;
      await UserScopeService.clearActiveUserId();
    } finally {
      _isCheckingAuth = false;
      notifyListeners();
    }
  }

  // Sign in with Google through Firebase Auth.
  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final idToken = await googleSignInService.signIn();
      if (idToken == GoogleSignInService.redirectInProgressMarker) {
        return;
      }

      if (idToken == null) {
        final signInError = googleSignInService.lastError?.toLowerCase();
        _errorMessage =
            signInError == null || signInError.contains('cancelled')
                ? 'Google sign in was cancelled'
                : _parseErrorMessage(googleSignInService.lastError!);
        return;
      }

      final googleCredential =
          firebase_auth.GoogleAuthProvider.credential(idToken: idToken);
      final credential = await firebase_auth.FirebaseAuth.instance
          .signInWithCredential(googleCredential);
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw StateError('Firebase Google Sign-In did not return a user.');
      }

      await _adoptFirebaseUser(firebaseUser);
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint("Firebase Google sign in error: $e");
      _errorMessage = e.message ?? 'Google Sign-In failed.';
      _user = null;
      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint("Google sign in error: $e");
      _errorMessage = _parseErrorMessage(e.toString());
      _user = null;
      _isJustLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with email and password through Firebase Auth.
  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final credential = await firebase_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw StateError('Firebase did not return a user.');
      }

      await firebaseUser.reload();
      final refreshedUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) {
        throw StateError('Firebase session could not be refreshed.');
      }

      if (!refreshedUser.emailVerified) {
        _user = null;
        _isJustLoggedIn = false;
        _errorMessage =
            'Email is not verified. Please check your inbox or resend the verification email.';
        return;
      }

      await _adoptFirebaseUser(refreshedUser);
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          _errorMessage = 'Incorrect email or password.';
          break;
        case 'invalid-email':
          _errorMessage = 'Invalid email address.';
          break;
        case 'user-disabled':
          _errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          _errorMessage = 'Too many attempts. Please try again later.';
          break;
        default:
          _errorMessage = e.message ?? 'Sign in failed. Please try again.';
      }
      _user = null;
      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint("Email sign in error: $e");
      _errorMessage = _parseErrorMessage(e.toString());
      _user = null;
      _isJustLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send a Firebase password-reset email.
  Future<bool> requestPasswordReset(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Could not send password reset email.';
      return false;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resend the Firebase verification email for the currently signed-in user.
  Future<bool> resendVerificationEmail(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _errorMessage =
            'Please sign in with this email first, then resend the verification email.';
        return false;
      }

      if ((firebaseUser.email ?? '').trim().toLowerCase() !=
          email.trim().toLowerCase()) {
        _errorMessage =
            'The signed-in account does not match this email address.';
        return false;
      }

      await firebaseUser.reload();
      final refreshedUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) {
        _errorMessage = 'Your Firebase session expired. Please sign in again.';
        return false;
      }

      if (refreshedUser.emailVerified) {
        _errorMessage = null;
        return true;
      }

      await refreshedUser.sendEmailVerification();
      _errorMessage = null;
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        _errorMessage =
            'Too many verification emails were requested. Please wait and try again.';
      } else {
        _errorMessage = e.message ?? 'Could not resend verification email.';
      }
      return false;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset password with token from email link.
  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await authRepository.resetPassword(
        token: token,
        newPassword: newPassword,
      );

      final succeeded = result.fold<bool>(
        (failure) {
          _errorMessage = _getFailureMessage(failure);
          return false;
        },
        (_) {
          _errorMessage = null;
          return true;
        },
      );
      return succeeded;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await googleSignInService.signOut();
      await firebase_auth.FirebaseAuth.instance.signOut();
      await signOutUseCase(NoParams());
      // Clear stored FCM token so it gets re-registered on next login
      await FirebaseMessagingService.instance.clearRegisteredToken();
      await PurchasesService.instance.logout();
      _user = null;
    } catch (e) {
      debugPrint("Sign out error: $e");
      _errorMessage = _parseErrorMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Permanently delete current user account (GDPR hard delete)
  Future<void> deleteAccount() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final apiClient = sl<ApiClient>();
      await apiClient.delete('/users/me/permanent');

      await googleSignInService.signOut();
      await signOutUseCase(NoParams());
      await FirebaseMessagingService.instance.clearRegisteredToken();
      _user = null;
    } catch (e) {
      debugPrint("Delete account error: $e");
      _errorMessage = _parseErrorMessage(e.toString());
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register new user
  Future<void> register({
    required String email,
    required String username,
    required String password,
    String? displayName,
    String? firstName,
    String? lastName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final fallbackNames = _splitDisplayName(displayName);
      final resolvedFirstName = (firstName ?? fallbackNames[0]).trim();
      final resolvedLastName = (lastName ?? fallbackNames[1]).trim();
      final normalizedEmail = email.trim().toLowerCase();

      final credential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw StateError('Firebase did not return a user after registration.');
      }

      final resolvedDisplayName =
          '$resolvedFirstName $resolvedLastName'.trim();
      if (resolvedDisplayName.isNotEmpty) {
        await firebaseUser.updateDisplayName(resolvedDisplayName);
      }

      await _upsertFirebaseIdentity(
        firebaseUser: firebaseUser,
        firstName: resolvedFirstName,
        lastName: resolvedLastName,
        email: normalizedEmail,
      );

      if (!firebaseUser.emailVerified) {
        await firebaseUser.sendEmailVerification();
      }

      _user = null;
      _errorMessage = null;
      _isJustLoggedIn = false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _errorMessage = 'This email is already registered.';
          break;
        case 'invalid-email':
          _errorMessage = 'Invalid email address.';
          break;
        case 'weak-password':
          _errorMessage = 'Password is too weak.';
          break;
        case 'operation-not-allowed':
          _errorMessage =
              'Email/password registration is not enabled in Firebase.';
          break;
        default:
          _errorMessage =
              e.message ?? 'Firebase registration failed. Please try again.';
      }
      _user = null;
      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint("Register error: $e");
      _errorMessage = _parseErrorMessage(e.toString());
      _user = null;
      _isJustLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile (display name, avatar)
  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await authRepository.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
      );

      result.fold(
        (failure) {
          _errorMessage = _getFailureMessage(failure);
          throw Exception(_errorMessage);
        },
        (updatedUser) {
          _user = updatedUser;
          _errorMessage = null;
        },
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit onboarding payload once at the end of onboarding flow.
  ///
  /// [displayName] and [nativeLanguage] are optional overrides from the
  /// pre-auth questions page. If not provided, sensible defaults are used.
  Future<void> submitOnboarding(
    Map<String, dynamic> payload, {
    String? displayName,
    String? nativeLanguage,
  }) async {
    final selectedLevel = (payload['level'] as String?)?.toUpperCase();

    final result = await authRepository.updateProfile(
      displayName: displayName,
      level: selectedLevel,
      goal: payload['goal'] as String?,
      interest: payload['interest'] as String?,
      nativeLanguage: nativeLanguage ?? 'vi',
      targetLanguage: (payload['target_language'] as String?) ?? 'en',
      isOnboardingCompleted: true,
    );

    result.fold(
      (_) {
        // Keep onboarding non-blocking on backend issues.
      },
      (updatedUser) {
        _user = updatedUser;
      },
    );
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Parse error messages to user-friendly format
  String _parseErrorMessage(String error) {
    final normalized = error.toLowerCase();

    if (normalized.contains('timeoutexception') ||
        normalized.contains('timed out')) {
      return 'Server is not responding in time. Please try again in a moment.';
    }
    if (normalized.contains('/users/me failed')) {
      return 'Sign in succeeded, but we could not load your profile. Please try again.';
    }
    if (normalized.contains('internal server error')) {
      return 'Server error occurred. Please try again later.';
    }
    if (normalized.contains('google_server_client_id')) {
      return 'Google sign-in config is missing. Please contact support.';
    }
    if (normalized.contains('google sign-in android config mismatch') ||
        normalized.contains('developer_error') ||
        normalized.contains('sha-1') ||
        normalized.contains('sha/client id')) {
      return 'Google Sign-In on Android is not configured correctly (SHA-1/SHA-256 or client ID). Please contact support.';
    }

    if (normalized.contains('account-exists-with-different-credential')) {
      return 'This email is already linked to another provider. Please sign in with the previous method first.';
    }
    if (normalized.contains('access-control-allow-origin') ||
        normalized.contains('blocked by cors')) {
      return 'Login is blocked by CORS configuration. Please try again in a moment.';
    }
    if (normalized.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (normalized.contains('cancelled') ||
        normalized.contains('canceled')) {
      return 'Sign in was cancelled.';
    } else if (normalized.contains('email')) {
      return 'Invalid email address.';
    } else if (normalized.contains('password')) {
      return 'Invalid password.';
    } else if (normalized.contains('user-not-found')) {
      return 'No account found with this email.';
    } else if (normalized.contains('wrong-password')) {
      return 'Incorrect password.';
    } else if (normalized.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  // Convert Failure to user-friendly message
  String _getFailureMessage(Failure failure) {
    if (failure is AuthFailure) {
      final normalized = failure.message.toLowerCase();
      if (normalized.contains('invalid google id token')) {
        return 'Google Sign-In token is invalid. Please update Android SHA and Google OAuth config.';
      }
      return failure.message;
    } else if (failure is ServerFailure) {
      final normalized = failure.message.toLowerCase();
      if (normalized.contains('timeoutexception') ||
          normalized.contains('timed out')) {
        return 'Server timeout. Please check server status and try again.';
      }
      if (normalized.contains('/users/me failed')) {
        return 'Sign in succeeded, but we could not load your profile. Please try again.';
      }
      return failure.message;
    } else if (failure is NetworkFailure) {
      return 'Network error. Please check your internet connection.';
    } else if (failure is CacheFailure) {
      return 'Local storage error.';
    } else if (failure is ValidationFailure) {
      return failure.message;
    } else if (failure is ConflictFailure) {
      return failure.message;
    } else if (failure is RateLimitFailure) {
      return 'Too many attempts. Please try again later.';
    } else if (failure is PermissionFailure) {
      return failure.message;
    } else if (failure is NotFoundFailure) {
      return failure.message;
    } else if (failure is UnauthorizedFailure) {
      return 'Session expired. Please sign in again.';
    } else {
      return failure.message.isNotEmpty
          ? failure.message
          : 'An error occurred. Please try again.';
    }
  }
}
