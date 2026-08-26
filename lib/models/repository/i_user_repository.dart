import 'dart:io';

import '../entities/personal_constraint.dart';
import '../entities/user.dart';

/// Lockout data returned by secure Supabase database functions.
class LoginLockStatus {
  final int failedAttempts;
  final DateTime? lockedUntil;

  const LoginLockStatus({
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());
}

/// Data-access contract for public user-management tables and storage.
/// Supabase Auth operations are deliberately kept in [AuthRepository].
abstract interface class IUserRepository {
  Future<bool> isEmailRegistered(String email);

  Future<User?> getUserProfileById(String userId);

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

  Future<List<PersonalConstraint>> getAllPersonalConstraints();

  Future<List<PersonalConstraint>> getUserConstraints(String userId);

  Future<void> replaceUserConstraints({
    required String userId,
    required List<String> constraintIds,
  });

  Future<LoginLockStatus> getLoginLockStatus(String email);

  Future<LoginLockStatus> recordFailedLoginAttempt(String email);

  Future<void> resetFailedLoginAttempts(String userId);
}

