class AuthIdentityData {
  final String id;
  final String provider;
  final String? email;

  const AuthIdentityData({
    required this.id,
    required this.provider,
    this.email,
  });
}

class AuthUserData {
  final String id;
  final String email;
  final Map<String, dynamic> metadata;
  final Map<String, String> providerEmails;
  final Set<String> providers;
  final DateTime createdAt;

  const AuthUserData({
    required this.id,
    required this.email,
    required this.providers,
    required this.createdAt,
    this.metadata = const {},
    this.providerEmails = const {},
  });

  bool get hasPasswordIdentity => providers.contains('email');

  bool get hasGoogleIdentity => providers.contains('google');

  bool get hasTrustedOAuthIdentity =>
      providers.any((provider) => provider != 'email');
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

  const AuthRegistrationData({required this.userId});
}

enum PasswordRecoveryStatus { pending, ready, expired, completed }

class RepositoryEmailAlreadyExistsException implements Exception {
  const RepositoryEmailAlreadyExistsException();
}

class RepositoryEmailChangeException implements Exception {
  final String message;

  const RepositoryEmailChangeException(this.message);
}

class RepositoryInvalidCredentialsException implements Exception {
  const RepositoryInvalidCredentialsException();
}

class RepositoryIncorrectCurrentPasswordException implements Exception {
  const RepositoryIncorrectCurrentPasswordException();
}

class RepositorySamePasswordException implements Exception {
  const RepositorySamePasswordException();
}

class RepositoryRecentAuthenticationRequiredException implements Exception {
  const RepositoryRecentAuthenticationRequiredException();
}

class RepositoryIdentityUnavailableException implements Exception {
  const RepositoryIdentityUnavailableException();
}

class RepositoryIdentityAlreadyLinkedException implements Exception {
  const RepositoryIdentityAlreadyLinkedException();
}

class RepositoryManualIdentityLinkingDisabledException implements Exception {
  const RepositoryManualIdentityLinkingDisabledException();
}

class RepositoryAccountDeletionException implements Exception {
  final String message;

  const RepositoryAccountDeletionException(this.message);
}

class RepositoryAccountDeletionNotConfirmedException implements Exception {
  const RepositoryAccountDeletionNotConfirmedException();
}

/// Pure authentication/account gateway implemented only by AuthRepository.
/// `abstract interface class` is Dart's interface-only syntax; it contains no
/// shared implementation and creates no inheritance between repositories.
abstract interface class IAuthRepository {
  AuthUserData? get currentUser;

  Stream<AuthSessionSnapshot> get authStateChanges;

  Future<AuthRegistrationData> signUpWithEmail({
    required String email,
    required String password,
    required String currency,
  });

  Future<AuthUserData> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  Future<void> linkGoogleIdentity();

  Future<void> sendMagicLink({required String email});

  Future<void> sendPasswordResetEmail({required String email});

  Future<bool> hasPendingPasswordRecovery();

  Future<PasswordRecoveryStatus> getPendingPasswordRecoveryStatus();

  Future<void> completePendingPasswordRecovery({required String newPassword});

  Future<void> clearPendingPasswordRecovery();

  Future<void> updatePassword({
    required String newPassword,
    String? currentPassword,
  });

  Future<void> requestAccountEmailChange({
    required String newEmail,
  });

  Future<AuthUserData> reauthenticateWithPassword({
    required String email,
    required String password,
  });

  Future<List<AuthIdentityData>> getUserIdentities();

  Future<void> unlinkGoogleIdentity();

  bool hasRecentOAuthAuthentication({
    Duration maximumAge = const Duration(minutes: 10),
  });

  Future<void> refreshSession();

  /// Returns true when the email-confirmation step can be skipped because the
  /// account email is not verified.
  Future<bool> requestAccountDeletion({
    required bool skipEmailConfirmation,
  });

  Future<void> permanentlyDeleteAccount();

  Future<void> cancelAccountDeletion();

  Future<void> signOut({bool allSessions = false});
}
