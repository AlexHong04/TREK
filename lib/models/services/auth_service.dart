import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../../utils/preference_keys.dart';
import '../entities/user.dart';
import '../local_data_source/notification_source.dart';
import '../repository/i_auth_repository.dart';
import '../repository/i_user_repository.dart';
import 'i_auth_service.dart';

class AuthService extends ChangeNotifier implements IAuthService {
  final IAuthRepository _authRepository;
  final IUserRepository _userRepository;
  final NotificationSource _notificationSource = NotificationSource();

  User? _currentUser;
  AccountInfo? _accountInfo;
  bool _isPasswordRecovery = false;
  bool _hasCrossDeviceRecovery = false;
  bool _recoveryStatusCheckInFlight = false;
  bool _hasCrossDeviceEmailLogin = false;
  bool _emailLoginStatusCheckInFlight = false;
  bool _isOffline = false;
  bool _requiresEmailVerification = false;
  int _verificationDaysRemaining = 0;
  AuthDestination _destination = AuthDestination.signedOut;
  String? _sessionMessage;
  String? _pendingEmailChangeTarget;
  String? _pendingVerificationAuthId;
  String? _pendingDeletionAuthId;
  bool _persistentEmailStateRestored = false;
  bool _disposed = false;
  bool _googleIdentityMutationInProgress = false;
  int _identityMutationVersion = 0;
  Future<void>? _activeAccountLoad;
  String? _activeAccountAuthId;
  Timer? _verificationDeadlineTimer;
  Timer? _passwordRecoveryTimer;
  Timer? _emailLoginTimer;
  Timer? _emailCooldownTimer;
  final Map<EmailActionType, DateTime> _emailCooldownUntil = {};
  StreamSubscription<AuthSessionSnapshot>? _authSubscription;
  StreamSubscription<User?>? _profileSubscription;

  AuthService(this._authRepository, this._userRepository) {
    _authSubscription = _authRepository.authStateChanges.listen(
      _handleAuthStateChange,
      onError: (Object error, StackTrace _) {
        if (isNetworkUnavailable(error)) {
          _setOffline(true);
        }
      },
    );
  }

  @override
  bool get isLoggedIn => _currentUser != null;

  @override
  bool get isPasswordRecovery => _isPasswordRecovery;

  @override
  bool get isOffline => _isOffline;

  @override
  bool get requiresEmailVerification => _requiresEmailVerification;

  @override
  int get verificationDaysRemaining => _verificationDaysRemaining;

  @override
  int emailCooldownSeconds(EmailActionType action) {
    final until = _emailCooldownUntil[action];
    if (until == null) return 0;
    final milliseconds = until.difference(DateTime.now().toUtc()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
  }

  @override
  AuthDestination get destination => _destination;

  @override
  String? get currentUserId => _currentUser?.userId;

  @override
  User? get currentUser => _currentUser;

  @override
  AccountInfo? get accountInfo => _accountInfo;

  @override
  Future<void> restoreSession() async {
    await _restorePersistentEmailState();
    final authUser = _authRepository.currentUser;
    if (authUser == null) {
      await _clearSessionState(clearCache: false);
      await _restorePasswordRecoveryPolling();
      await _restoreDeviceEmailLoginPolling();
      return;
    }
    await _loadAuthenticatedAccount(authUser);
  }

  @override
  Future<RegistrationResult> register({
    required String email,
    required String password,
    required String currency,
  }) async {
    try {
      await _authRepository.signUpWithEmail(
        email: InputValidator.normalizeEmail(email),
        password: password,
        currency: currency,
      );
      final authUser = _authRepository.currentUser;
      if (authUser == null) {
        throw StateError('Registration completed without an Auth session.');
      }
      // Queue the one-off user guide here rather than in the registration form.
      // This is the only place that knows a brand-new account now exists, and it
      // runs before _loadAuthenticatedAccount() flips the destination and the
      // app routes the new tourist to the Home screen.
      try {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool(PreferenceKeys.userGuidePending, true);
        debugPrint('[UserGuide] queued after registration.');
      } catch (error) {
        // A missing guide is never a reason to fail a successful registration.
        debugPrint('[UserGuide] could not queue the guide: $error');
      }
      await _loadAuthenticatedAccount(authUser);
      // Cooldowns belong to the email address that requested them. Do not carry
      // an older account's saved countdown into this newly registered account -
      // a stale deletion cooldown would otherwise block this account from ever
      // requesting its own confirmation email.
      await _clearAllEmailCooldowns();
      // Registration no longer sends a verification email automatically. The
      // 60-second resend timer therefore starts only after the user explicitly
      // presses Verify email on Profile or the verification gate.
      return const RegistrationResult(
        requiresEmailVerification: true,
        verificationEmailSent: false,
      );
    } on RepositoryEmailAlreadyExistsException {
      throw const EmailAlreadyExistsException();
    }
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = InputValidator.normalizeEmail(email);
    final currentLock =
    await _userRepository.getLoginLockStatus(normalizedEmail);
    if (currentLock.isLocked) {
      throw AccountLockedException(lockedUntil: currentLock.lockedUntil);
    }

    try {
      final authUser = await _authRepository.signInWithEmail(
        email: normalizedEmail,
        password: password,
      );
      await _loadAuthenticatedAccount(authUser);
    } on RepositoryInvalidCredentialsException {
      LoginLockStatus? updatedLock;
      try {
        updatedLock =
        await _userRepository.recordFailedLoginAttempt(normalizedEmail);
      } on NetworkUnavailableException {
        // A transport failure is never counted as another incorrect password.
      }
      if (updatedLock?.isLocked == true) {
        throw AccountLockedException(lockedUntil: updatedLock?.lockedUntil);
      }
      throw const InvalidCredentialsException();
    }
  }

  @override
  Future<void> signInWithGoogle() => _authRepository.signInWithGoogle();

  @override
  Future<void> linkGoogle() async {
    if (_googleIdentityMutationInProgress) {
      throw const GoogleIdentityOperationInProgressException();
    }
    _requireCurrentUser();
    final info = _requireAccountInfo();
    if (info.hasGoogleIdentity) return;
    _googleIdentityMutationInProgress = true;
    try {
      await _authRepository.linkGoogleIdentity();
    } on RepositoryIdentityAlreadyLinkedException {
      throw const GoogleIdentityAlreadyLinkedException();
    } on RepositoryManualIdentityLinkingDisabledException {
      throw const ManualIdentityLinkingDisabledException();
    } finally {
      // This lock prevents duplicate browser launches. The Edit Account
      // ViewModel keeps its own pending flag until the callback is processed.
      _googleIdentityMutationInProgress = false;
    }
  }

  @override
  Future<void> sendMagicLinkForLockedAccount({required String email}) async {
    await _runEmailRequest(
      EmailActionType.lockedAccountLogin,
          () => _authRepository.requestDeviceEmailLogin(email: email),
    );
    _hasCrossDeviceEmailLogin = true;
    _startDeviceEmailLoginPolling();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _runEmailRequest(
      EmailActionType.passwordRecovery,
          () => _authRepository.sendPasswordResetEmail(email: email),
    );
    _hasCrossDeviceRecovery = true;
    _startPasswordRecoveryPolling();
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    await _runEmailRequest(
      EmailActionType.verification,
          () => _authRepository.sendMagicLink(email: email),
    );
    final authId = _currentUser?.authId;
    if (authId != null) await _rememberPendingVerification(authId);
  }

  @override
  Future<void> setNewPasswordFromRecovery({
    required String newPassword,
  }) async {
    if (!_isPasswordRecovery) {
      throw StateError('A valid password-recovery session is required.');
    }
    try {
      if (_hasCrossDeviceRecovery) {
        await _authRepository.completePendingPasswordRecovery(
          newPassword: newPassword,
        );
      } else {
        await _authRepository.updatePassword(newPassword: newPassword);
        // Legacy same-device Supabase recovery links still work.
        await _userRepository.completeEmailVerification();
      }
    } on RepositorySamePasswordException {
      throw const PasswordReusedException();
    }
    final authId = _authRepository.currentUser?.id;
    if (authId != null) await _authRepository.signOut(allSessions: true);
    if (authId != null) {
      await _userRepository.clearCachedUserProfile(authId);
    }
    _isPasswordRecovery = false;
    _hasCrossDeviceRecovery = false;
    _passwordRecoveryTimer?.cancel();
    _sessionMessage = 'Password reset successfully.';
    await _clearSessionState(clearCache: false);
  }

  @override
  Future<void> setPasswordForOAuthUser({
    required String newPassword,
  }) async {
    final info = _requireAccountInfo();
    if (info.hasPasswordSignIn || !info.hasGoogleIdentity) {
      throw StateError('This account already has a password.');
    }
    if (!info.hasRecentOAuthAuthentication) {
      throw const RecentAuthenticationRequiredException();
    }
    try {
      await _authRepository.updatePassword(newPassword: newPassword);
      await refreshCurrentUser();
    } on RepositorySamePasswordException {
      throw const PasswordReusedException();
    } on RepositoryRecentAuthenticationRequiredException {
      throw const RecentAuthenticationRequiredException();
    }
    _sessionMessage = 'Password set successfully.';
    _notifySafely();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) throw StateError('No signed-in tourist.');
    if (currentPassword == newPassword) {
      throw const PasswordReusedException();
    }
    try {
      await _authRepository.updatePassword(
        newPassword: newPassword,
        currentPassword: currentPassword,
      );
    } on RepositoryIncorrectCurrentPasswordException {
      throw const IncorrectCurrentPasswordException();
    } on RepositorySamePasswordException {
      throw const PasswordReusedException();
    }
    final authId = _currentUser!.authId;
    await _authRepository.signOut(allSessions: true);
    await _userRepository.clearCachedUserProfile(authId);
    _sessionMessage = 'Password changed. Please log in again.';
    await _clearSessionState(clearCache: false);
  }

  @override
  Future<void> changeAccountEmail({
    required String newEmail,
    String? currentPassword,
  }) async {
    final user = _requireCurrentUser();
    final info = _requireAccountInfo();
    final normalizedEmail = InputValidator.normalizeEmail(newEmail);
    final validationError = InputValidator.validateEmail(normalizedEmail);
    if (validationError != null) throw ArgumentError(validationError);
    if (normalizedEmail.toLowerCase() == user.email.toLowerCase()) return;
    if (info.isGoogleManagedAccount) {
      throw const GoogleManagedAccountException();
    }

    await _reauthenticateForSensitiveAction(
      info: info,
      user: user,
      currentPassword: currentPassword,
    );

    try {
      await _runEmailRequest(
        EmailActionType.emailChange,
            () => _authRepository.requestAccountEmailChange(
          newEmail: normalizedEmail,
        ),
      );
      await _rememberPendingEmailChange(normalizedEmail);
    } on RepositoryEmailAlreadyExistsException {
      throw const EmailAlreadyExistsException();
    } on RepositoryRecentAuthenticationRequiredException {
      throw const RecentAuthenticationRequiredException();
    } on RepositoryEmailChangeException catch (error) {
      throw AccountEmailChangeException(error.message);
    }
  }

  @override
  Future<void> unlinkGoogle({required String currentPassword}) async {
    if (_googleIdentityMutationInProgress) {
      throw const GoogleIdentityOperationInProgressException();
    }
    final user = _requireCurrentUser();
    final info = _requireAccountInfo();
    if (!info.canUnlinkGoogle) {
      throw const CannotUnlinkGoogleException();
    }
    _googleIdentityMutationInProgress = true;
    try {
      await _reauthenticatePassword(user, currentPassword);
      await _authRepository.unlinkGoogleIdentity();
      // unlinkIdentity() already updates the authenticated user. Refreshing the
      // whole session here emitted another auth event while the unlink was
      // still being handled and could race with a second button press.
      _identityMutationVersion++;
      final latestInfo = _accountInfo ?? info;
      _accountInfo = AccountInfo(
        accountEmail: latestInfo.accountEmail,
        hasPasswordSignIn: latestInfo.hasPasswordSignIn,
        hasEmailIdentity: latestInfo.hasEmailIdentity,
        hasGoogleIdentity: false,
        isEmailVerified: latestInfo.isEmailVerified,
        hasRecentOAuthAuthentication: false,
      );
      _notifySafely();
    } on RepositoryIdentityUnavailableException {
      throw const MissingEmailIdentityForGoogleUnlinkException();
    } finally {
      _googleIdentityMutationInProgress = false;
    }
  }

  @override
  Future<bool> requestAccountDeletion({String? currentPassword}) async {
    final user = _requireCurrentUser();
    final info = _requireAccountInfo();
    // For verified accounts, possession of the one-time email link is the
    // confirmation step. Unverified accounts skip that email and therefore
    // still require recent password/OAuth authentication here.
    if (!user.isEmailVerified) {
      await _reauthenticateForSensitiveAction(
        info: info,
        user: user,
        currentPassword: currentPassword,
      );
    }

    final ready = await _runEmailRequest(
      EmailActionType.accountDeletion,
          () => _authRepository.requestAccountDeletion(
        skipEmailConfirmation: !user.isEmailVerified,
      ),
      startsCooldown: user.isEmailVerified,
    );
    if (ready) {
      _currentUser = user.copyWith(
        accountStatus: TrekAccountStatus.deletionEmailConfirmed,
        deletionConfirmedAt: DateTime.now().toUtc(),
      );
      _updateDestination();
      _notifySafely();
    } else {
      await _rememberPendingDeletion(user.authId);
    }
    return ready;
  }

  @override
  Future<void> permanentlyDeleteAccount() async {
    final user = _requireCurrentUser();
    if (!user.isDeletionConfirmed) {
      throw const AccountDeletionNotConfirmedException();
    }
    try {
      await _authRepository.permanentlyDeleteAccount();
    } on RepositoryAccountDeletionNotConfirmedException {
      throw const AccountDeletionNotConfirmedException();
    }
    // The server-side deletion is already complete. From this point, local
    // cleanup failures must not turn a successful deletion into an error.
    // Store the message before sign-out emits the signed-out event and creates
    // the next LoginViewModel, which consumes this one-time message.
    _sessionMessage = 'Your account has been deleted successfully.';
    try {
      await _userRepository.clearCachedUserProfile(user.authId);
    } catch (_) {
      // Cached data is never exposed without an authenticated session.
    }
    try {
      await _authRepository.signOut();
    } catch (_) {
      // The Auth user has already been removed server-side.
    }
    await _clearSessionState(clearCache: false);
  }

  @override
  Future<void> cancelAccountDeletion() async {
    _requireCurrentUser();
    await _authRepository.cancelAccountDeletion();
    await refreshCurrentUser();
  }

  @override
  Future<void> refreshCurrentUser() async {
    final authUser = _authRepository.currentUser;
    if (authUser == null) {
      await _clearSessionState(clearCache: false);
      return;
    }
    await _loadAuthenticatedAccount(authUser);
  }

  @override
  Future<void> onAppResumed() async {
    if (_authRepository.currentUser == null) {
      await _checkPasswordRecoveryStatus();
      await _checkDeviceEmailLoginStatus();
      return;
    }
    await refreshCurrentUser();
  }

  @override
  String? consumeSessionMessage() {
    final message = _sessionMessage;
    _sessionMessage = null;
    return message;
  }

  @override
  Future<void> logout() async {
    final authId = _currentUser?.authId ?? _authRepository.currentUser?.id;
    Object? signOutFailure;
    try {
      await _authRepository.signOut();
    } catch (error) {
      // Offline logout still removes the local session. Only keep an
      // unexpected error when Supabase also kept a local current user.
      if (!isNetworkUnavailable(error) && _authRepository.currentUser != null) {
        signOutFailure = error;
      }
    }
    if (authId != null) {
      try {
        await _userRepository.clearCachedUserProfile(authId);
      } catch (_) {
        // The session still ends. Cached data is never shown without a restored
        // session and a later cleanup attempt can remove the stale files.
      }
    }
    try {
      await _notificationSource.cancelAllNotifications();
    } catch (error) {
      debugPrint('Unable to clear local notifications during logout: $error');
    }
    await _clearSessionState(clearCache: false);
    // A cooldown belongs to the account that triggered it, so it must not
    // follow the device into the next session.
    await _clearAllEmailCooldowns();
    if (signOutFailure != null) throw signOutFailure;
  }

  Future<void> _handleAuthStateChange(AuthSessionSnapshot snapshot) async {
    try {
      if (snapshot.isPasswordRecovery) {
        _isPasswordRecovery = true;
        _isOffline = false;
        _destination = AuthDestination.passwordRecovery;
        _notifySafely();
        return;
      }

      final authUser = snapshot.user;
      if (authUser == null) {
        await _clearSessionState(clearCache: false);
        if (_hasCrossDeviceRecovery) _startPasswordRecoveryPolling();
        if (_hasCrossDeviceEmailLogin) _startDeviceEmailLoginPolling();
        return;
      }

      _hasCrossDeviceEmailLogin = false;
      _emailLoginTimer?.cancel();
      _isPasswordRecovery = false;
      await _loadAuthenticatedAccount(authUser);
    } on NetworkUnavailableException {
      _setOffline(true);
    } catch (_) {
      // The foreground action presents its own error. Auth-state callbacks must
      // never become uncaught zone errors or red framework screens.
    }
  }

  Future<void> _restorePasswordRecoveryPolling() async {
    try {
      _hasCrossDeviceRecovery =
      await _authRepository.hasPendingPasswordRecovery();
      if (!_hasCrossDeviceRecovery) return;
      await _checkPasswordRecoveryStatus();
      if (!_isPasswordRecovery) _startPasswordRecoveryPolling();
    } catch (error) {
      if (isNetworkUnavailable(error)) _setOffline(true);
    }
  }

  Future<void> _restoreDeviceEmailLoginPolling() async {
    try {
      _hasCrossDeviceEmailLogin =
      await _authRepository.hasPendingDeviceEmailLogin();
      if (!_hasCrossDeviceEmailLogin) return;
      await _checkDeviceEmailLoginStatus();
      if (_authRepository.currentUser == null && _hasCrossDeviceEmailLogin) {
        _startDeviceEmailLoginPolling();
      }
    } catch (error) {
      if (isNetworkUnavailable(error)) _setOffline(true);
    }
  }

  void _startPasswordRecoveryPolling() {
    _passwordRecoveryTimer?.cancel();
    unawaited(_checkPasswordRecoveryStatus());
    _passwordRecoveryTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => unawaited(_checkPasswordRecoveryStatus()),
    );
  }

  Future<void> _checkPasswordRecoveryStatus() async {
    if (!_hasCrossDeviceRecovery || _recoveryStatusCheckInFlight || _disposed) {
      return;
    }
    _recoveryStatusCheckInFlight = true;
    try {
      final status =
      await _authRepository.getPendingPasswordRecoveryStatus();
      if (status == PasswordRecoveryStatus.ready) {
        _passwordRecoveryTimer?.cancel();
        _isPasswordRecovery = true;
        _isOffline = false;
        _updateDestination();
        _notifySafely();
      } else if (status == PasswordRecoveryStatus.expired ||
          status == PasswordRecoveryStatus.completed) {
        _passwordRecoveryTimer?.cancel();
        await _authRepository.clearPendingPasswordRecovery();
        _hasCrossDeviceRecovery = false;
      } else if (_isOffline) {
        _setOffline(false);
      }
    } on NetworkUnavailableException {
      _setOffline(true);
    } finally {
      _recoveryStatusCheckInFlight = false;
    }
  }

  void _startDeviceEmailLoginPolling() {
    _emailLoginTimer?.cancel();
    unawaited(_checkDeviceEmailLoginStatus());
    _emailLoginTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => unawaited(_checkDeviceEmailLoginStatus()),
    );
  }

  Future<void> _checkDeviceEmailLoginStatus() async {
    if (!_hasCrossDeviceEmailLogin ||
        _emailLoginStatusCheckInFlight ||
        _disposed) {
      return;
    }
    _emailLoginStatusCheckInFlight = true;
    try {
      final status =
      await _authRepository.getPendingDeviceEmailLoginStatus();
      if (status == DeviceEmailLoginStatus.signedIn) {
        _emailLoginTimer?.cancel();
        _hasCrossDeviceEmailLogin = false;
        _isOffline = false;
        _sessionMessage = 'Secure email sign-in completed successfully.';
        final authUser = _authRepository.currentUser;
        if (authUser != null) await _loadAuthenticatedAccount(authUser);
      } else if (status == DeviceEmailLoginStatus.expired ||
          status == DeviceEmailLoginStatus.completed) {
        _emailLoginTimer?.cancel();
        await _authRepository.clearPendingDeviceEmailLogin();
        _hasCrossDeviceEmailLogin = false;
      } else if (_isOffline) {
        _setOffline(false);
      }
    } on NetworkUnavailableException {
      _setOffline(true);
    } catch (_) {
      // Status polling runs outside the button's Future. A malformed, expired,
      // or temporarily unavailable token must never escape as an uncaught
      // asynchronous error. The request remains pending and can retry on the
      // next timer tick or app resume.
    } finally {
      _emailLoginStatusCheckInFlight = false;
    }
  }

  Future<void> _loadAuthenticatedAccount(AuthUserData authUser) async {
    final active = _activeAccountLoad;
    if (active != null) {
      if (_activeAccountAuthId == authUser.id) {
        await active;
        return;
      }
      try {
        await active;
      } catch (_) {
        // The newer Auth session still needs its own load attempt.
      }
      await _loadAuthenticatedAccount(authUser);
      return;
    }

    final load = _performAccountLoad(authUser);
    _activeAccountLoad = load;
    _activeAccountAuthId = authUser.id;
    try {
      await load;
    } finally {
      if (identical(_activeAccountLoad, load)) _activeAccountLoad = null;
      if (_activeAccountAuthId == authUser.id) _activeAccountAuthId = null;
    }
  }

  Future<void> _performAccountLoad(AuthUserData authUser) async {
    if (_authRepository.currentUser?.id != authUser.id) return;
    final previousUser = _currentUser;
    User? profile;
    AccountAccessData? access;
    var loadedFromCache = false;

    try {
      // Safe for every sign-in method: the SQL function changes state only for
      // a validated magic-link/recovery AMR or trusted OAuth session.
      await _userRepository.completeEmailVerification();
      profile = await _userRepository.getUserProfileByAuthId(authUser.id);
      if (profile == null) {
        await _createMissingProfile(authUser);
        profile = await _userRepository.getUserProfileByAuthId(authUser.id);
      }
      if (profile == null) {
        throw StateError('The TREK user profile could not be created.');
      }
      access = await _userRepository.getCurrentAccountAccess();
      try {
        await _userRepository.resetFailedLoginAttempts(profile.userId);
      } on NetworkUnavailableException {
        // Profile and access were already securely loaded; retry on refresh.
      }
      _isOffline = false;
    } on NetworkUnavailableException {
      profile = await _userRepository.getCachedUserProfileByAuthId(authUser.id);
      if (profile == null) rethrow;
      loadedFromCache = true;
      _isOffline = true;
    }

    // A sign-out or account switch may have happened while the profile was
    // loading. Never publish data from that stale Auth session.
    if (_authRepository.currentUser?.id != authUser.id) return;
    _currentUser = access == null
        ? profile
        : profile.copyWith(hasPasswordSignIn: access.hasPasswordSignIn);
    final accountEmailChanged = previousUser != null &&
        previousUser.email.toLowerCase() != _currentUser!.email.toLowerCase();
    await _completePendingEmailChangeIfNeeded(
      _currentUser!,
      force: accountEmailChanged,
    );
    if (_pendingVerificationAuthId == authUser.id &&
        _currentUser!.isEmailVerified) {
      await _clearPendingVerification();
      if (!accountEmailChanged) {
        _sessionMessage = 'Email verified successfully.';
      }
    } else if (!accountEmailChanged &&
        previousUser != null &&
        !previousUser.isEmailVerified &&
        _currentUser!.isEmailVerified) {
      _sessionMessage = 'Email verified successfully.';
    }
    if (_pendingDeletionAuthId == authUser.id &&
        _currentUser!.isDeletionConfirmed) {
      await _clearPendingDeletion();
      _sessionMessage =
      'Deletion request confirmed. Review the final confirmation.';
    } else if (previousUser != null &&
        !previousUser.isDeletionConfirmed &&
        _currentUser!.isDeletionConfirmed) {
      _sessionMessage =
      'Deletion request confirmed. Review the final confirmation.';
    }
    if (access != null) {
      await _userRepository.cacheUserProfile(_currentUser!);
    }
    if (access != null) {
      _requiresEmailVerification = access.requiresVerification;
      _verificationDaysRemaining = access.verificationDaysRemaining;
    } else {
      _requiresEmailVerification =
          profile.requiresVerificationAt(DateTime.now().toUtc());
      _verificationDaysRemaining =
          profile.verificationDaysRemainingAt(DateTime.now().toUtc());
    }
    _scheduleVerificationDeadline(access);
    final identityVersion = _identityMutationVersion;
    await _refreshAccountInfo(
      authUser,
      allowNetwork: !loadedFromCache,
      access: access,
      expectedIdentityVersion: identityVersion,
    );
    _subscribeToProfile(authUser.id);
    _updateDestination();
    _notifySafely();
  }

  Future<void> _createMissingProfile(AuthUserData authUser) async {
    final now = authUser.createdAt;
    final fallbackProfile = User(
      userId: '',
      authId: authUser.id,
      fullName: _resolveName(authUser),
      email: authUser.email,
      currency:
      authUser.metadata['currency']?.toString().toUpperCase() ?? 'MYR',
      createdAt: now,
      updatedAt: now,
      verificationDeadlineAt: now.add(const Duration(days: 7)),
    );
    await _userRepository.createUserProfile(fallbackProfile);
    if (authUser.hasTrustedOAuthIdentity) {
      await _userRepository.completeEmailVerification();
    }
  }

  Future<void> _refreshAccountInfo(
      AuthUserData authUser, {
        bool allowNetwork = true,
        AccountAccessData? access,
        int? expectedIdentityVersion,
      }) async {
    var providers = authUser.providers;
    Set<String>? liveIdentityProviders;
    String? googleEmail = authUser.providerEmails['google'];
    if (allowNetwork) {
      try {
        final identities = await _authRepository.getUserIdentities();
        liveIdentityProviders = identities
            .map((identity) => identity.provider)
            .toSet();
        providers = {
          ...providers,
          ...identities.map((identity) => identity.provider),
        };
        googleEmail = identities
            .where((identity) => identity.provider == 'google')
            .map((identity) => identity.email)
            .whereType<String>()
            .firstOrNull;
      } on NetworkUnavailableException {
        _isOffline = true;
      }
    }

    final hasGoogleIdentity =
        liveIdentityProviders?.contains('google') ?? providers.contains('google');
    final hasEmailIdentity =
        liveIdentityProviders?.contains('email') ?? providers.contains('email');
    final serverHasPasswordSignIn = access?.hasPasswordSignIn ??
        _currentUser?.hasPasswordSignIn ??
        false;

    final refreshedInfo = AccountInfo(
      accountEmail: _currentUser?.email ?? authUser.email,
      googleEmail: googleEmail,
      // TREK creates email identities through password registration. Preserve
      // that capability even if an older/custom access RPC reports a stale
      // false value. Google-only accounts still rely on the authoritative
      // server flag after a password is added.
      hasPasswordSignIn: serverHasPasswordSignIn || hasEmailIdentity,
      hasEmailIdentity: hasEmailIdentity,
      hasGoogleIdentity: hasGoogleIdentity,
      isEmailVerified: _currentUser?.isEmailVerified ?? false,
      hasRecentOAuthAuthentication:
      _authRepository.hasRecentOAuthAuthentication(),
    );
    // Do not let an account refresh that started before a successful unlink
    // restore stale Google identity state after the unlink completes.
    if (expectedIdentityVersion == null ||
        expectedIdentityVersion == _identityMutationVersion) {
      _accountInfo = refreshedInfo;
    }
  }

  void _subscribeToProfile(String authUserId) {
    _profileSubscription?.cancel();
    _profileSubscription = _userRepository
        .watchUserProfileByAuthId(authUserId)
        .listen(
          (fresh) => unawaited(_applyProfileUpdate(authUserId, fresh)),
      onError: (Object error, StackTrace _) {
        if (isNetworkUnavailable(error)) _setOffline(true);
      },
    );
  }

  Future<void> _applyProfileUpdate(String authUserId, User? fresh) async {
    if (fresh == null || _currentUser?.authId != authUserId) return;
    final current = _currentUser!;
    final becameVerified = !current.isEmailVerified && fresh.isEmailVerified;
    final emailChanged = current.email.toLowerCase() != fresh.email.toLowerCase();
    final deletionConfirmed = !current.isDeletionConfirmed &&
        fresh.isDeletionConfirmed;
    _currentUser = fresh.copyWith(
      hasPasswordSignIn: current.hasPasswordSignIn,
      cachedProfilePicturePath:
      fresh.cachedProfilePicturePath ?? current.cachedProfilePicturePath,
      personalConstraints: fresh.personalConstraints.isEmpty
          ? current.personalConstraints
          : fresh.personalConstraints,
    );
    if (becameVerified) await _clearPendingVerification();
    if (deletionConfirmed) await _clearPendingDeletion();
    if (emailChanged) {
      await _completePendingEmailChangeIfNeeded(_currentUser!, force: true);
    } else if (deletionConfirmed) {
      _sessionMessage =
      'Deletion request confirmed. Review the final confirmation.';
    } else if (becameVerified) {
      _sessionMessage = 'Email verified successfully.';
    }
    unawaited(_userRepository.cacheUserProfile(_currentUser!));
    _requiresEmailVerification = _currentUser!.requiresVerificationAt(
      DateTime.now().toUtc(),
    );
    _verificationDaysRemaining = _currentUser!
        .verificationDaysRemainingAt(DateTime.now().toUtc());
    _scheduleVerificationDeadline(null);
    final info = _accountInfo;
    if (info != null) {
      _accountInfo = AccountInfo(
        accountEmail: _currentUser!.email,
        googleEmail: info.googleEmail,
        hasPasswordSignIn: info.hasPasswordSignIn,
        hasEmailIdentity: info.hasEmailIdentity,
        hasGoogleIdentity: info.hasGoogleIdentity,
        isEmailVerified: _currentUser!.isEmailVerified,
        hasRecentOAuthAuthentication: info.hasRecentOAuthAuthentication,
      );
    }
    _updateDestination();
    _notifySafely();
  }

  Future<T> _runEmailRequest<T>(
      EmailActionType action,
      Future<T> Function() request, {
        bool startsCooldown = true,
      }) async {
    final remaining = emailCooldownSeconds(action);
    if (remaining > 0) {
      throw EmailRequestRateLimitedException(remaining);
    }
    try {
      final result = await request();
      if (startsCooldown) await _setEmailCooldown(action, 60);
      return result;
    } on RepositoryEmailRateLimitedException catch (error) {
      await _setEmailCooldown(action, error.retryAfterSeconds);
      throw EmailRequestRateLimitedException(error.retryAfterSeconds);
    }
  }

  Future<void> _restorePersistentEmailState() async {
    if (_persistentEmailStateRestored) return;
    _persistentEmailStateRestored = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _pendingEmailChangeTarget =
          preferences.getString('trek.pending_email_change');
      _pendingVerificationAuthId =
          preferences.getString('trek.pending_verification_auth_id');
      _pendingDeletionAuthId =
          preferences.getString('trek.pending_deletion_auth_id');
      final now = DateTime.now().toUtc();
      for (final action in EmailActionType.values) {
        final key = 'trek.email_cooldown.${action.name}';
        final milliseconds = preferences.getInt(key);
        if (milliseconds == null) continue;
        final until = DateTime.fromMillisecondsSinceEpoch(
          milliseconds,
          isUtc: true,
        );
        if (until.isAfter(now)) {
          _emailCooldownUntil[action] = until;
        } else {
          await preferences.remove(key);
        }
      }
      _ensureEmailCooldownTimer();
    } catch (_) {
      // Cooldowns are still enforced server-side if local persistence fails.
    }
  }

  Future<void> _setEmailCooldown(
      EmailActionType action,
      int seconds,
      ) async {
    final safeSeconds = seconds < 1 ? 1 : seconds;
    final until = DateTime.now().toUtc().add(Duration(seconds: safeSeconds));
    _emailCooldownUntil[action] = until;
    _ensureEmailCooldownTimer();
    _notifySafely();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
        'trek.email_cooldown.${action.name}',
        until.millisecondsSinceEpoch,
      );
    } catch (_) {
      // Losing a local countdown cannot bypass the server-side limit.
    }
  }

  /// Drops every locally cached cooldown.
  ///
  /// A cooldown belongs to the email address that triggered it, so it must not
  /// survive an account change: a stale deletion or password-recovery countdown
  /// saved by a previous account would otherwise block the next account from
  /// ever requesting that email. The server still enforces its own limit, so
  /// clearing this can never be used to bypass it.
  Future<void> _clearAllEmailCooldowns() async {
    _emailCooldownUntil.clear();
    _ensureEmailCooldownTimer();
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final action in EmailActionType.values) {
        await preferences.remove('trek.email_cooldown.${action.name}');
      }
    } catch (_) {
      // The in-memory map is already cleared.
    }
  }

  void _ensureEmailCooldownTimer() {
    _emailCooldownTimer?.cancel();
    if (!_emailCooldownUntil.values.any(
          (until) => until.isAfter(DateTime.now().toUtc()),
    )) {
      _emailCooldownTimer = null;
      return;
    }
    _emailCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      final now = DateTime.now().toUtc();
      _emailCooldownUntil.removeWhere((_, until) => !until.isAfter(now));
      if (_emailCooldownUntil.isEmpty) {
        _emailCooldownTimer?.cancel();
        _emailCooldownTimer = null;
      }
      _notifySafely();
    });
  }

  Future<void> _rememberPendingEmailChange(String newEmail) async {
    _pendingEmailChangeTarget = newEmail.trim().toLowerCase();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'trek.pending_email_change',
        _pendingEmailChangeTarget!,
      );
    } catch (_) {
      // Realtime still detects an email change during the current app run.
    }
  }

  Future<void> _rememberPendingVerification(String authId) async {
    _pendingVerificationAuthId = authId;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('trek.pending_verification_auth_id', authId);
    } catch (_) {
      // Realtime still detects completion while the app remains open.
    }
  }

  Future<void> _clearPendingVerification() async {
    _pendingVerificationAuthId = null;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('trek.pending_verification_auth_id');
    } catch (_) {
      // The stored marker is scoped to an auth ID and is harmless if retained.
    }
  }

  Future<void> _rememberPendingDeletion(String authId) async {
    _pendingDeletionAuthId = authId;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('trek.pending_deletion_auth_id', authId);
    } catch (_) {
      // Realtime still detects completion while the app remains open.
    }
  }

  Future<void> _clearPendingDeletion() async {
    _pendingDeletionAuthId = null;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('trek.pending_deletion_auth_id');
    } catch (_) {
      // The stored marker is scoped to an auth ID and is harmless if retained.
    }
  }

  Future<void> _completePendingEmailChangeIfNeeded(
      User user, {
        bool force = false,
      }) async {
    final target = _pendingEmailChangeTarget;
    if (!force &&
        (target == null || user.email.trim().toLowerCase() != target)) {
      return;
    }
    _pendingEmailChangeTarget = null;
    _sessionMessage = 'Email changed successfully to ${user.email}.';
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('trek.pending_email_change');
    } catch (_) {
      // The completed value is harmless and is ignored unless it matches.
    }
    try {
      await _authRepository.refreshSession();
    } catch (_) {
      // The profile is authoritative. Session refresh will retry on resume.
    }
  }

  Future<void> _reauthenticateForSensitiveAction({
    required AccountInfo info,
    required User user,
    String? currentPassword,
  }) async {
    if (info.hasPasswordSignIn) {
      await _reauthenticatePassword(user, currentPassword ?? '');
      return;
    }
    if (info.hasGoogleIdentity && info.hasRecentOAuthAuthentication) return;
    throw const RecentAuthenticationRequiredException();
  }

  Future<void> _reauthenticatePassword(User user, String password) async {
    if (password.isEmpty) throw const IncorrectCurrentPasswordException();
    try {
      await _authRepository.reauthenticateWithPassword(
        email: user.email,
        password: password,
      );
    } on RepositoryInvalidCredentialsException {
      throw const IncorrectCurrentPasswordException();
    }
  }

  User _requireCurrentUser() {
    final user = _currentUser;
    if (user == null) throw StateError('No signed-in tourist.');
    return user;
  }

  AccountInfo _requireAccountInfo() {
    final info = _accountInfo;
    if (info == null) throw StateError('Account information is unavailable.');
    return info;
  }

  String _resolveName(AuthUserData user) {
    if (user.hasTrustedOAuthIdentity) {
      final candidates = [
        user.metadata['full_name']?.toString(),
        user.metadata['name']?.toString(),
      ];
      for (final candidate in candidates.whereType<String>()) {
        if (candidate.trim().isNotEmpty &&
            InputValidator.validateDisplayName(candidate) == null) {
          return InputValidator.normalizeDisplayName(candidate);
        }
      }
    }
    // An absent name remains absent in the profile model. Home and Profile
    // render the friendly "Trekker" fallback without putting it in Edit Profile.
    return '';
  }

  void _updateDestination() {
    if (_isPasswordRecovery) {
      _destination = AuthDestination.passwordRecovery;
    } else if (_currentUser == null) {
      _destination = AuthDestination.signedOut;
    } else if (_currentUser!.isDeletionConfirmed) {
      _destination = AuthDestination.deletionConfirmation;
    } else if (_requiresEmailVerification) {
      _destination = AuthDestination.verificationRequired;
    } else {
      _destination = AuthDestination.normalApp;
    }
  }

  void _scheduleVerificationDeadline(AccountAccessData? access) {
    _verificationDeadlineTimer?.cancel();
    _verificationDeadlineTimer = null;
    final user = _currentUser;
    if (user == null || user.isEmailVerified || _requiresEmailVerification) {
      return;
    }
    final now = access?.serverTime ?? DateTime.now().toUtc();
    final deadline = access?.verificationDeadline ?? user.verificationDeadlineAt;
    final remaining = deadline.difference(now);
    if (remaining <= Duration.zero) {
      _requiresEmailVerification = true;
      _verificationDaysRemaining = 0;
      _updateDestination();
      _notifySafely();
      return;
    }
    _verificationDeadlineTimer = Timer(remaining, () {
      if (_disposed || _currentUser?.isEmailVerified != false) return;
      _requiresEmailVerification = true;
      _verificationDaysRemaining = 0;
      _updateDestination();
      _notifySafely();
      unawaited(refreshCurrentUser().catchError((_) {}));
    });
  }

  Future<void> _clearSessionState({required bool clearCache}) async {
    final authId = _currentUser?.authId;
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _verificationDeadlineTimer?.cancel();
    _passwordRecoveryTimer?.cancel();
    _emailLoginTimer?.cancel();
    _verificationDeadlineTimer = null;
    if (clearCache && authId != null) {
      await _userRepository.clearCachedUserProfile(authId);
    }
    _currentUser = null;
    _accountInfo = null;
    _isPasswordRecovery = false;
    _isOffline = false;
    _requiresEmailVerification = false;
    _verificationDaysRemaining = 0;
    _updateDestination();
    _notifySafely();
  }

  void _setOffline(bool value) {
    if (_isOffline == value) return;
    _isOffline = value;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _verificationDeadlineTimer?.cancel();
    _passwordRecoveryTimer?.cancel();
    _emailLoginTimer?.cancel();
    _emailCooldownTimer?.cancel();
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
