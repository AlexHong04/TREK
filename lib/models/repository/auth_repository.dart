import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthUserData {
  final String id;
  final String email;
  final bool isEmailVerified;
  final Map<String, dynamic> metadata;

  const AuthUserData({
    required this.id,
    required this.email,
    required this.isEmailVerified,
    this.metadata = const {},
  });
}

class AuthSessionSnapshot {
  final AuthUserData? user;
  final bool isPasswordRecovery;

  const AuthSessionSnapshot({
    this.user,
    this.isPasswordRecovery = false,
  });
}

class AuthRegistrationData {
  final String userId;
  final bool requiresEmailVerification;

  const AuthRegistrationData({
    required this.userId,
    required this.requiresEmailVerification,
  });
}

abstract interface class IAuthRepository {
  AuthUserData? get currentUser;

  Stream<AuthSessionSnapshot> get authStateChanges;

  Future<AuthRegistrationData> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String currency,
  });

  Future<AuthUserData> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  Future<void> sendMagicLink({required String email});

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> resendEmailVerification({required String email});

  Future<void> updatePassword({required String newPassword});

  Future<void> signOut({bool allSessions = false});
}

class RepositoryEmailAlreadyExistsException implements Exception {
  const RepositoryEmailAlreadyExistsException();
}

class RepositoryInvalidCredentialsException implements Exception {
  const RepositoryInvalidCredentialsException();
}

class RepositoryEmailNotVerifiedException implements Exception {
  const RepositoryEmailNotVerifiedException();
}

class AuthRepository implements IAuthRepository {
  final supabase.SupabaseClient _client;
  final String authCallbackUrl;
  final String passwordResetCallbackUrl;

  AuthRepository(
      this._client, {
        required this.authCallbackUrl,
        required this.passwordResetCallbackUrl,
      });

  @override
  AuthUserData? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthSessionSnapshot> get authStateChanges {
    return _client.auth.onAuthStateChange.map(
          (state) => AuthSessionSnapshot(
        user: _mapUser(state.session?.user),
        isPasswordRecovery:
        state.event == supabase.AuthChangeEvent.passwordRecovery,
      ),
    );
  }

  @override
  Future<AuthRegistrationData> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String currency,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: authCallbackUrl,
        data: {
          'full_name': fullName.trim(),
          'currency': currency,
          'role': 'tourist',
        },
      );
      final user = response.user;
      if (user == null) {
        throw const supabase.AuthException(
          'Registration failed. Please try again.',
        );
      }
      return AuthRegistrationData(
        userId: user.id,
        requiresEmailVerification: user.emailConfirmedAt == null,
      );
    } on supabase.AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('already registered') ||
          message.contains('already exists')) {
        throw const RepositoryEmailAlreadyExistsException();
      }
      rethrow;
    }
  }

  @override
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
      if (user == null) {
        throw const RepositoryInvalidCredentialsException();
      }
      if (user.emailConfirmedAt == null) {
        await _client.auth.signOut();
        throw const RepositoryEmailNotVerifiedException();
      }
      return _mapUser(user)!;
    } on RepositoryInvalidCredentialsException {
      rethrow;
    } on RepositoryEmailNotVerifiedException {
      rethrow;
    } on supabase.AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('email not confirmed') ||
          message.contains('email not verified')) {
        throw const RepositoryEmailNotVerifiedException();
      }
      if (message.contains('invalid login credentials') ||
          message.contains('invalid credentials')) {
        throw const RepositoryInvalidCredentialsException();
      }
      rethrow;
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    final started = await _client.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: authCallbackUrl,
    );
    if (!started) {
      throw const supabase.AuthException(
        'Google sign-in could not be started.',
      );
    }
  }

  @override
  Future<void> sendMagicLink({required String email}) async {
    await _client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      emailRedirectTo: authCallbackUrl,
      shouldCreateUser: false,
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: passwordResetCallbackUrl,
    );
  }

  @override
  Future<void> resendEmailVerification({required String email}) async {
    await _client.auth.resend(
      type: supabase.OtpType.signup,
      email: email.trim().toLowerCase(),
      emailRedirectTo: authCallbackUrl,
    );
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    await _client.auth.updateUser(
      supabase.UserAttributes(password: newPassword),
    );
  }

  @override
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
      isEmailVerified: user.emailConfirmedAt != null,
      metadata: Map<String, dynamic>.from(user.userMetadata ?? const {}),
    );
  }
}
