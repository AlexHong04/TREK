import 'dart:async';

import '../entities/user.dart';
import '../repository/i_user_repository.dart';
import 'i_auth_service.dart';
import 'profile_service.dart';

class AuthService extends IAuthService {
  final IUserRepository _userRepository;
  final ProfileService _profileService;

  User? _currentUser;
  bool _isPasswordRecovery = false;
  bool _suppressNextSignInNotification = false;
  StreamSubscription<AuthSessionSnapshot>? _authSubscription;

  AuthService(this._userRepository, this._profileService) {
    _authSubscription = _userRepository.authStateChanges.listen(
      _handleAuthStateChange,
      onError: (Object _, StackTrace __) {
        // Offline refresh errors must not become uncaught zone exceptions.
      },
    );
  }

  @override
  bool get isLoggedIn => _currentUser != null;

  @override
  String? get currentUserId => _currentUser?.userId;

  @override
  User? get currentUser => _currentUser;

  @override
  String get preferredCurrency => _currentUser?.currency ?? 'MYR';

  @override
  bool get isPasswordRecovery => _isPasswordRecovery;

  @override
  Future<void> restoreSession() async {
    final authUser = _userRepository.currentAuthUser;
    if (authUser == null) {
      _setCurrentUser(null);
      return;
    }
    try {
      // Handles a cold start directly from a magic link, where the SDK may
      // restore the new session before the signedIn event listener runs.
      await _userRepository.completeDeferredEmailVerification();
    } catch (_) {
      // Keep the valid session; verification can be retried from Profile.
    }
    await _loadProfile(authUser);
  }

  @override
  Future<RegistrationResult> register({
    required String email,
    required String password,
    required String currency,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      _suppressNextSignInNotification = true;
      await _userRepository.signUpWithEmail(
        email: normalizedEmail,
        password: password,
        currency: currency,
      );
      final authUser = _userRepository.currentAuthUser;
      if (authUser == null) {
        throw StateError('Registration completed without an Auth session.');
      }
      await _loadProfile(authUser);
      _suppressNextSignInNotification = false;
      return const RegistrationResult(requiresEmailVerification: false);
    } on RepositoryEmailAlreadyExistsException {
      _suppressNextSignInNotification = false;
      throw const EmailAlreadyExistsException();
    } catch (_) {
      _suppressNextSignInNotification = false;
      rethrow;
    }
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final currentLock =
    await _userRepository.getLoginLockStatus(normalizedEmail);
    if (currentLock.isLocked) {
      throw AccountLockedException(lockedUntil: currentLock.lockedUntil);
    }

    try {
      _suppressNextSignInNotification = true;
      final authUser = await _userRepository.signInWithEmail(
        email: normalizedEmail,
        password: password,
      );
      await _loadProfile(authUser);
      _suppressNextSignInNotification = false;
    } on RepositoryInvalidCredentialsException {
      _suppressNextSignInNotification = false;
      final updatedLock =
      await _userRepository.recordFailedLoginAttempt(normalizedEmail);
      if (updatedLock.isLocked) {
        throw AccountLockedException(lockedUntil: updatedLock.lockedUntil);
      }
      throw const InvalidCredentialsException();
    } catch (_) {
      _suppressNextSignInNotification = false;
      rethrow;
    }
  }

  @override
  Future<void> signInWithGoogle() => _userRepository.signInWithGoogle();

  @override
  Future<void> sendMagicLinkForLockedAccount({required String email}) {
    return _userRepository.sendMagicLink(email: email);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _userRepository.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> setNewPassword({required String newPassword}) async {
    try {
      await _userRepository.updatePassword(newPassword: newPassword);
    } on RepositorySamePasswordException {
      throw const PasswordReusedException();
    }
  }

  @override
  Future<void> resendVerificationEmail({required String email}) {
    // This is deliberately a sign-in magic link, not Supabase signup
    // confirmation. shouldCreateUser is false in AuthRepository.
    return _userRepository.sendMagicLink(email: email);
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
      await _userRepository.updatePassword(
        newPassword: newPassword,
        currentPassword: currentPassword,
      );
    } on RepositoryIncorrectCurrentPasswordException {
      throw const IncorrectCurrentPasswordException();
    } on RepositorySamePasswordException {
      throw const PasswordReusedException();
    }
    await _userRepository.signOut(allSessions: true);
    _isPasswordRecovery = false;
    _setCurrentUser(null);
  }

  @override
  Future<List<String>> getSupportedCurrencies() {
    return _userRepository.getSupportedCurrencies();
  }

  @override
  Future<void> updateCurrentProfile({
    required String fullName,
    required String currency,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    await _profileService.updateProfile(
      userId: userId,
      fullName: fullName,
      currency: currency,
    );
    await refreshCurrentUser();
  }

  @override
  Future<String?> updateProfilePicture(ProfileImageSource source) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    try {
      final url = await _profileService.pickAndSaveProfilePicture(
        userId: userId,
        source: source == ProfileImageSource.gallery
            ? ProfilePictureSource.gallery
            : ProfilePictureSource.camera,
      );
      if (url != null) await refreshCurrentUser();
      return url;
    } on ImageTooLargeException {
      throw const ProfileImageTooLargeException();
    } on InvalidImageFormatException {
      throw const ProfileInvalidImageFormatException();
    }
  }

  @override
  Future<void> removeProfilePicture() async {
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    await _profileService.removeProfilePicture(userId: userId);
    await refreshCurrentUser();
  }

  @override
  Future<List<PersonalConstraintOptionData>>
  loadPersonalConstraintOptions() async {
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    final results = await Future.wait([
      _profileService.getAllConstraints(),
      _profileService.getUserConstraints(userId),
    ]);
    final selectedIds =
    results[1].map((constraint) => constraint.constraintId).toSet();
    return results[0]
        .map(
          (constraint) => PersonalConstraintOptionData(
        id: constraint.constraintId,
        category: constraint.category,
        name: constraint.constraintName,
        isSelected: selectedIds.contains(constraint.constraintId),
      ),
    )
        .toList(growable: false);
  }

  @override
  Future<void> savePersonalConstraints(List<String> constraintIds) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    await _profileService.saveUserConstraints(
      userId: userId,
      constraintIds: constraintIds,
    );
    await refreshCurrentUser();
  }

  @override
  Future<void> refreshCurrentUser() async {
    final authUser = _userRepository.currentAuthUser;
    if (authUser == null) {
      _setCurrentUser(null);
      return;
    }
    await _loadProfile(authUser);
  }

  @override
  Future<void> logout() async {
    await _userRepository.signOut();
    _isPasswordRecovery = false;
    _setCurrentUser(null);
  }

  Future<void> _handleAuthStateChange(AuthSessionSnapshot snapshot) async {
    if (snapshot.isPasswordRecovery) {
      _isPasswordRecovery = true;
      _currentUser = null;
      notifyListeners();
      return;
    }

    final authUser = snapshot.user;
    if (authUser == null) {
      final recoveryChanged = _isPasswordRecovery;
      _isPasswordRecovery = false;
      if (recoveryChanged && _currentUser == null) {
        notifyListeners();
        return;
      }
      _setCurrentUser(null);
      return;
    }
    if (_suppressNextSignInNotification) {
      _suppressNextSignInNotification = false;
      return;
    }

    _isPasswordRecovery = false;
    if (snapshot.isSignedInEvent) {
      // The SQL function updates only for a recent OTP/magic-link AMR claim.
      // Password sign-ins safely return the existing status without updating.
      try {
        await _userRepository.completeDeferredEmailVerification();
      } catch (_) {
        // A temporary verification-RPC failure must not invalidate a valid
        // Auth session. Profile remains unverified and the user can retry.
      }
    }
    await _loadProfile(authUser);
  }

  Future<void> _loadProfile(AuthUserData authUser) async {
    var profile = await _userRepository.getUserProfileByAuthId(authUser.id);
    if (profile == null) {
      final now = DateTime.now();
      final fallbackProfile = User(
        userId: '',
        fullName: _resolveName(authUser),
        email: authUser.email,
        currency: authUser.metadata['currency'] as String? ?? 'MYR',
        createdAt: now,
        updatedAt: now,
        authId: authUser.id,
      );
      await _userRepository.createUserProfile(fallbackProfile);
      profile = await _userRepository.getUserProfileByAuthId(authUser.id);
      if (profile == null) {
        throw StateError('The TREK user profile could not be created.');
      }
    }

    if (authUser.isTrustedOAuthProvider && !profile.isEmailVerified) {
      await _userRepository.completeDeferredEmailVerification();
      profile = await _userRepository.getUserProfileByAuthId(authUser.id);
      if (profile == null) {
        throw StateError('The TREK user profile could not be refreshed.');
      }
    }

    await _userRepository.resetFailedLoginAttempts(profile.userId);
    _setCurrentUser(profile);
  }

  String _resolveName(AuthUserData user) {
    final fullName = user.metadata['full_name'] as String?;
    final providerName = user.metadata['name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
    if (providerName != null && providerName.trim().isNotEmpty) {
      return providerName.trim();
    }
    return user.email.contains('@') ? user.email.split('@').first : user.email;
  }

  void _setCurrentUser(User? user) {
    if (_currentUser == user) return;
    _currentUser = user;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
