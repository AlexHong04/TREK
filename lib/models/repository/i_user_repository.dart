import 'dart:io';

import '../entities/personal_constraint.dart';
import '../entities/user.dart';

class AuthUserData {
  final String id;
  final String email;
  final Map<String, dynamic> metadata;
  final String provider;

  const AuthUserData({
    required this.id,
    required this.email,
    required this.provider,
    this.metadata = const {},
  });

  bool get isTrustedOAuthProvider => provider != 'email';
}

class AuthSessionSnapshot {
  final AuthUserData? user;
  final bool isPasswordRecovery;
  final bool isSignedInEvent;

  const AuthSessionSnapshot({
    this.user,
    this.isPasswordRecovery = false,
    this.isSignedInEvent = false,
  });
}

class AuthRegistrationData {
  final String userId;

  const AuthRegistrationData({required this.userId});
}

class LoginLockStatus {
  final int failedAttempts;
  final DateTime? lockedUntil;

  const LoginLockStatus({
    required this.failedAttempts,
    this.lockedUntil,
  });

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());
}

class RepositoryEmailAlreadyExistsException implements Exception {
  const RepositoryEmailAlreadyExistsException();
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

/// Complete data-access contract used by the User Management services.
///
/// UserRepository implements this contract and delegates Supabase Auth work to
/// AuthRepository internally. Services therefore never depend on a concrete
/// repository or on a second repository interface.
abstract interface class IUserRepository {
  AuthUserData? get currentAuthUser;

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

  Future<void> sendMagicLink({required String email});

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> updatePassword({
    required String newPassword,
    String? currentPassword,
  });

  Future<void> signOut({bool allSessions = false});

  Future<bool> completeDeferredEmailVerification();

  Future<List<String>> getSupportedCurrencies();

  Future<double?> convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  });

  Future<LoginLockStatus> getLoginLockStatus(String email);

  Future<LoginLockStatus> recordFailedLoginAttempt(String email);

  Future<void> resetFailedLoginAttempts(String userId);

  Future<User?> getUserProfileByAuthId(String authUserId);

  Future<void> createUserProfile(User user);

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String currency,
  });

  Future<String> uploadAndSetProfilePicture({
    required String userId,
    required File imageFile,
  });

  Future<void> removeProfilePicture({required String userId});

  Future<List<PersonalConstraint>> getAllPersonalConstraints();

  Future<List<PersonalConstraint>> getUserConstraints(String userId);

  Future<void> replaceUserConstraints({
    required String userId,
    required List<String> constraintIds,
  });
}
