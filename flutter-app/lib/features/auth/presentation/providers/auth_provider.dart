import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:lexilingo_app/core/services/google_sign_in_service.dart';
import 'package:lexilingo_app/core/services/firebase_messaging_service.dart';
import 'package:lexilingo_app/core/services/purchases_service.dart';
import 'package:lexilingo_app/core/services/session_expired_service.dart';
import 'package:lexilingo_app/core/services/user_scope_service.dart';

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

    _sessionExpiredSub =
        SessionExpiredService.instance.onSessionExpired.listen(
      (_) => _onSessionExpired(),
    );
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  UserEntity? get user => _user;

  UserEntity? get currentUser => _user;

  bool get isAuthenticated => _user != null;

  bool get isLoading => _isLoading;

  bool get isCheckingAuth => _isCheckingAuth;

  bool get isJustLoggedIn => _isJustLoggedIn;

  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _splitDisplayName(String? displayName) {
    final normalized = (displayName ?? '').trim();

    if (normalized.isEmpty) {
      return const ['', ''];
    }

    final parts = normalized.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return [parts.first, ''];
    }

    return [
      parts.first,
      parts.sublist(1).join(' '),
    ];
  }

  UserEntity _userEntityFromFirebase(
    firebase_auth.User firebaseUser,
  ) {
    final email =
        (firebaseUser.email ?? '').trim().toLowerCase();

    final displayName =
        (firebaseUser.displayName ?? '').trim();

    final username = email.contains('@')
        ? email.split('@').first
        : firebaseUser.uid;

    return UserEntity(
      id: firebaseUser.uid,
      email: email,
      username: username,
      displayName:
          displayName.isEmpty ? username : displayName,
      provider: firebaseUser.providerData.isNotEmpty
          ? firebaseUser.providerData.first.providerId
          : 'firebase',

      //
      // Quoriv AI currently does NOT require
      // email verification.
      //
      // We keep the app-level account usable even when
      // Firebase emailVerified is false.
      //
      isVerified: true,

      isOnboardingCompleted: false,
      nativeLanguage: 'en',
      targetLanguage: 'en',
      createdAt:
          firebaseUser.metadata.creationTime ??
          DateTime.now(),
      updatedAt:
          firebaseUser.metadata.lastSignInTime,
    );
  }

  Future<void> _upsertFirebaseIdentity({
    required firebase_auth.User firebaseUser,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid);

    final existing = await ref.get();

    final data = <String, dynamic>{
      'uid': firebaseUser.uid,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim().toLowerCase(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      data['createdAt'] =
          FieldValue.serverTimestamp();
    }

    await ref.set(
      data,
      SetOptions(merge: true),
    );
  }

  Future<void> _adoptFirebaseUser(
    firebase_auth.User firebaseUser,
  ) async {
    final names =
        _splitDisplayName(firebaseUser.displayName);

    await _upsertFirebaseIdentity(
      firebaseUser: firebaseUser,
      firstName: names[0],
      lastName: names[1],
      email: firebaseUser.email ?? '',
    );

    _user =
        _userEntityFromFirebase(firebaseUser);

    _errorMessage = null;

    _isJustLoggedIn = true;

    await UserScopeService.setActiveUserId(
      firebaseUser.uid,
    );
  }

  // ---------------------------------------------------------------------------
  // Logged-in flag
  // ---------------------------------------------------------------------------

  void clearJustLoggedIn() {
    _isJustLoggedIn = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Refresh Firebase user
  // ---------------------------------------------------------------------------

  Future<void> refreshCurrentUser() async {
    try {
      final auth =
          firebase_auth.FirebaseAuth.instance;

      final current =
          auth.currentUser;

      if (current == null) {
        _user = null;
        _errorMessage = null;

        await UserScopeService
            .clearActiveUserId();

        return;
      }

      await current.reload();

      final refreshed =
          auth.currentUser;

      if (refreshed == null) {
        _user = null;
        _errorMessage = null;

        await UserScopeService
            .clearActiveUserId();

        return;
      }

      //
      // IMPORTANT:
      // No emailVerified check.
      //

      await _adoptFirebaseUser(
        refreshed,
      );

      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint(
        'Refresh Firebase user error: $e',
      );

      _errorMessage =
          _parseErrorMessage(
        e.toString(),
      );
    } finally {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Check current Firebase session on app startup
  // ---------------------------------------------------------------------------

  Future<void> _checkCurrentUser() async {
    try {
      _isCheckingAuth = true;

      notifyListeners();

      final firebaseUser =
          firebase_auth.FirebaseAuth.instance
              .currentUser;

      if (firebaseUser == null) {
        _user = null;
        _errorMessage = null;

        await UserScopeService
            .clearActiveUserId();

        return;
      }

      await firebaseUser.reload();

      final refreshedUser =
          firebase_auth.FirebaseAuth.instance
              .currentUser;

      if (refreshedUser == null) {
        _user = null;
        _errorMessage = null;

        await UserScopeService
            .clearActiveUserId();

        return;
      }

      //
      // No email verification check.
      //

      await _adoptFirebaseUser(
        refreshedUser,
      );

      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint(
        'Firebase auth check error: $e',
      );

      _errorMessage = null;
      _user = null;

      await UserScopeService
          .clearActiveUserId();
    } finally {
      _isCheckingAuth = false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      final result =
          await googleSignInService.signIn();

      if (result ==
          GoogleSignInService
              .redirectInProgressMarker) {
        return;
      }

      if (result == null) {
        final signInError =
            googleSignInService.lastError
                ?.toLowerCase();

        _errorMessage =
            signInError == null ||
                    signInError.contains(
                      'cancelled',
                    )
                ? 'Google sign in was cancelled'
                : _parseErrorMessage(
                    googleSignInService
                        .lastError!,
                  );

        return;
      }

      final firebaseUser =
          firebase_auth.FirebaseAuth.instance
              .currentUser;

      if (firebaseUser == null) {
        throw StateError(
          'Firebase Google Sign-In did not create a session.',
        );
      }

      await _adoptFirebaseUser(
        firebaseUser,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Google sign in error: $e',
      );

      _errorMessage =
          e.message ??
          'Google Sign-In failed.';

      _user = null;
      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint(
        'Google sign in error: $e',
      );

      _errorMessage =
          _parseErrorMessage(
        e.toString(),
      );

      _user = null;
      _isJustLoggedIn = false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Email + Password Login
  // ---------------------------------------------------------------------------

  Future<void> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      final credential =
          await firebase_auth
              .FirebaseAuth.instance
              .signInWithEmailAndPassword(
        email:
            email.trim().toLowerCase(),
        password: password,
      );

      final firebaseUser =
          credential.user;

      if (firebaseUser == null) {
        throw StateError(
          'Firebase did not return a user.',
        );
      }

      await firebaseUser.reload();

      final refreshedUser =
          firebase_auth.FirebaseAuth.instance
              .currentUser;

      if (refreshedUser == null) {
        throw StateError(
          'Firebase session could not be refreshed.',
        );
      }

      //
      // No emailVerified check.
      //

      await _adoptFirebaseUser(
        refreshedUser,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          _errorMessage =
              'Incorrect email or password.';
          break;

        case 'invalid-email':
          _errorMessage =
              'Invalid email address.';
          break;

        case 'user-disabled':
          _errorMessage =
              'This account has been disabled.';
          break;

        case 'too-many-requests':
          _errorMessage =
              'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          _errorMessage =
              'Network error. Check your connection and try again.';
          break;

        default:
          _errorMessage =
              e.message ??
              'Sign in failed. Please try again.';
      }

      _user = null;
      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint(
        'Email sign in error: $e',
      );

      _errorMessage =
          _parseErrorMessage(
        e.toString(),
      );

      _user = null;
      _isJustLoggedIn = false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Forgot Password
  // Firebase sends the reset email directly.
  // ---------------------------------------------------------------------------

  Future<bool> requestPasswordReset(
    String email,
  ) async {
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      await firebase_auth
          .FirebaseAuth.instance
          .sendPasswordResetEmail(
        email:
            email.trim().toLowerCase(),
      );

      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase password reset email error: '
        '${e.code} ${e.message}',
      );

      switch (e.code) {
        case 'invalid-email':
          _errorMessage =
              'Invalid email address.';
          break;

        case 'too-many-requests':
          _errorMessage =
              'Too many requests. Please wait and try again later.';
          break;

        case 'network-request-failed':
          _errorMessage =
              'Network error. Check your connection and try again.';
          break;

        default:
          _errorMessage =
              e.message ??
              'Could not send password reset email.';
      }

      return false;
    } catch (e) {
      _errorMessage =
          _parseErrorMessage(
        e.toString(),
      );

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Verification disabled
  // ---------------------------------------------------------------------------

  /// Kept only for compatibility with any older screen that still calls it.
  ///
  /// IMPORTANT:
  /// This method intentionally sends NO email.
  Future<bool> resendVerificationEmail(
    String email,
  ) async {
    _errorMessage = null;

    debugPrint(
      'Email verification is disabled. '
      'No verification email was sent.',
    );

    return true;
  }

  // ---------------------------------------------------------------------------
  // Firebase Password Reset confirmation
  // ---------------------------------------------------------------------------

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      await firebase_auth
          .FirebaseAuth.instance
          .confirmPasswordReset(
        code: token,
        newPassword: newPassword,
      );

      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase password reset error: '
        '${e.code} ${e.message}',
      );

      switch (e.code) {
        case 'expired-action-code':
          _errorMessage =
              'This password reset link has expired. Please request a new one.';
          break;

        case 'invalid-action-code':
          _errorMessage =
              'This password reset link is invalid or has already been used.';
          break;

        case 'weak-password':
          _errorMessage =
              'Password is too weak. Use at least 6 characters.';
          break;

        case 'user-disabled':
          _errorMessage =
              'This account has been disabled.';
          break;

        case 'user-not-found':
          _errorMessage =
              'No account was found for this reset link.';
          break;

        default:
          _errorMessage =
              e.message ??
              'Could not reset password.';
      }

      return false;
    } catch (e) {
      _errorMessage =
          _parseErrorMessage(
        e.toString(),
      );

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      await googleSignInService.signOut();

      await firebase_auth
          .FirebaseAuth.instance
          .signOut();

      await FirebaseMessagingService.instance
          .clearRegisteredToken();

      await PurchasesService.instance.logout();

      await UserScopeService
          .clearActiveUserId();

      _user = null;
      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint(
        'Sign out error: $e',
      );

      _errorMessage =
          _parseErrorMessage(
        e.toString(),
      );
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Delete Account
  // ---------------------------------------------------------------------------

  Future<void> deleteAccount() async {
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      final auth =
          firebase_auth.FirebaseAuth.instance;

      final firebaseUser =
          auth.currentUser;

      if (firebaseUser == null) {
        _user = null;

        await UserScopeService
            .clearActiveUserId();

        return;
      }

      final uid =
          firebaseUser.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      await googleSignInService.signOut();

      await firebaseUser.delete();

      await FirebaseMessagingService.instance
          .clearRegisteredToken();

      await PurchasesService.instance.logout();

      await UserScopeService
          .clearActiveUserId();

      _user = null;
      _isJustLoggedIn = false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code ==
          'requires-recent-login') {
        _errorMessage =
            'Please sign in again before deleting your account.';
      } else {
        _errorMessage =
            e.message ??
            'Could not delete your account.';
      }

      rethrow;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------------------

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

      final auth =
          firebase_auth.FirebaseAuth.instance;

      final fallbackNames =
          _splitDisplayName(
        displayName,
      );

      final resolvedFirstName =
          (firstName ??
                  fallbackNames[0])
              .trim();

      final resolvedLastName =
          (lastName ??
                  fallbackNames[1])
              .trim();

      final normalizedEmail =
          email.trim().toLowerCase();

      final credential =
          await auth
              .createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final firebaseUser =
          credential.user;

      if (firebaseUser == null) {
        throw StateError(
          'Firebase did not return a user after registration.',
        );
      }

      final resolvedDisplayName =
          '$resolvedFirstName '
                  '$resolvedLastName'
              .trim();

      if (resolvedDisplayName.isNotEmpty) {
        await firebaseUser
            .updateDisplayName(
          resolvedDisplayName,
        );
      }

      await firebaseUser.reload();

      final refreshedUser =
          auth.currentUser ??
          firebaseUser;

      await _upsertFirebaseIdentity(
        firebaseUser:
            refreshedUser,
        firstName:
            resolvedFirstName,
        lastName:
            resolvedLastName,
        email:
            normalizedEmail,
      );

      //
      // IMPORTANT:
      //
      // No sendEmailVerification()
      // No Resend
      // No verification screen requirement
      //
      // User becomes logged in immediately.
      //

      _user =
          _userEntityFromFirebase(
        refreshedUser,
      );

      _errorMessage = null;
      _isJustLoggedIn = true;

      await UserScopeService
          .setActiveUserId(
        refreshedUser.uid,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase registration failed: '
        '${e.code} ${e.message}',
      );

      switch (e.code) {
        case 'email-already-in-use':
          _errorMessage =
              'This email is already registered. Please log in instead.';
          break;

        case 'invalid-email':
          _errorMessage =
              'Invalid email address.';
          break;

        case 'weak-password':
          _errorMessage =
              'Password is too weak. Use at least 6 characters.';
          break;

        case 'operation-not-allowed':
          _errorMessage =
              'Email/password registration is not enabled in Firebase.';
          break;

        case 'network-request-failed':
          _errorMessage =
              'Network error. Check your connection and try again.';
          break;

        case 'too-many-requests':
          _errorMessage =
              'Too many attempts. Please wait a few minutes and try again.';
          break;

        default:
          _errorMessage =
              e.message ??
              'Firebase registration failed. Please try again.';
      }

      _user = null;
      _isJustLoggedIn = false;
    } catch (e) {
      debugPrint(
        'Register error: $e',
      );

      _errorMessage =
          _parseErrorMessage(
        e.toString(),
      );

      _user = null;
      _isJustLoggedIn = false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Update Profile
  // ---------------------------------------------------------------------------

  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      final auth =
          firebase_auth.FirebaseAuth.instance;
