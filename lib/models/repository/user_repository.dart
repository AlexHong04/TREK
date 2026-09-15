import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../configurations/frankfurter_api_config.dart';
import '../entities/personal_constraint.dart';
import '../entities/user.dart';
import '../../utils/id_generator.dart';
import 'i_user_repository.dart';

class UserRepository implements IUserRepository {
  final supabase.SupabaseClient _client;
  final SharedPreferencesAsync _preferences;

  UserRepository(
      this._client, {
        SharedPreferencesAsync? preferences,
      }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _usersTable = 'user';
  static const String _constraintsTable = 'personal_constraints';
  static const String _userConstraintsTable = 'user_constraints';
  static const String _profilePicturesBucket = 'profile-pictures';
  static const String _userIdPrefix = 'US';
  static const int _maxCachedPictureBytes = 5 * 1024 * 1024;
  static const String _profileCacheKeyPrefix = 'trek.profile.';
  static const String _profileUserIdKeyPrefix = 'trek.profile_user_id.';
  static const String _allConstraintsCacheKey = 'trek.constraints.all';
  static const String _userConstraintsCacheKeyPrefix =
      'trek.constraints.user.';

  @override
  Future<bool> completeEmailVerification() async {
    try {
      final result = await _client.rpc('complete_email_verification');
      return result == true;
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Future<AccountAccessData> getCurrentAccountAccess() async {
    try {
      final value = await _client.rpc('get_current_account_access');
      if (value is! Map) {
        throw const FormatException('Invalid account-access response.');
      }
      final map = Map<String, dynamic>.from(value);
      final serverTime = _parseDate(map['server_time']) ?? DateTime.now().toUtc();
      final deadline = _parseDate(map['verification_deadline_at']) ?? serverTime;
      return AccountAccessData(
        serverTime: serverTime,
        verificationDeadline: deadline,
        isEmailVerified: map['is_email_verified'] == true,
        requiresVerification: map['requires_verification'] == true,
        verificationDaysRemaining:
        (map['verification_days_remaining'] as num?)?.toInt() ?? 0,
        accountStatus: _parseAccountStatus(map['account_status']),
        hasPasswordSignIn: map['has_password_sign_in'] == true,
      );
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Stream<User?> watchUserProfileByAuthId(String authUserId) {
    return _client
        .from(_usersTable)
        .stream(primaryKey: const ['user_id'])
        .eq('auth_id', authUserId)
        .asyncMap((rows) async {
      if (rows.isEmpty) return null;
      var user = User.fromMap(Map<String, dynamic>.from(rows.first));
      final cached = await getCachedUserProfileByAuthId(authUserId);
      if (cached?.profilePicture == user.profilePicture) {
        user = user.copyWith(
          cachedProfilePicturePath: cached?.cachedProfilePicturePath,
          personalConstraints:
          cached?.personalConstraints ?? const <PersonalConstraint>[],
        );
      }
      await cacheUserProfile(user);
      return user;
    });
  }

  @override
  Future<User?> getUserProfileByAuthId(String authUserId) async {
    try {
      final row = await _client
          .from(_usersTable)
          .select()
          .eq('auth_id', authUserId)
          .maybeSingle();
      if (row == null) return null;

      final userId = row['user_id'] as String;
      final constraints = await getUserConstraints(userId);
      var user = User.fromMap(row, constraints: constraints);
      user = await _withCachedProfilePicture(user);
      await _writeUserCache(user);
      return user;
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Future<User?> getCachedUserProfileByAuthId(String authUserId) async {
    final value = await _preferences.getString(_profileKey(authUserId));
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      var user = User.fromCacheMap(Map<String, dynamic>.from(decoded));
      if (user.authId != authUserId) return null;
      final path = user.cachedProfilePicturePath;
      if (path != null && !await File(path).exists()) {
        user = user.copyWith(clearCachedProfilePicture: true);
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cacheUserProfile(User user) async {
    final withPicture = await _withCachedProfilePicture(user);
    await _writeUserCache(withPicture);
  }

  @override
  Future<void> clearCachedUserProfile(String authUserId) async {
    final cached = await getCachedUserProfileByAuthId(authUserId);
    final mappedUserId =
    await _preferences.getString('$_profileUserIdKeyPrefix$authUserId');
    await _preferences.remove(_profileKey(authUserId));
    await _preferences.remove('$_profileUserIdKeyPrefix$authUserId');
    final userId = cached?.userId ?? mappedUserId;
    if (userId != null && userId.isNotEmpty) {
      await _preferences.remove('$_userConstraintsCacheKeyPrefix$userId');
    }
    final path = cached?.cachedProfilePicturePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> createUserProfile(User user) async {
    final existingProfile = await getUserProfileByAuthId(user.authId);
    if (existingProfile != null) return;

    if (user.userId.trim().isNotEmpty) {
      await _insertUser(user, user.userId);
      return;
    }

    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final lastIdValue = await _client.rpc('get_last_trek_user_id');
        final nextId = IdGenerator.generateNextFormattedId(
          _userIdPrefix,
          lastIdValue?.toString(),
        );
        await _insertUser(user, nextId);
        return;
      } on supabase.PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        final concurrentlyCreated = await getUserProfileByAuthId(user.authId);
        if (concurrentlyCreated != null) return;
        if (attempt == 3) rethrow;
      } catch (error) {
        rethrowAsNetworkUnavailable<void>(error);
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
  Future<LoginLockStatus> getLoginLockStatus(String email) async {
    try {
      final result = await _client.rpc(
        'get_login_lock_status',
        params: {'email_input': InputValidator.normalizeEmail(email)},
      );
      return _parseLockStatus(result);
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Future<LoginLockStatus> recordFailedLoginAttempt(String email) async {
    try {
      final result = await _client.rpc(
        'record_failed_login_attempt',
        params: {'email_input': InputValidator.normalizeEmail(email)},
      );
      return _parseLockStatus(result);
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Future<void> resetFailedLoginAttempts(String userId) async {
    try {
      await _client.rpc(
        'reset_failed_login_attempts',
        params: {'user_id_input': userId},
      );
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  Future<List<String>> getSupportedCurrencies() {
    return FrankfurterApiConfig.getCurrencyCodes();
  }

  @override
  Future<double?> convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (!amount.isFinite) {
      throw ArgumentError.value(amount, 'amount', 'Must be a finite number.');
    }
    final from = fromCurrency.trim().toUpperCase();
    final to = toCurrency.trim().toUpperCase();
    if (from.isEmpty || to.isEmpty) {
      throw ArgumentError('Both currency codes are required.');
    }
    if (from == to) return amount;
    final rate = await FrankfurterApiConfig.getRate(
      fromCurrency: from,
      toCurrency: to,
    );
    return rate == null ? null : amount * rate;
  }

  @override
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String currency,
  }) async {
    try {
      final updatedRow = await _client.from(_usersTable).update({
        'full_name': InputValidator.normalizeDisplayName(fullName),
        'currency': currency.trim().toUpperCase(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId).select('user_id').maybeSingle();
      if (updatedRow == null) {
        throw StateError('The profile update was not permitted.');
      }
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  Future<String> uploadAndSetProfilePicture({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final previousPictures = await _client.storage
          .from(_profilePicturesBucket)
          .list(path: userId);
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
      final updatedRow = await _client.from(_usersTable).update({
        'profile_picture': publicUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId).select('user_id').maybeSingle();
      if (updatedRow == null) {
        try {
          await _client.storage
              .from(_profilePicturesBucket)
              .remove([storagePath]);
        } catch (_) {
          // Keep the original permission error if cleanup also fails.
        }
        throw StateError('The profile picture update was not permitted.');
      }
      final oldPaths = previousPictures
          .where((picture) => picture.name.isNotEmpty)
          .map((picture) => '$userId/${picture.name}')
          .toList(growable: false);
      if (oldPaths.isNotEmpty) {
        try {
          await _client.storage.from(_profilePicturesBucket).remove(oldPaths);
        } catch (_) {
          // The profile already points to the new image. Any rare orphan is
          // still removed by the server-side account-deletion flow.
        }
      }
      return publicUrl;
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Future<void> removeProfilePicture({required String userId}) async {
    try {
      final storedPictures = await _client.storage
          .from(_profilePicturesBucket)
          .list(path: userId);
      final paths = storedPictures
          .where((picture) => picture.name.isNotEmpty)
          .map((picture) => '$userId/${picture.name}')
          .toList(growable: false);
      if (paths.isNotEmpty) {
        await _client.storage.from(_profilePicturesBucket).remove(paths);
      }
      final updatedRow = await _client.from(_usersTable).update({
        'profile_picture': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId).select('user_id').maybeSingle();
      if (updatedRow == null) {
        throw StateError('The profile picture update was not permitted.');
      }
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  Future<List<PersonalConstraint>> getAllPersonalConstraints() async {
    try {
      final rows = await _client
          .from(_constraintsTable)
          .select()
          .order('category')
          .order('constraint_name');
      final constraints = (rows as List<dynamic>)
          .map(
            (row) => PersonalConstraint.fromMap(
          Map<String, dynamic>.from(row as Map),
        ),
      )
          .toList(growable: false);
      await _preferences.setString(
        _allConstraintsCacheKey,
        jsonEncode(constraints.map(_constraintMap).toList()),
      );
      return constraints;
    } catch (error) {
      if (isNetworkUnavailable(error)) {
        final cached = await _readConstraintsCache(_allConstraintsCacheKey);
        if (cached.isNotEmpty) return cached;
        throw const NetworkUnavailableException();
      }
      rethrow;
    }
  }

  @override
  Future<List<PersonalConstraint>> getUserConstraints(String userId) async {
    final cacheKey = '$_userConstraintsCacheKeyPrefix$userId';
    try {
      final rows = await _client
          .from(_userConstraintsTable)
          .select(
        'personal_constraints(constraint_id, category, constraint_name)',
      )
          .eq('user_id', userId);
      final constraints = (rows as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) => row['personal_constraints'])
          .whereType<Map>()
          .map(
            (constraint) => PersonalConstraint.fromMap(
          Map<String, dynamic>.from(constraint),
        ),
      )
          .toList(growable: false);
      await _preferences.setString(
        cacheKey,
        jsonEncode(constraints.map(_constraintMap).toList()),
      );
      return constraints;
    } catch (error) {
      if (isNetworkUnavailable(error)) {
        return _readConstraintsCache(cacheKey);
      }
      rethrow;
    }
  }

  @override
  Future<void> replaceUserConstraints({
    required String userId,
    required List<String> constraintIds,
  }) async {
    try {
      await _client.rpc(
        'replace_user_constraints',
        params: {
          'user_id_input': userId,
          'constraint_ids_input': constraintIds,
        },
      );
      final fresh = await getUserConstraints(userId);
      await _preferences.setString(
        '$_userConstraintsCacheKeyPrefix$userId',
        jsonEncode(fresh.map(_constraintMap).toList()),
      );
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  Future<User> _withCachedProfilePicture(User user) async {
    final url = user.profilePicture;
    if (url == null || url.isEmpty) {
      return user.copyWith(clearCachedProfilePicture: true);
    }
    final previous = await getCachedUserProfileByAuthId(user.authId);
    final previousPath = previous?.cachedProfilePicturePath;
    if (previous?.profilePicture == url &&
        previousPath != null &&
        await File(previousPath).exists()) {
      return user.copyWith(cachedProfilePicturePath: previousPath);
    }

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      final contentType = response.headers['content-type']?.toLowerCase();
      final supportedContentType = contentType?.contains('image/jpeg') == true ||
          contentType?.contains('image/png') == true;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          !supportedContentType ||
          response.bodyBytes.length > _maxCachedPictureBytes) {
        return user.copyWith(clearCachedProfilePicture: true);
      }
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/trek/profile_cache');
      await directory.create(recursive: true);
      final extension = _pictureExtension(contentType, url);
      // Include the remote object's versioned filename in the local path. A
      // stable auth-id-only path can be retained by Flutter's ImageCache after
      // its bytes are overwritten, leaving Home/Profile on the previous photo.
      final cacheName = _profilePictureCacheName(
        authId: user.authId,
        url: url,
        extension: extension,
      );
      final file = File('${directory.path}/$cacheName');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (previousPath != null && previousPath != file.path) {
        final oldFile = File(previousPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
      return user.copyWith(cachedProfilePicturePath: file.path);
    } catch (_) {
      return user.copyWith(clearCachedProfilePicture: true);
    }
  }

  Future<void> _writeUserCache(User user) async {
    await _preferences.setString(
      _profileKey(user.authId),
      jsonEncode(user.toCacheMap()),
    );
    await _preferences.setString(
      '$_profileUserIdKeyPrefix${user.authId}',
      user.userId,
    );
  }

  Future<List<PersonalConstraint>> _readConstraintsCache(String key) async {
    final value = await _preferences.getString(key);
    if (value == null) return const [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => PersonalConstraint.fromMap(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic> _constraintMap(PersonalConstraint item) => {
    'constraint_id': item.constraintId,
    'category': item.category,
    'constraint_name': item.constraintName,
  };

  static String _pictureExtension(String? contentType, String url) {
    if (contentType?.toLowerCase().contains('png') == true ||
        Uri.tryParse(url)?.path.toLowerCase().endsWith('.png') == true) {
      return 'png';
    }
    return 'jpg';
  }

  static String _profilePictureCacheName({
    required String authId,
    required String url,
    required String extension,
  }) {
    final uri = Uri.tryParse(url);
    final remoteName = uri != null && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : '';
    final stem = remoteName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final safeStem = stem.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final version = safeStem.isEmpty
        ? url.hashCode.toUnsigned(32).toRadixString(16)
        : safeStem;
    return '${authId}_$version.$extension';
  }

  static String _profileKey(String authUserId) =>
      '$_profileCacheKeyPrefix$authUserId';

  static LoginLockStatus _parseLockStatus(Object? value) {
    if (value is! Map) return const LoginLockStatus(failedAttempts: 0);
    final map = Map<String, dynamic>.from(value);
    return LoginLockStatus(
      failedAttempts: (map['failed_attempts'] as num?)?.toInt() ?? 0,
      lockedUntil: _parseDate(map['locked_until'])?.toLocal(),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  static TrekAccountStatus _parseAccountStatus(Object? value) {
    switch (value?.toString()) {
      case 'deletion_pending':
        return TrekAccountStatus.deletionPending;
      case 'deletion_email_confirmed':
        return TrekAccountStatus.deletionEmailConfirmed;
      default:
        return TrekAccountStatus.active;
    }
  }
}
