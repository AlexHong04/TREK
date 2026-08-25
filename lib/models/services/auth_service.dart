import 'dart:async';

import '../entities/user.dart';
import '../repository/auth_repository.dart';
import '../repository/i_user_repository.dart';
import 'i_auth_service.dart';

class AuthService extends IAuthService {
  final IAuthRepository _authRepository;
  final IUserRepository _userRepository;

  User? _currentUser;
  bool _isPasswordRecovery = false;
  bool _suppressNextSignInNotification = false;
  bool _suppressNextSignOutNotification = false;
  StreamSubscription<AuthSessionSnapshot>? _authSubscription;

  AuthService(this._authRepository, this._userRepository) {
    _authSubscription =
        _authRepository.authStateChanges.listen(_handleAuthStateChange);
  }

  @override
  bool get isLoggedIn => _currentUser != null;

  @override
  String? get currentUserId => _currentUser?.userId;

  @override
  User? get currentUser => _currentUser;

  @override
  bool get isPasswordRecovery => _isPasswordRecovery;

  @override
  Future<void> restoreSession() async {
    final authUser = _authRepository.currentUser;
    if (authUser == null) {
      _setCurrentUser(null);
      return;
    }
    await _loadProfile(authUser);
  }

  @override
  Future<RegistrationResult> register({
    required String fullName,
    required String email,
    required String password,
    required String currency,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (await _userRepository.isEmailRegistered(normalizedEmail)) {
      throw const EmailAlreadyExistsException();
    }

    try {
      final result = await _authRepository.signUpWithEmail(
        fullName: fullName.trim(),
        email: normalizedEmail,
        password: password,
        currency: currency,
      );

      if (_authRepository.currentUser != null) {
        _suppressNextSignOutNotification = true;
        await _authRepository.signOut();
      }
      _setCurrentUser(null);
      return RegistrationResult(
        requiresEmailVerification: result.requiresEmailVerification,
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
    final normalizedEmail = email.trim().toLowerCase();
    final lockStatus =
    await _userRepository.getLoginLockStatus(normalizedEmail);
    if (lockStatus.isLocked) {
      throw AccountLockedException(lockedUntil: lockStatus.lockedUntil);
    }

    try {
      _suppressNextSignInNotification = true;
      final authUser = await _authRepository.signInWithEmail(
        email: normalizedEmail,
        password: password,
      );
      await _userRepository.resetFailedLoginAttempts(authUser.id);
      await _loadProfile(authUser, notify: false);
    } on RepositoryEmailNotVerifiedException {
      _suppressNextSignInNotification = false;
      throw const EmailNotVerifiedException();
    } on RepositoryInvalidCredentialsException {
      _suppressNextSignInNotification = false;
      final updatedStatus =
      await _userRepository.recordFailedLoginAttempt(normalizedEmail);
      if (updatedStatus.isLocked) {
        throw AccountLockedException(lockedUntil: updatedStatus.lockedUntil);
      }
      throw const InvalidCredentialsException();
    }
  }

  @override
  Future<void> signInWithGoogle() => _authRepository.signInWithGoogle();

  @override
  Future<void> sendMagicLinkForLockedAccount({required String email}) {
    return _authRepository.sendMagicLink(email: email);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _authRepository.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> setNewPassword({required String newPassword}) {
    return _authRepository.updatePassword(newPassword: newPassword);
  }

  @override
  Future<void> resendVerificationEmail({required String email}) {
    return _authRepository.resendEmailVerification(email: email);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _currentUser?.email;
    if (email == null) throw StateError('No signed-in tourist.');
    if (currentPassword == newPassword) {
      throw const PasswordReusedException();
    }

    try {
      _suppressNextSignInNotification = true;
      await _authRepository.signInWithEmail(
        email: email,
        password: currentPassword,
      );
    } on RepositoryInvalidCredentialsException {
      _suppressNextSignInNotification = false;
      throw const IncorrectCurrentPasswordException();
    }

    await _authRepository.updatePassword(newPassword: newPassword);
    _suppressNextSignOutNotification = true;
    await _authRepository.signOut(allSessions: true);
    _isPasswordRecovery = false;
    _setCurrentUser(null, notify: false);
  }

  @override
  Future<void> refreshCurrentUser() async {
    final authUser = _authRepository.currentUser;
    if (authUser == null) {
      _setCurrentUser(null);
      return;
    }
    await _loadProfile(authUser);
  }

  @override
  Future<void> logout() async {
    _suppressNextSignOutNotification = true;
    await _authRepository.signOut();
    _isPasswordRecovery = false;
    _setCurrentUser(null, notify: false);
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
      if (_suppressNextSignOutNotification) {
        _suppressNextSignOutNotification = false;
        _isPasswordRecovery = false;
        _currentUser = null;
        return;
      }
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
    await _loadProfile(authUser);
  }

  Future<void> _loadProfile(
      AuthUserData authUser, {
        bool notify = true,
      }) async {
    var profile = await _userRepository.getUserProfileById(authUser.id);
    if (profile == null) {
      final now = DateTime.now();
      profile = User(
        userId: authUser.id,
        fullName: _resolveName(authUser),
        email: authUser.email,
        currency: authUser.metadata['currency'] as String? ?? 'MYR',
        createdAt: now,
        updatedAt: now, authId: '',
      );
      await _userRepository.createUserProfile(profile);
    }

    _setCurrentUser(
      profile.copyWith(isEmailVerified: authUser.isEmailVerified),
      notify: notify,
    );
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

  void _setCurrentUser(User? user, {bool notify = true}) {
    if (identical(_currentUser, user)) return;
    _currentUser = user;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
