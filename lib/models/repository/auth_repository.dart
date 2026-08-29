import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';

import 'i_user_repository.dart';

/// Supabase Auth adapter used internally by UserRepository.
class AuthRepository {
  final supabase.SupabaseClient _client;
  final String authCallbackUrl;
  final String passwordResetCallbackUrl;

  AuthRepository(
      this._client, {
        required this.authCallbackUrl,
        required this.passwordResetCallbackUrl,
      });

  AuthUserData? get currentUser => _mapUser(_client.auth.currentUser);

  Stream<AuthSessionSnapshot> get authStateChanges {
    return _client.auth.onAuthStateChange.map(
          (state) => AuthSessionSnapshot(
        user: _mapUser(state.session?.user),
        isPasswordRecovery:
        state.event == supabase.AuthChangeEvent.passwordRecovery,
        isSignedInEvent: state.event == supabase.AuthChangeEvent.signedIn,
      ),
    );
  }

  Future<AuthRegistrationData> signUpWithEmail({
    required String email,
    required String password,
    required String currency,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'currency': currency,
          'role': 'tourist',
        },
      );
      final user = response.user;
      if (user == null || response.session == null) {
        throw const supabase.AuthException(
          'Registration did not create a session. Disable Confirm email for '
              'TREK deferred verification.',
        );
      }
      return AuthRegistrationData(userId: user.id);
    } on supabase.AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('already registered') ||
          message.contains('already exists')) {
        throw const RepositoryEmailAlreadyExistsException();
      }
      rethrow;
    }
  }

  Future<AuthUserData> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = response.user;
      if (user == null) throw const RepositoryInvalidCredentialsException();
      return _mapUser(user)!;
    } on RepositoryInvalidCredentialsException {
      rethrow;
    } on supabase.AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('invalid credentials')) {
        throw const RepositoryInvalidCredentialsException();
      }
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    final started = await _client.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: authCallbackUrl,
      authScreenLaunchMode:
      kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!started) {
      throw const supabase.AuthException(
        'Google sign-in could not be started.',
      );
    }
  }

  Future<void> sendMagicLink({required String email}) async {
    await _client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      emailRedirectTo: authCallbackUrl,
      shouldCreateUser: false,
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: passwordResetCallbackUrl,
    );
  }

  Future<void> updatePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(
          password: newPassword,
          currentPassword: currentPassword,
        ),
      );
    } on supabase.AuthException catch (error) {
      final code = error.code?.toLowerCase();
      final message = error.message.toLowerCase();
      if (code == 'same_password' || message.contains('same password')) {
        throw const RepositorySamePasswordException();
      }
      if (code == 'invalid_credentials' ||
          message.contains('current password') ||
          message.contains('invalid login credentials')) {
        throw const RepositoryIncorrectCurrentPasswordException();
      }
      rethrow;
    }
  }

  Future<void> signOut({bool allSessions = false}) async {
    await _client.auth.signOut(
      scope: allSessions
          ? supabase.SignOutScope.global
          : supabase.SignOutScope.local,
    );
  }

  static AuthUserData? _mapUser(supabase.User? user) {
    if (user == null) return null;
    return AuthUserData(
      id: user.id,
      email: user.email ?? '',
      provider: user.appMetadata['provider'] as String? ?? 'email',
      metadata: Map<String, dynamic>.from(user.userMetadata ?? const {}),
    );
  }
}
