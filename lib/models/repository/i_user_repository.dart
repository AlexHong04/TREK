import 'dart:io';

import '../entities/personal_constraint.dart';
import '../entities/user.dart';

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

class AccountAccessData {
  final DateTime serverTime;
  final DateTime verificationDeadline;
  final bool isEmailVerified;
  final bool requiresVerification;
  final int verificationDaysRemaining;
  final TrekAccountStatus accountStatus;
  final bool hasPasswordSignIn;

  const AccountAccessData({
    required this.serverTime,
    required this.verificationDeadline,
    required this.isEmailVerified,
    required this.requiresVerification,
    required this.verificationDaysRemaining,
    required this.accountStatus,
    required this.hasPasswordSignIn,
  });
}

/// App-data gateway implemented only by UserRepository. Supabase Auth methods
/// deliberately live in IAuthRepository instead of being duplicated here.
abstract interface class IUserRepository {
  Future<bool> completeEmailVerification();

  Future<AccountAccessData> getCurrentAccountAccess();

  Stream<User?> watchUserProfileByAuthId(String authUserId);

  Future<User?> getUserProfileByAuthId(String authUserId);

  Future<User?> getCachedUserProfileByAuthId(String authUserId);

  Future<void> cacheUserProfile(User user);

  Future<void> clearCachedUserProfile(String authUserId);

  Future<void> createUserProfile(User user);

  Future<LoginLockStatus> getLoginLockStatus(String email);

  Future<LoginLockStatus> recordFailedLoginAttempt(String email);

  Future<void> resetFailedLoginAttempts(String userId);

  Future<List<String>> getSupportedCurrencies();

  Future<double?> convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  });

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
