import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';

import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import 'i_auth_repository.dart';

class AuthRepository implements IAuthRepository {
  final supabase.SupabaseClient _client;
  final String authCallbackUrl;
  final String passwordResetCallbackUrl;
  final FlutterSecureStorage _secureStorage;

  static const _recoveryRequestIdKey = 'trek.recovery.request_id';
  static const _recoveryDeviceSecretKey = 'trek.recovery.device_secret';

  AuthRepository(
      this._client, {
        required this.authCallbackUrl,
        required this.passwordResetCallbackUrl,
        FlutterSecureStorage? secureStorage,
      }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  AuthUserData? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthSessionSnapshot> get authStateChanges {
    return _client.auth.onAuthStateChange.map(
          (state) => AuthSessionSnapshot(
        user: _mapUser(state.session?.user),
        isPasswordRecovery:
        state.event == supabase.AuthChangeEvent.passwordRecovery,
      ),
    );
  }

  @override
  Future<AuthRegistrationData> signUpWithEmail({
    required String email,
    required String password,
    required String currency,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: InputValidator.normalizeEmail(email),
        password: password,
        data: {
          'currency': currency.trim().toUpperCase(),
          'role': 'tourist',
        },
      );
      final user = response.user;
      if (user == null || response.session == null) {
        throw const supabase.AuthException(
          'Registration did not create a session. TREK deferred verification '
              'requires Confirm email to be disabled in Supabase Auth settings.',
        );
      }
      return AuthRegistrationData(userId: user.id);
    } on supabase.AuthException catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      final message = error.message.toLowerCase();
      if (message.contains('already registered') ||
          message.contains('already exists') ||
          error.code == 'user_already_exists') {
        throw const RepositoryEmailAlreadyExistsException();
      }
      rethrow;
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Future<AuthUserData> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: InputValidator.normalizeEmail(email),
        password: password,
      );
      final user = response.user;
      if (user == null) throw const RepositoryInvalidCredentialsException();
      return _mapUser(user)!;
    } on RepositoryInvalidCredentialsException {
      rethrow;
    } on supabase.AuthException catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('invalid credentials') ||
          error.code == 'invalid_credentials') {
        throw const RepositoryInvalidCredentialsException();
      }
      rethrow;
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final started = await _client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: authCallbackUrl,
        queryParams: const {'prompt': 'select_account'},
        authScreenLaunchMode:
        kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
      );
      if (!started) {
        throw const supabase.AuthException(
          'Google sign-in could not be started.',
        );
      }
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  Future<void> linkGoogleIdentity() async {
    if (_client.auth.currentUser == null) {
      throw const RepositoryInvalidCredentialsException();
    }
    try {
      final started = await _client.auth.linkIdentity(
        supabase.OAuthProvider.google,
        redirectTo: authCallbackUrl,
        queryParams: const {'prompt': 'select_account'},
        authScreenLaunchMode:
        kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
      );
      if (!started) {
        throw const supabase.AuthException(
          'Google account linking could not be started.',
        );
      }
    } on supabase.AuthException catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      final code = error.code?.toLowerCase();
      final message = error.message.toLowerCase();
      if (code == 'identity_already_exists' ||
          message.contains('already linked') ||
          message.contains('already exists')) {
        throw const RepositoryIdentityAlreadyLinkedException();
      }
      if (code == 'manual_linking_disabled' ||
          message.contains('manual linking')) {
        throw const RepositoryManualIdentityLinkingDisabledException();
      }
      rethrow;
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  Future<void> sendMagicLink({required String email}) async {
    try {
      await _client.auth.signInWithOtp(
        email: InputValidator.normalizeEmail(email),
        emailRedirectTo: authCallbackUrl,
        shouldCreateUser: false,
      );
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    final deviceSecret = _randomSecret();
    try {
      final response = await _client.functions.invoke(
        'password-recovery',
        body: {
          'action': 'request',
          'email': InputValidator.normalizeEmail(email),
          'device_secret': deviceSecret,
        },
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300 ||
          data is! Map || data['request_id'] == null) {
        throw StateError(_responseMessage(data));
      }
      await _secureStorage.write(
        key: _recoveryRequestIdKey,
        value: data['request_id'].toString(),
      );
      await _secureStorage.write(
        key: _recoveryDeviceSecretKey,
        value: deviceSecret,
      );
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  Future<bool> hasPendingPasswordRecovery() async {
    final values = await Future.wait([
      _secureStorage.read(key: _recoveryRequestIdKey),
      _secureStorage.read(key: _recoveryDeviceSecretKey),
    ]);
    return values.every((value) => value?.isNotEmpty == true);
  }

  @override
  Future<PasswordRecoveryStatus> getPendingPasswordRecoveryStatus() async {
    final pending = await _pendingRecoveryValues();
    if (pending == null) return PasswordRecoveryStatus.expired;
    try {
      final response = await _client.functions.invoke(
        'password-recovery',
        body: {
          'action': 'status',
          'request_id': pending.$1,
          'device_secret': pending.$2,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError(_responseMessage(response.data));
      }
      final data = response.data;
      final status = data is Map
          ? data['status']?.toString()
          : null;
      return switch (status) {
        'ready' => PasswordRecoveryStatus.ready,
        'completed' => PasswordRecoveryStatus.completed,
        'expired' => PasswordRecoveryStatus.expired,
        _ => PasswordRecoveryStatus.pending,
      };
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Future<void> completePendingPasswordRecovery({
    required String newPassword,
  }) async {
    final pending = await _pendingRecoveryValues();
    if (pending == null) {
      throw StateError('The password-recovery request is no longer available.');
    }
    try {
      final response = await _client.functions.invoke(
        'password-recovery',
        body: {
          'action': 'complete',
          'request_id': pending.$1,
          'device_secret': pending.$2,
          'new_password': newPassword,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError(_responseMessage(response.data));
      }
      await clearPendingPasswordRecovery();
    } catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      rethrow;
    }
  }

  @override
  Future<void> clearPendingPasswordRecovery() async {
    await Future.wait([
      _secureStorage.delete(key: _recoveryRequestIdKey),
      _secureStorage.delete(key: _recoveryDeviceSecretKey),
    ]);
  }

  Future<(String, String)?> _pendingRecoveryValues() async {
    final requestId = await _secureStorage.read(key: _recoveryRequestIdKey);
    final secret = await _secureStorage.read(key: _recoveryDeviceSecretKey);
    if (requestId == null || requestId.isEmpty || secret == null || secret.isEmpty) {
      return null;
    }
    return (requestId, secret);
  }

  static String _randomSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  @override
  Future<void> updatePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(
          password: newPassword,
          currentPassword: currentPassword,
        ),
      );
    } on supabase.AuthException catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      final code = error.code?.toLowerCase();
      final message = error.message.toLowerCase();
      if (code == 'same_password' || message.contains('same password')) {
        throw const RepositorySamePasswordException();
      }
      if (code == 'invalid_credentials' ||
          message.contains('current password') ||
          message.contains('invalid login credentials')) {
        throw const RepositoryIncorrectCurrentPasswordException();
      }
      if (code == 'reauthentication_needed' ||
          message.contains('reauthentication')) {
        throw const RepositoryRecentAuthenticationRequiredException();
      }
      rethrow;
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  Future<void> requestAccountEmailChange({
    required String newEmail,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'request-email-correction',
        body: {'new_email': InputValidator.normalizeEmail(newEmail)},
      );
      if (response.status < 200 || response.status >= 300) {
        final message = _responseMessage(response.data);
        final normalizedMessage = message.toLowerCase();
        if (response.status == 409 &&
            (normalizedMessage.contains('email_exists') ||
                normalizedMessage.contains('already registered') ||
                normalizedMessage.contains('already in use'))) {
          throw const RepositoryEmailAlreadyExistsException();
        }
        if (response.status == 401 &&
            normalizedMessage.contains('recent')) {
          throw const RepositoryRecentAuthenticationRequiredException();
        }
        throw RepositoryEmailChangeException(message);
      }
    } on RepositoryEmailAlreadyExistsException {
      rethrow;
    } on RepositoryRecentAuthenticationRequiredException {
      rethrow;
    } on RepositoryEmailChangeException {
      rethrow;
    } catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      final message = error.toString().toLowerCase();
      if (message.contains('email_exists') ||
          message.contains('already registered')) {
        throw const RepositoryEmailAlreadyExistsException();
      }
      throw const RepositoryEmailChangeException(
        'Unable to request the email change. Please try again.',
      );
    }
  }

  @override
  Future<AuthUserData> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {
    final expectedUserId = _client.auth.currentUser?.id;
    if (expectedUserId == null) {
      throw const RepositoryInvalidCredentialsException();
    }
    final user = await signInWithEmail(email: email, password: password);
    if (user.id != expectedUserId) {
      await signOut();
      throw const RepositoryInvalidCredentialsException();
    }
    return user;
  }

  @override
  Future<List<AuthIdentityData>> getUserIdentities() async {
    try {
      final identities = await _client.auth.getUserIdentities();
      return identities
          .map(
            (identity) => AuthIdentityData(
          id: identity.id,
          provider: identity.provider,
          email: identity.identityData?['email']?.toString(),
        ),
      )
          .toList(growable: false);
    } catch (error) {
      return rethrowAsNetworkUnavailable(error);
    }
  }

  @override
  Future<void> unlinkGoogleIdentity() async {
    try {
      // Use one authoritative identity snapshot. Fetching DTOs first and then
      // fetching Supabase identities again created a race where firstWhere()
      // could throw if an auth refresh changed the list between the two calls.
      final liveIdentities = await _client.auth.getUserIdentities();
      if (liveIdentities.length < 2) {
        throw const RepositoryIdentityUnavailableException();
      }
      final googleIdentity = liveIdentities
          .where((identity) => identity.provider == 'google')
          .firstOrNull;
      if (googleIdentity == null) {
        throw const RepositoryIdentityUnavailableException();
      }
      await _client.auth.unlinkIdentity(googleIdentity);
    } on RepositoryIdentityUnavailableException {
      rethrow;
    } on supabase.AuthException catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      final code = error.code?.toLowerCase();
      final message = error.message.toLowerCase();
      if (code == 'single_identity_not_deletable' ||
          code == 'identity_not_found' ||
          code == 'email_conflict_identity_not_deletable' ||
          message.contains('only identity') ||
          message.contains('at least two identities')) {
        throw const RepositoryIdentityUnavailableException();
      }
      rethrow;
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  bool hasRecentOAuthAuthentication({
    Duration maximumAge = const Duration(minutes: 10),
  }) {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return false;
      final methods = payload['amr'];
      if (methods is! List) return false;
      final cutoff = DateTime.now().toUtc().subtract(maximumAge);
      return methods.whereType<Map>().any((method) {
        final name = method['method']?.toString().toLowerCase();
        final timestamp = (method['timestamp'] as num?)?.toInt();
        if (name != 'oauth' || timestamp == null) return false;
        return DateTime.fromMillisecondsSinceEpoch(
          timestamp * 1000,
          isUtc: true,
        ).isAfter(cutoff);
      });
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> refreshSession() async {
    try {
      await _client.auth.refreshSession();
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  @override
  Future<bool> requestAccountDeletion({
    required bool skipEmailConfirmation,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'request-account-deletion',
        body: {'skip_email_confirmation': skipEmailConfirmation},
      );
      if (response.status < 200 || response.status >= 300) {
        throw RepositoryAccountDeletionException(
          _responseMessage(response.data),
        );
      }
      final data = response.data;
      return data is Map && data['ready_for_final_confirmation'] == true;
    } catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      rethrow;
    }
  }

  @override
  Future<void> permanentlyDeleteAccount() async {
    try {
      final response = await _client.functions.invoke('delete-account');
      if (response.status < 200 || response.status >= 300) {
        if (response.status == 409) {
          throw const RepositoryAccountDeletionNotConfirmedException();
        }
        throw RepositoryAccountDeletionException(
          _responseMessage(response.data),
        );
      }
    } on RepositoryAccountDeletionNotConfirmedException {
      rethrow;
    } catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      rethrow;
    }
  }

  @override
  Future<void> cancelAccountDeletion() async {
    try {
      final response = await _client.functions.invoke(
        'request-account-deletion',
        body: {'cancel': true},
      );
      if (response.status < 200 || response.status >= 300) {
        throw RepositoryAccountDeletionException(
          _responseMessage(response.data),
        );
      }
    } catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut({bool allSessions = false}) async {
    try {
      await _client.auth.signOut(
        scope: allSessions
            ? supabase.SignOutScope.global
            : supabase.SignOutScope.local,
      );
    } catch (error) {
      rethrowAsNetworkUnavailable<void>(error);
    }
  }

  static AuthUserData? _mapUser(supabase.User? user) {
    if (user == null) return null;
    final rawProviders = user.appMetadata['providers'];
    final providers = <String>{
      if (user.appMetadata['provider'] case final String provider) provider,
      if (rawProviders is List)
        ...rawProviders.map((provider) => provider.toString()),
      if (user.identities != null)
        ...user.identities!.map((identity) => identity.provider),
    };
    if (providers.isEmpty) providers.add('email');
    final providerEmails = <String, String>{};
    final identities = user.identities;
    if (identities != null) {
      for (final identity in identities) {
        final identityEmail =
        identity.identityData?['email']?.toString().trim();
        if (identityEmail != null && identityEmail.isNotEmpty) {
          providerEmails[identity.provider] = identityEmail;
        }
      }
    }
    return AuthUserData(
      id: user.id,
      email: user.email ?? '',
      providers: Set<String>.unmodifiable(providers),
      createdAt: DateTime.tryParse(user.createdAt)?.toUtc() ??
          DateTime.now().toUtc(),
      metadata: Map<String, dynamic>.from(user.userMetadata ?? const {}),
      providerEmails: Map<String, String>.unmodifiable(providerEmails),
    );
  }

  static String _responseMessage(Object? data) {
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'The account operation could not be completed.';
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
