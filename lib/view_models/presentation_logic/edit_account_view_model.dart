import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../ui_state/edit_account_ui_state.dart';

class EditAccountViewModel extends ChangeNotifier {
  final IAuthService _authService;
  bool _disposed = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _loadInProgress = false;
  int _googleLinkAttempt = 0;
  int _googleUnlinkAttempt = 0;

  EditAccountViewModel(this._authService) {
    _authService.addListener(_syncAccount);
    _syncAccount(notify: false);
  }

  EditAccountUiState _uiState = const EditAccountUiState();
  EditAccountUiState get uiState => _uiState;

  Future<void> load() async {
    if (_loadInProgress ||
        _uiState.isSavingEmail ||
        _uiState.isLinkingGoogle ||
        _uiState.isUnlinkingGoogle ||
        _uiState.isRequestingDeletion) {
      return;
    }
    _loadInProgress = true;
    _uiState = _uiState.copyWith(isLoading: true, clearErrorMessage: true);
    _notify();
    try {
      await _authService.refreshCurrentUser();
      if (_disposed) return;
      _syncAccount(notify: false);
      _uiState = _uiState.copyWith(isLoading: false);
    } on NetworkUnavailableException {
      if (_disposed) return;
      _syncAccount(notify: false);
      _uiState = _uiState.copyWith(isLoading: false, isOffline: true);
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load account settings. Please try again.',
      );
    } finally {
      _loadInProgress = false;
    }
    _notify();
  }

  Future<void> linkGoogle({required String currentPassword}) async {
    if (_uiState.isBusy || !_requireOnline()) return;
    if (_uiState.hasGoogleIdentity) return;
    if (_uiState.hasPasswordSignIn && currentPassword.isEmpty) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Current password is required to link Google.',
      );
      _notify();
      return;
    }

    final attempt = ++_googleLinkAttempt;
    _uiState = _uiState.copyWith(
      isLinkingGoogle: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      // This only opens Google's OAuth page. Completion arrives later through
      // Supabase's deep-link/auth-state listener.
      await _authService.linkGoogle(currentPassword: currentPassword);
    } on NetworkUnavailableException {
      if (_disposed || attempt != _googleLinkAttempt) return;
      _showOfflineError(isLinkingGoogle: true);
    } on GoogleIdentityAlreadyLinkedException {
      if (_disposed || attempt != _googleLinkAttempt) return;
      _uiState = _uiState.copyWith(
        isLinkingGoogle: false,
        errorMessage:
        'That Google account is already linked to another TREK account.',
      );
      _notify();
    } on ManualIdentityLinkingDisabledException {
      if (_disposed || attempt != _googleLinkAttempt) return;
      _uiState = _uiState.copyWith(
        isLinkingGoogle: false,
        errorMessage:
        'Google linking is not enabled in Supabase. Enable Manual Linking in Authentication settings.',
      );
      _notify();
    } on GoogleIdentityOperationInProgressException {
      if (_disposed || attempt != _googleLinkAttempt) return;
      _uiState = _uiState.copyWith(
        isLinkingGoogle: false,
        errorMessage: 'Another Google account action is already in progress.',
      );
      _notify();
    } on IncorrectCurrentPasswordException {
      if (_disposed || attempt != _googleLinkAttempt) return;
      _uiState = _uiState.copyWith(
        isLinkingGoogle: false,
        errorMessage: 'Current password is incorrect.',
      );
      _notify();
    } on RecentAuthenticationRequiredException {
      if (_disposed || attempt != _googleLinkAttempt) return;
      _uiState = _uiState.copyWith(
        isLinkingGoogle: false,
        errorMessage:
        'Sign in with Google again before linking another sign-in method.',
      );
      _notify();
    } catch (_) {
      if (_disposed || attempt != _googleLinkAttempt) return;
      _uiState = _uiState.copyWith(
        isLinkingGoogle: false,
        errorMessage: 'Unable to start Google linking. Please try again.',
      );
      _notify();
    }
  }

  Future<void> onAppResumedAfterGoogleLink() async {
    if (_disposed || !_uiState.isLinkingGoogle) return;
    final attempt = _googleLinkAttempt;
    // Give Supabase's deep-link listener time to exchange the callback code.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (_disposed ||
        attempt != _googleLinkAttempt ||
        !_uiState.isLinkingGoogle) {
      return;
    }
    try {
      await _authService.refreshCurrentUser();
      if (_disposed || attempt != _googleLinkAttempt) return;
      _syncAccount(notify: false);
      if (_uiState.hasGoogleIdentity) {
        _uiState = _uiState.copyWith(
          isLinkingGoogle: false,
          successMessage: 'Google account linked.',
        );
      } else {
        _uiState = _uiState.copyWith(
          isLinkingGoogle: false,
          errorMessage:
          'Google linking was cancelled or could not be completed. If the Google account already belongs to another TREK account, choose a different one.',
        );
      }
    } on NetworkUnavailableException {
      if (_disposed || attempt != _googleLinkAttempt) return;
      _showOfflineError(isLinkingGoogle: true);
      return;
    } catch (_) {
      if (_disposed || attempt != _googleLinkAttempt) return;
      _uiState = _uiState.copyWith(
        isLinkingGoogle: false,
        errorMessage: 'Unable to confirm whether Google was linked.',
      );
    }
    _notify();
  }

  void onNewEmailChanged(String value) {
    final error = _emailTouched ? InputValidator.validateEmail(value) : null;
    final emailChanged = InputValidator.normalizeEmail(value).toLowerCase() !=
        _uiState.accountEmail.trim().toLowerCase();
    final shouldClearPassword = _uiState.isEmailVerified || !emailChanged;
    _uiState = _uiState.copyWith(
      newEmail: value,
      emailChangeRequested: false,
      newEmailError: error,
      currentPassword:
      shouldClearPassword ? '' : _uiState.currentPassword,
      clearNewEmailError: error == null,
      clearCurrentPasswordError: shouldClearPassword,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
  }

  void onEmailFocusLost() {
    _emailTouched = true;
    final error = InputValidator.validateEmail(_uiState.newEmail);
    _uiState = _uiState.copyWith(
      newEmailError: error,
      clearNewEmailError: error == null,
    );
    _notify();
  }

  void onCurrentPasswordChanged(String value) {
    final error = _passwordTouched && value.isEmpty
        ? 'Current password is required.'
        : null;
    _uiState = _uiState.copyWith(
      currentPassword: value,
      currentPasswordError: error,
      clearCurrentPasswordError: error == null,
      clearErrorMessage: true,
    );
    _notify();
  }

  void onCurrentPasswordFocusLost() {
    if (!_uiState.hasPasswordSignIn) return;
    _passwordTouched = true;
    final error = _uiState.currentPassword.isEmpty
        ? 'Current password is required.'
        : null;
    _uiState = _uiState.copyWith(
      currentPasswordError: error,
      clearCurrentPasswordError: error == null,
    );
    _notify();
  }

  void togglePasswordVisibility() {
    if (_uiState.isBusy) return;
    _uiState = _uiState.copyWith(
      obscureCurrentPassword: !_uiState.obscureCurrentPassword,
    );
    _notify();
  }

  Future<void> saveEmail() async {
    if (_uiState.isGoogleManagedAccount) return;
    if (_uiState.isBusy ||
        _uiState.emailChangeCooldownSeconds > 0 ||
        !_requireOnline()) {
      return;
    }
    _emailTouched = true;
    final normalizedEmail = InputValidator.normalizeEmail(_uiState.newEmail);
    final emailError = InputValidator.validateEmail(normalizedEmail);
    if (emailError != null) {
      _uiState = _uiState.copyWith(
        newEmailError: emailError,
        clearCurrentPasswordError: true,
      );
      _notify();
      return;
    }
    if (normalizedEmail.toLowerCase() ==
        _uiState.accountEmail.trim().toLowerCase()) {
      _uiState = _uiState.copyWith(
        newEmailError: 'Enter a different email address.',
        currentPassword: '',
        clearCurrentPasswordError: true,
      );
      _notify();
      return;
    }

    final requiresPassword =
        !_uiState.isEmailVerified && _uiState.hasPasswordSignIn;
    final passwordError = _requiredPasswordError(required: requiresPassword);
    if (passwordError != null) {
      _uiState = _uiState.copyWith(
        currentPasswordError: passwordError,
        clearNewEmailError: true,
      );
      _notify();
      return;
    }

    _uiState = _uiState.copyWith(
      isSavingEmail: true,
      emailChangeRequested: false,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      await _authService.changeAccountEmail(
        newEmail: normalizedEmail,
        currentPassword: requiresPassword ? _uiState.currentPassword : null,
      );
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSavingEmail: false,
        emailChangeRequested: true,
        currentPassword: '',
        successMessage: _uiState.isEmailVerified
            ? 'Confirm the links sent to your current and new email addresses.'
            : 'Check the new email address to complete the change.',
        clearCurrentPasswordError: true,
      );
    } on NetworkUnavailableException {
      _showOfflineError(isSavingEmail: true);
      return;
    } on EmailRequestRateLimitedException catch (error) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSavingEmail: false,
        emailChangeCooldownSeconds: error.retryAfterSeconds,
      );
    } on EmailAlreadyExistsException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSavingEmail: false,
        newEmailError: 'Email address is already registered.',
      );
    } on IncorrectCurrentPasswordException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSavingEmail: false,
        currentPasswordError: 'Current password is incorrect.',
      );
    } on RecentAuthenticationRequiredException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSavingEmail: false,
        errorMessage:
        'For security, log out and sign in with Google again before changing the email.',
      );
    } on AccountEmailChangeException catch (error) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSavingEmail: false,
        errorMessage: error.message,
      );
    } on GoogleManagedAccountException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSavingEmail: false,
        clearErrorMessage: true,
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSavingEmail: false,
        errorMessage: 'Unable to change the account email. Please try again.',
      );
    }
    _notify();
  }

  Future<void> unlinkGoogle({required String currentPassword}) async {
    if (_uiState.isGoogleManagedAccount) return;
    if (_uiState.isBusy || !_requireOnline()) return;
    if (_uiState.hasPasswordSignIn && currentPassword.isEmpty) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Current password is required to unlink Google.',
      );
      _notify();
      return;
    }
    if (!_uiState.canUnlinkGoogle) {
      _uiState = _uiState.copyWith(
        errorMessage: _uiState.hasPasswordSignIn
            ? 'Email/password sign-in is ready, but Supabase requires at least two linked identities before Google can be unlinked.'
            : 'Set a password before unlinking Google.',
      );
      _notify();
      return;
    }

    final attempt = ++_googleUnlinkAttempt;
    _uiState = _uiState.copyWith(
      isUnlinkingGoogle: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      await _authService.unlinkGoogle(
        currentPassword: currentPassword,
      );
      if (_disposed || attempt != _googleUnlinkAttempt) return;
      _syncAccount(notify: false);
      _uiState = _uiState.copyWith(
        isUnlinkingGoogle: false,
        googleUnlinked: true,
        currentPassword: '',
        successMessage: 'Google sign-in unlinked.',
        clearCurrentPasswordError: true,
      );
    } on NetworkUnavailableException {
      if (_disposed || attempt != _googleUnlinkAttempt) return;
      _showOfflineError(isUnlinkingGoogle: true);
      return;
    } on IncorrectCurrentPasswordException {
      if (_disposed || attempt != _googleUnlinkAttempt) return;
      _uiState = _uiState.copyWith(
        isUnlinkingGoogle: false,
        errorMessage: 'Current password is incorrect.',
      );
    } on MissingEmailIdentityForGoogleUnlinkException {
      if (_disposed || attempt != _googleUnlinkAttempt) return;
      _uiState = _uiState.copyWith(
        isUnlinkingGoogle: false,
        errorMessage:
        'Email/password sign-in is ready, but Supabase requires at least two linked identities before Google can be unlinked.',
      );
    } on CannotUnlinkGoogleException {
      if (_disposed || attempt != _googleUnlinkAttempt) return;
      _uiState = _uiState.copyWith(
        isUnlinkingGoogle: false,
        errorMessage:
        'Google cannot be unlinked until another sign-in method is available.',
      );
    } on GoogleIdentityOperationInProgressException {
      if (_disposed || attempt != _googleUnlinkAttempt) return;
      _uiState = _uiState.copyWith(
        isUnlinkingGoogle: false,
        errorMessage: 'Another Google account action is already in progress.',
      );
    } catch (_) {
      if (_disposed || attempt != _googleUnlinkAttempt) return;
      _uiState = _uiState.copyWith(
        isUnlinkingGoogle: false,
        errorMessage: 'Unable to unlink Google. Please try again.',
      );
    }
    _notify();
  }

  /// The screen owns the first destructive warning. Call this only after that
  /// dialog has been accepted.
  Future<void> requestDeletion({String? currentPassword}) async {
    if (_uiState.isBusy ||
        (_uiState.isEmailVerified &&
            _uiState.deletionCooldownSeconds > 0) ||
        !_requireOnline()) {
      return;
    }
    // A verified account confirms deletion through its one-time email link.
    // Only an unverified account, which skips that email step, needs immediate
    // password/OAuth reauthentication here.
    final requiresPassword =
        !_uiState.isEmailVerified && _uiState.hasPasswordSignIn;
    if (requiresPassword && (currentPassword ?? '').isEmpty) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Current password is required to delete the account.',
      );
      _notify();
      return;
    }
    _uiState = _uiState.copyWith(
      isRequestingDeletion: true,
      deletionEmailSent: false,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      final ready = await _authService.requestAccountDeletion(
        currentPassword: requiresPassword ? currentPassword : null,
      );
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isRequestingDeletion: false,
        deletionReady: ready,
        deletionEmailSent: !ready,
        currentPassword: '',
        successMessage: ready
            ? 'Identity confirmed. Review the final deletion screen.'
            : 'Confirmation link sent to your account email.',
        clearCurrentPasswordError: true,
      );
    } on NetworkUnavailableException {
      _showOfflineError(isRequestingDeletion: true);
      return;
    } on EmailRequestRateLimitedException catch (error) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isRequestingDeletion: false,
        deletionCooldownSeconds: error.retryAfterSeconds,
      );
    } on IncorrectCurrentPasswordException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isRequestingDeletion: false,
        errorMessage: 'Current password is incorrect.',
      );
    } on RecentAuthenticationRequiredException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isRequestingDeletion: false,
        errorMessage: _uiState.hasGoogleIdentity
            ? 'For security, log out and sign in with Google again before deleting the account.'
            : 'Enter your current password to confirm account deletion.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isRequestingDeletion: false,
        errorMessage: 'Unable to request account deletion. Please try again.',
      );
    }
    _notify();
  }

  String? _requiredPasswordError({required bool required}) {
    if (!required) return null;
    _passwordTouched = true;
    return _uiState.currentPassword.isEmpty
        ? 'Current password is required.'
        : null;
  }

  bool _requireOnline() {
    if (!_authService.isOffline) return true;
    _uiState = _uiState.copyWith(
      isOffline: true,
      errorMessage:
      'No internet connection. Account changes are unavailable while offline.',
    );
    _notify();
    return false;
  }

  void _showOfflineError({
    bool isSavingEmail = false,
    bool isLinkingGoogle = false,
    bool isUnlinkingGoogle = false,
    bool isRequestingDeletion = false,
  }) {
    if (_disposed) return;
    _uiState = _uiState.copyWith(
      isOffline: true,
      isSavingEmail: isSavingEmail ? false : _uiState.isSavingEmail,
      isLinkingGoogle:
      isLinkingGoogle ? false : _uiState.isLinkingGoogle,
      isUnlinkingGoogle:
      isUnlinkingGoogle ? false : _uiState.isUnlinkingGoogle,
      isRequestingDeletion:
      isRequestingDeletion ? false : _uiState.isRequestingDeletion,
      errorMessage: 'No internet connection. Check your connection and try again.',
    );
    _notify();
  }

  void _syncAccount({bool notify = true}) {
    final user = _authService.currentUser;
    final info = _authService.accountInfo;
    if (user == null || info == null) return;
    final shouldReplaceDraft = _uiState.accountEmail.isEmpty ||
        _uiState.newEmail == _uiState.accountEmail;
    final googleWasJustLinked =
        _uiState.isLinkingGoogle && info.hasGoogleIdentity;
    _uiState = _uiState.copyWith(
      accountEmail: user.email,
      newEmail: shouldReplaceDraft ? user.email : _uiState.newEmail,
      googleEmail: info.googleEmail,
      isEmailVerified: user.isEmailVerified,
      currentPassword:
      user.isEmailVerified ? '' : _uiState.currentPassword,
      hasPasswordSignIn: info.hasPasswordSignIn,
      hasEmailIdentity: info.hasEmailIdentity,
      hasGoogleIdentity: info.hasGoogleIdentity,
      canUnlinkGoogle: info.canUnlinkGoogle,
      emailChangeCooldownSeconds: _authService.emailCooldownSeconds(
        EmailActionType.emailChange,
      ),
      deletionCooldownSeconds: _authService.emailCooldownSeconds(
        EmailActionType.accountDeletion,
      ),
      isLinkingGoogle:
      googleWasJustLinked ? false : _uiState.isLinkingGoogle,
      isOffline: _authService.isOffline,
      isLoading: false,
      clearGoogleEmail: info.googleEmail == null,
      clearCurrentPasswordError: user.isEmailVerified,
    );
    if (googleWasJustLinked) {
      _uiState = _uiState.copyWith(successMessage: 'Google account linked.');
    }
    if (notify) _notify();
  }

  void consumeMessages() {
    _uiState = _uiState.copyWith(
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _googleLinkAttempt++;
    _googleUnlinkAttempt++;
    _authService.removeListener(_syncAccount);
    super.dispose();
  }
}

class EditAccountViewModelScope extends StatelessWidget {
  final Widget child;

  const EditAccountViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditAccountViewModel(context.read<IAuthService>())..load(),
      child: child,
    );
  }
}
