import 'package:flutter/foundation.dart';

import '../entities/user.dart';

class RegistrationResult {
  final bool requiresEmailVerification;

  const RegistrationResult({required this.requiresEmailVerification});
}

/// Public User Management contract used by this module and other TREK modules.
abstract class IAuthService extends ChangeNotifier {
  bool get isLoggedIn;

  String? get currentUserId;

  User? get currentUser;

  bool get isPasswordRecovery;

  Future<void> restoreSession();

  Future<RegistrationResult> register({
    required String fullName,
    required String email,
    required String password,
    required String currency,
  });

  Future<void> login({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  Future<void> sendMagicLinkForLockedAccount({required String email});

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> setNewPassword({required String newPassword});

  Future<void> resendVerificationEmail({required String email});

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> refreshCurrentUser();

  Future<void> logout();
}

class EmailAlreadyExistsException implements Exception {
  const EmailAlreadyExistsException();
}

class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();
}

class AccountLockedException implements Exception {
  final DateTime? lockedUntil;

  const AccountLockedException({this.lockedUntil});
}

class EmailNotVerifiedException implements Exception {
  const EmailNotVerifiedException();
}

class IncorrectCurrentPasswordException implements Exception {
  const IncorrectCurrentPasswordException();
}

class PasswordReusedException implements Exception {
  const PasswordReusedException();
}
