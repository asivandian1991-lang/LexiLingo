import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/app_logger.dart';

const _tag = 'GoogleSignInService';

/// Service for handling Google Sign In
///
/// On Web: uses Firebase Auth [signInWithPopup] with [GoogleAuthProvider].
/// This avoids calling the People API (which requires a separate GCP
/// API enable step) and gets the id_token directly from the GIS popup.
///
/// On Mobile: uses the standard [google_sign_in] package so that the
/// server-client-id / id_token exchange works correctly.
class GoogleSignInService {
  static const String redirectInProgressMarker =
      '__GOOGLE_REDIRECT_IN_PROGRESS__';

  final GoogleSignIn _googleSignIn;
  String? _lastError;

  String? get lastError => _lastError;

  GoogleSignInService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            scopes: ['email', 'profile'],
          );

  /// Sign in with Google and return the Firebase ID token.
  /// Returns null if sign-in was cancelled or failed.
  Future<String?> signIn() async {
    try {
      _lastError = null;
      logInfo(_tag, 'Starting Google Sign In...');

      if (kIsWeb) {
        return await _signInWeb();
      } else {
        return await _signInMobile();
      }
    } catch (e) {
      logError(_tag, 'Google Sign In error: $e');
      _lastError = e.toString();
      return null;
    }
  }

  /// Web: use Firebase Auth signInWithPopup — no People API call needed.
  /// Extracts the Google ID token from the OAuth credential (not the Firebase
  /// ID token), so the backend's verify_google_token still works.
  Future<String?> _signInWeb() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});

    // If the app has just returned from signInWithRedirect(), consume the
    // pending credential first.
    final pendingRedirectToken = await consumePendingWebRedirectIdToken();
    if (pendingRedirectToken != null) {
      return pendingRedirectToken;
    }

    try {
      final userCredential = await FirebaseAuth.instance.signInWithPopup(
        provider,
      );

      return await _extractGoogleIdTokenAndSignOut(userCredential);
    } on FirebaseAuthException catch (e) {
      if (_shouldFallbackToRedirect(e.code, e.message)) {
        logWarn(
          _tag,
          'Popup sign-in failed (${e.code}), falling back to redirect flow',
        );
        await FirebaseAuth.instance.signInWithRedirect(provider);
        return redirectInProgressMarker;
      }
      rethrow;
    } catch (e) {
      final message = e.toString();
      if (_shouldFallbackToRedirect('unknown', message)) {
        logWarn(
          _tag,
          'Popup sign-in blocked by browser policy, using redirect flow',
        );
        await FirebaseAuth.instance.signInWithRedirect(provider);
        return redirectInProgressMarker;
      }
      rethrow;
    }
  }

  /// Consume pending Google credential after signInWithRedirect().
  /// Returns Google id_token if present.
  Future<String?> consumePendingWebRedirectIdToken() async {
    if (!kIsWeb) return null;

    try {
      final redirectResult = await FirebaseAuth.instance.getRedirectResult();
      return await _extractGoogleIdTokenAndSignOut(redirectResult);
    } catch (e) {
      logWarn(_tag, 'No pending redirect result or failed to consume: $e');
      return null;
    }
  }

  Future<String?> _extractGoogleIdTokenAndSignOut(
    UserCredential userCredential,
  ) async {
    final firebaseToken = await userCredential.user?.getIdToken(true);
    if (firebaseToken == null) {
      logError(_tag, 'Failed to get Firebase ID token after Google Sign-In');
      return null;
    }

    logInfo(_tag, 'Google Sign In successful (web + Firebase)');
    return firebaseToken;
  }

  bool _shouldFallbackToRedirect(String code, String? message) {
    const fallbackCodes = {
      'popup-blocked',
      'popup-closed-by-user',
      'cancelled-popup-request',
      'operation-not-supported-in-this-environment',
      'web-storage-unsupported',
    };

    if (fallbackCodes.contains(code)) return true;

    final normalized = (message ?? '').toLowerCase();
    return normalized.contains('cross-origin-opener-policy') ||
        normalized.contains('window.closed') ||
        normalized.contains('popup');
  }

  /// Mobile: sign in with Google and immediately authenticate with Firebase.
  /// The returned token is a Firebase ID token and is only used as a success marker
  /// by the AuthProvider; the Firebase session is already established here.
  Future<String?> _signInMobile() async {
    try {
      try {
        await _googleSignIn.signOut();
      } on PlatformException catch (e) {
        logWarn(_tag, 'Could not clear previous Google session: ${e.code} ${e.message}');
      }

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        _lastError = 'cancelled';
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      if (auth.idToken == null) {
        _lastError = 'Unable to get Google ID token. Check Android OAuth SHA configuration.';
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseToken = await userCredential.user?.getIdToken(true);
      if (firebaseToken == null) {
        _lastError = 'Firebase did not return an ID token after Google Sign-In.';
        return null;
      }
      logInfo(_tag, 'Google Sign In successful (mobile + Firebase)');
      return firebaseToken;
    } on PlatformException catch (e) {
      _lastError = _mapMobileGoogleError(e);
      logError(_tag, 'Google mobile sign-in PlatformException: ${e.code} ${e.message}');
      return null;
    } on FirebaseAuthException catch (e) {
      _lastError = e.message ?? 'Firebase Google Sign-In failed.';
      logError(_tag, 'Firebase Google sign-in failed: ${e.code} ${e.message}');
      return null;
    }
  }
  String _mapMobileGoogleError(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();
    final details = (e.details ?? '').toString().toLowerCase();
    final combined = '$code $message $details';

    if (combined.contains('10') ||
        combined.contains('developer_error') ||
        combined.contains('12500')) {
      return 'Google Sign-In Android config mismatch (SHA/client ID).';
    }
    if (combined.contains('network')) {
      return 'Network error during Google Sign-In. Please check your connection.';
    }
    if (combined.contains('cancel')) {
      return 'cancelled';
    }
    return e.message ?? 'Google Sign-In failed on mobile.';
  }
  /// Sign out from Google without revoking the user's OAuth grant.
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      } else {
        await FirebaseAuth.instance.signOut();
      }
      logInfo(_tag, 'Google Sign Out successful');
    } catch (e) {
      logError(_tag, 'Google Sign Out error: $e');
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    if (kIsWeb) {
      return FirebaseAuth.instance.currentUser != null;
    }
    return await _googleSignIn.isSignedIn();
  }

  /// Get current Google account (mobile only)
  GoogleSignInAccount? get currentUser =>
      kIsWeb ? null : _googleSignIn.currentUser;
}
