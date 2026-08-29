import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../utils/id_generator.dart';
import '../configurations/frankfurter_api_config.dart';
import '../entities/personal_constraint.dart';
import '../entities/user.dart';
import 'auth_repository.dart';
import 'i_user_repository.dart';

class UserRepository implements IUserRepository {
  final supabase.SupabaseClient _client;
  final AuthRepository _authRepository;

  UserRepository(this._client, this._authRepository);

  static const String _usersTable = 'user';
  static const String _constraintsTable = 'personal_constraints';
  static const String _userConstraintsTable = 'user_constraints';
  static const String _profilePicturesBucket = 'profile-pictures';
  static const String _userIdPrefix = 'US';

  @override
  AuthUserData? get currentAuthUser => _authRepository.currentUser;

  @override
  Stream<AuthSessionSnapshot> get authStateChanges =>
      _authRepository.authStateChanges;

  @override
  Future<AuthRegistrationData> signUpWithEmail({
    required String email,
    required String password,
    required String currency,
  }) {
    return _authRepository.signUpWithEmail(
      email: email,
      password: password,
      currency: currency,
    );
  }

  @override
  Future<AuthUserData> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() => _authRepository.signInWithGoogle();

  @override
  Future<void> sendMagicLink({required String email}) =>
      _authRepository.sendMagicLink(email: email);

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      _authRepository.sendPasswordResetEmail(email: email);

  @override
  Future<void> updatePassword({
    required String newPassword,
    String? currentPassword,
  }) {
    return _authRepository.updatePassword(
      newPassword: newPassword,
      currentPassword: currentPassword,
    );
  }

  @override
  Future<void> signOut({bool allSessions = false}) =>
      _authRepository.signOut(allSessions: allSessions);

  @override
  Future<bool> completeDeferredEmailVerification() async {
    final result = await _client.rpc('complete_email_verification');
    return result == true;
  }

  @override
  Future<List<String>> getSupportedCurrencies() {
    return FrankfurterApiConfig.getCurrencyCodes();
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

  @override
  Future<User?> getUserProfileByAuthId(String authUserId) async {
    final row = await _client
        .from(_usersTable)
        .select()
        .eq('auth_id', authUserId)
        .maybeSingle();
    if (row == null) return null;

    final userId = row['user_id'] as String;
    final constraints = await getUserConstraints(userId);
    return User.fromMap(row, constraints: constraints);
  }

  @override
  Future<void> createUserProfile(User user) async {
    final existingProfile = await getUserProfileByAuthId(user.authId);
    if (existingProfile != null) return;

    if (user.userId.trim().isNotEmpty) {
      await _insertUser(user, user.userId);
      return;
    }

    // IdGenerator is retained from the shared TREK data-source implementation.
    // The database function exposes only the last formatted ID, and collisions
    // are retried so simultaneous registrations do not overwrite each other.
    for (var attempt = 0; attempt < 4; attempt++) {
      final lastIdValue = await _client.rpc('get_last_trek_user_id');
      final nextId = IdGenerator.generateNextFormattedId(
        _userIdPrefix,
        lastIdValue?.toString(),
      );
      try {
        await _insertUser(user, nextId);
        return;
      } on supabase.PostgrestException catch (error) {
        if (error.code != '23505') rethrow;

        // A concurrent auth-state callback may already have created the same
        // user's profile. In that case profile creation is complete. A
        // collision only on the formatted TREK ID is retried with the next ID.
        final concurrentlyCreated = await getUserProfileByAuthId(user.authId);
        if (concurrentlyCreated != null) return;
        if (attempt == 3) rethrow;
      }
    }
  }

  Future<void> _insertUser(User user, String userId) async {
    final values = user.toInsertMap()
      ..['user_id'] = userId
      ..['auth_id'] = user.authId;
    await _client.from(_usersTable).insert(values);
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
      fileOptions: supabase.FileOptions(
        upsert: false,
        contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
        cacheControl: '3600',
      ),
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
  Future<void> removeProfilePicture({required String userId}) async {
    final storedPictures = await _client.storage
        .from(_profilePicturesBucket)
        .list(path: userId);
    final storagePaths = storedPictures
        .where((picture) => picture.name.isNotEmpty)
        .map((picture) => '$userId/${picture.name}')
        .toList(growable: false);

    if (storagePaths.isNotEmpty) {
      await _client.storage
          .from(_profilePicturesBucket)
          .remove(storagePaths);
    }

    await _client.from(_usersTable).update({
      'profile_picture': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);
  }

  @override
  Future<List<PersonalConstraint>> getAllPersonalConstraints() async {
    final rows = await _client
        .from(_constraintsTable)
        .select()
        .order('category')
        .order('constraint_name');
    return (rows as List<dynamic>)
        .map(
          (row) => PersonalConstraint.fromMap(
        Map<String, dynamic>.from(row as Map),
      ),
    )
        .toList(growable: false);
  }

  @override
  Future<List<PersonalConstraint>> getUserConstraints(String userId) async {
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
        .map(
          (constraint) => PersonalConstraint.fromMap(
        Map<String, dynamic>.from(constraint),
      ),
    )
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

  static LoginLockStatus _parseLockStatus(Object? value) {
    if (value is! Map) {
      return const LoginLockStatus(failedAttempts: 0);
    }
    final map = Map<String, dynamic>.from(value);
    final lockedUntilValue = map['locked_until']?.toString();
    return LoginLockStatus(
      failedAttempts: (map['failed_attempts'] as num?)?.toInt() ?? 0,
      lockedUntil: lockedUntilValue == null
          ? null
          : DateTime.tryParse(lockedUntilValue)?.toLocal(),
    );
  }
}
