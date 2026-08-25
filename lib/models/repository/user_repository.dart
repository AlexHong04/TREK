import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../entities/personal_constraint.dart';
import '../entities/user.dart';
import 'i_user_repository.dart';

class UserRepository implements IUserRepository {
  final supabase.SupabaseClient _client;

  UserRepository(this._client);

  static const String _usersTable = 'users';
  static const String _constraintsTable = 'personal_constraints';
  static const String _userConstraintsTable = 'user_constraints';
  static const String _profilePicturesBucket = 'profile-pictures';

  @override
  Future<bool> isEmailRegistered(String email) async {
    final result = await _client.rpc(
      'is_email_registered',
      params: {'email_input': email.trim().toLowerCase()},
    );
    if (result is bool) return result;
    return _firstRow(result)?['is_registered'] == true;
  }

  @override
  Future<User?> getUserProfileById(String userId) async {
    final row = await _client
        .from(_usersTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;

    final constraints = await getUserConstraints(userId);
    return User.fromMap(row, constraints: constraints);
  }

  @override
  Future<void> createUserProfile(User user) async {
    await _client
        .from(_usersTable)
        .upsert(user.toInsertMap(), onConflict: 'user_id');
  }

  @override
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String currency,
  }) async {
    await _client.from(_usersTable).update({
      'full_name': fullName.trim(),
      'currency': currency,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);
  }

  @override
  Future<String> uploadAndSetProfilePicture({
    required String userId,
    required File imageFile,
  }) async {
    final extension = imageFile.path.split('.').last.toLowerCase();
    final storagePath =
        '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final bytes = await imageFile.readAsBytes();

    await _client.storage.from(_profilePicturesBucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: const supabase.FileOptions(upsert: false),
    );
    final publicUrl = _client.storage
        .from(_profilePicturesBucket)
        .getPublicUrl(storagePath);

    await _client.from(_usersTable).update({
      'profile_picture': publicUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);
    return publicUrl;
  }

  @override
  Future<List<PersonalConstraint>> getAllPersonalConstraints() async {
    final rows = await _client
        .from(_constraintsTable)
        .select()
        .order('category')
        .order('constraint_name');
    return (rows as List<dynamic>)
        .map((row) => PersonalConstraint.fromMap(
      Map<String, dynamic>.from(row as Map),
    ))
        .toList(growable: false);
  }

  @override
  Future<List<PersonalConstraint>> getUserConstraints(
      String userId,
      ) async {
    final rows = await _client
        .from(_userConstraintsTable)
        .select(
      'personal_constraints(constraint_id, category, constraint_name)',
    )
        .eq('user_id', userId);

    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map((row) => row['personal_constraints'])
        .whereType<Map>()
        .map((constraint) => PersonalConstraint.fromMap(
      Map<String, dynamic>.from(constraint),
    ))
        .toList(growable: false);
  }

  @override
  Future<void> replaceUserConstraints({
    required String userId,
    required List<String> constraintIds,
  }) async {
    await _client.rpc(
      'replace_user_constraints',
      params: {
        'user_id_input': userId,
        'constraint_ids_input': constraintIds,
      },
    );
  }

  @override
  Future<LoginLockStatus> getLoginLockStatus(String email) async {
    final result = await _client.rpc(
      'get_login_lock_status',
      params: {'email_input': email.trim().toLowerCase()},
    );
    return _parseLockStatus(result);
  }

  @override
  Future<LoginLockStatus> recordFailedLoginAttempt(String email) async {
    final result = await _client.rpc(
      'record_failed_login_attempt',
      params: {'email_input': email.trim().toLowerCase()},
    );
    return _parseLockStatus(result);
  }

  @override
  Future<void> resetFailedLoginAttempts(String userId) async {
    await _client.rpc(
      'reset_failed_login_attempts',
      params: {'user_id_input': userId},
    );
  }

  static LoginLockStatus _parseLockStatus(dynamic value) {
    final row = _firstRow(value);
    if (row == null) return const LoginLockStatus();
    final lockedUntil = row['locked_until'];
    return LoginLockStatus(
      failedAttempts:
      ((row['failed_attempts'] ?? row['failed_login_attempts']) as num?)
          ?.toInt() ??
          0,
      lockedUntil: lockedUntil is String
          ? DateTime.tryParse(lockedUntil)?.toLocal()
          : null,
    );
  }

  static Map<String, dynamic>? _firstRow(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }
}
