import 'package:flutter/foundation.dart';

import '../entities/user.dart';

enum AuthDestination {
  signedOut,
  normalApp,
  verificationRequired,
  passwordRecovery,
  deletionConfirmation,
}

class RegistrationResult {
  final bool requiresEmailVerification;
  final bool verificationEmailSent;

  const RegistrationResult({
    required this.requiresEmailVerification,
    required this.verificationEmailSent,
  });
}

class AccountInfo {
  final String accountEmail;
  final String? googleEmail;
  final bool hasPasswordSignIn;
  final bool hasEmailIdentity;
  final bool hasGoogleIdentity;
  final bool isEmailVerified;
  final bool hasRecentOAuthAuthentication;

  const AccountInfo({
    required this.accountEmail,
    this.googleEmail,
    required this.hasPasswordSignIn,
    required this.hasEmailIdentity,
    required this.hasGoogleIdentity,
    required this.isEmailVerified,
    required this.hasRecentOAuthAuthentication,
  });

  bool get canUnlinkGoogle =>
      hasGoogleIdentity &&
          hasPasswordSignIn &&
          hasEmailIdentity &&
          isEmailVerified;

  /// Google created this Auth user and remains its only linked identity.
  bool get isGoogleManagedAccount => hasGoogleIdentity && !hasEmailIdentity;
}

/// Public authentication/account contract implemented only by AuthService.
/// It is a Listenable so Provider can rebuild consumers without coupling them
/// to the concrete ChangeNotifier implementation.
abstract interface class IAuthService implements Listenable {
  bool get isLoggedIn;

  bool get isPasswordRecovery;

  bool get isOffline;

  bool get requiresEmailVerification;

  int get verificationDaysRemaining;

  AuthDestination get destination;

  String? get currentUserId;

  User? get currentUser;

  AccountInfo? get accountInfo;

  Future<void> restoreSession();

  Future<RegistrationResult> register({
    required String email,
    required String password,
    required String currency,
  });

  Future<void> login({required String email, required String password});

  Future<void> signInWithGoogle();

  Future<void> linkGoogle();

  Future<void> sendMagicLinkForLockedAccount({required String email});

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> resendVerificationEmail({required String email});

  Future<void> setNewPasswordFromRecovery({required String newPassword});

  Future<void> setPasswordForOAuthUser({required String newPassword});

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> changeAccountEmail({
    required String newEmail,
    String? currentPassword,
  });

  Future<void> unlinkGoogle({required String currentPassword});

  /// Returns true when the app may open the final deletion confirmation now;
  /// false means the user must first confirm the email that was sent.
  Future<bool> requestAccountDeletion({String? currentPassword});

  Future<void> permanentlyDeleteAccount();

  Future<void> cancelAccountDeletion();

  Future<void> refreshCurrentUser();

  Future<void> onAppResumed();

  String? consumeSessionMessage();

  Future<void> logout();
}

class EmailAlreadyExistsException implements Exception {
  const EmailAlreadyExistsException();
}

class AccountEmailChangeException implements Exception {
  final String message;

  const AccountEmailChangeException(this.message);
}

class GoogleManagedAccountException implements Exception {
  const GoogleManagedAccountException();
}

class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();
}

class AccountLockedException implements Exception {
  final DateTime? lockedUntil;

  const AccountLockedException({this.lockedUntil});
}

class IncorrectCurrentPasswordException implements Exception {
  const IncorrectCurrentPasswordException();
}

class PasswordReusedException implements Exception {
  const PasswordReusedException();
}

class RecentAuthenticationRequiredException implements Exception {
  const RecentAuthenticationRequiredException();
}

class CannotUnlinkGoogleException implements Exception {
  const CannotUnlinkGoogleException();
}

class MissingEmailIdentityForGoogleUnlinkException implements Exception {
  const MissingEmailIdentityForGoogleUnlinkException();
}

class GoogleIdentityAlreadyLinkedException implements Exception {
  const GoogleIdentityAlreadyLinkedException();
}

class ManualIdentityLinkingDisabledException implements Exception {
  const ManualIdentityLinkingDisabledException();
}

class GoogleIdentityOperationInProgressException implements Exception {
  const GoogleIdentityOperationInProgressException();
}

class AccountDeletionNotConfirmedException implements Exception {
  const AccountDeletionNotConfirmedException();
}
