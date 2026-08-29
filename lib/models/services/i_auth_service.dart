import 'package:flutter/foundation.dart';

import '../entities/user.dart';

class RegistrationResult {
  final bool requiresEmailVerification;

  const RegistrationResult({required this.requiresEmailVerification});
}

enum ProfileImageSource { gallery, camera }

class PersonalConstraintOptionData {
  final String id;
  final String category;
  final String name;
  final bool isSelected;

  const PersonalConstraintOptionData({
    required this.id,
    required this.category,
    required this.name,
    required this.isSelected,
  });
}

/// Public User Management contract used by this module and other TREK modules.
abstract class IAuthService extends ChangeNotifier {
  bool get isLoggedIn;

  String? get currentUserId;

  User? get currentUser;

  bool get isPasswordRecovery;

  Future<void> restoreSession();

  Future<RegistrationResult> register({
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

  Future<List<String>> getSupportedCurrencies();

  Future<void> updateCurrentProfile({
    required String fullName,
    required String currency,
  });

  Future<String?> updateProfilePicture(ProfileImageSource source);

  Future<void> removeProfilePicture();

  Future<List<PersonalConstraintOptionData>>
  loadPersonalConstraintOptions();

  Future<void> savePersonalConstraints(List<String> constraintIds);

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

class ProfileImageTooLargeException implements Exception {
  const ProfileImageTooLargeException();
}

class ProfileInvalidImageFormatException implements Exception {
  const ProfileInvalidImageFormatException();
}
