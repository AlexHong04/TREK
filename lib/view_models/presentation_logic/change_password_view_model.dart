import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../ui_state/change_password_ui_state.dart';

class ChangePasswordViewModel extends ChangeNotifier {
  final IAuthService _authService;
  bool _disposed = false;
  bool _currentTouched = false;
  bool _newTouched = false;

  ChangePasswordViewModel(this._authService) {
    _authService.addListener(_syncAccountMode);
    _syncAccountMode(notify: false);
  }

  ChangePasswordUiState _uiState = const ChangePasswordUiState();
  ChangePasswordUiState get uiState => _uiState;

  void _syncAccountMode({bool notify = true}) {
    final info = _authService.accountInfo;
    if (info == null) return;
    // Setting the first password changes accountInfo immediately. Keep this
    // page in Set Password mode until its success event has popped the route;
    // otherwise the same page briefly turns into Change Password and remains
    // on screen.
    if (_uiState.isSaving || _uiState.passwordSaved) {
      _uiState = _uiState.copyWith(isOffline: _authService.isOffline);
      if (notify) _notify();
      return;
    }
    final mode = info.hasPasswordSignIn
        ? PasswordPageMode.changePassword
        : PasswordPageMode.setPassword;
    _uiState = _uiState.copyWith(
      mode: mode,
      requiresRecentGoogleAuthentication:
      mode == PasswordPageMode.setPassword &&
          !info.hasRecentOAuthAuthentication,
      isOffline: _authService.isOffline,
    );
    if (notify) _notify();
  }

  void onCurrentPasswordChanged(String value) {
    final error = _currentTouched && value.isEmpty
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

  void onNewPasswordChanged(String value) {
    final error = _newTouched ? _validateNewPassword(value) : null;
    _uiState = _uiState.copyWith(
      newPassword: value,
      newPasswordError: error,
      clearNewPasswordError: error == null,
      clearErrorMessage: true,
    );
    _notify();
  }

  void onCurrentPasswordFocusLost() {
    if (_uiState.isSetMode) return;
    _currentTouched = true;
    final error = _uiState.currentPassword.isEmpty
        ? 'Current password is required.'
        : null;
    _uiState = _uiState.copyWith(
      currentPasswordError: error,
      clearCurrentPasswordError: error == null,
    );
    _notify();
  }

  void onNewPasswordFocusLost() {
    _newTouched = true;
    final error = _validateNewPassword(_uiState.newPassword);
    _uiState = _uiState.copyWith(
      newPasswordError: error,
      clearNewPasswordError: error == null,
    );
    _notify();
  }

  void toggleCurrentPasswordVisibility() {
    if (_uiState.isSaving) return;
    _uiState = _uiState.copyWith(
      obscureCurrentPassword: !_uiState.obscureCurrentPassword,
    );
    _notify();
  }

  void toggleNewPasswordVisibility() {
    if (_uiState.isSaving) return;
    _uiState = _uiState.copyWith(
      obscureNewPassword: !_uiState.obscureNewPassword,
    );
    _notify();
  }

  Future<void> savePassword() async {
    if (_uiState.isSaving || _uiState.mode == PasswordPageMode.loading) return;
    if (_uiState.isOffline) {
      _uiState = _uiState.copyWith(
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
      _notify();
      return;
    }
    if (_uiState.requiresRecentGoogleAuthentication) {
      _uiState = _uiState.copyWith(
        logoutRequested: true,
      );
      _notify();
      return;
    }

    _currentTouched = !_uiState.isSetMode;
    _newTouched = true;
    final currentError = !_uiState.isSetMode &&
        _uiState.currentPassword.isEmpty
        ? 'Current password is required.'
        : null;
    final newError = _validateNewPassword(_uiState.newPassword);
    if (currentError != null || newError != null) {
      _uiState = _uiState.copyWith(
        currentPasswordError: currentError,
        newPasswordError: newError,
        clearCurrentPasswordError: currentError == null,
        clearNewPasswordError: newError == null,
      );
      _notify();
      return;
    }

    _uiState = _uiState.copyWith(
      isSaving: true,
      passwordSaved: false,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    final wasSetMode = _uiState.isSetMode;
    try {
      if (wasSetMode) {
        await _authService.setPasswordForOAuthUser(
          newPassword: _uiState.newPassword,
        );
      } else {
        await _authService.changePassword(
          currentPassword: _uiState.currentPassword,
          newPassword: _uiState.newPassword,
        );
      }
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSaving: false,
        passwordSaved: true,
        successMessage: wasSetMode
            ? 'Password set successfully.'
            : 'Password changed. Please log in again.',
      );
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSaving: false,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } on IncorrectCurrentPasswordException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSaving: false,
        currentPasswordError: 'Current password is incorrect.',
      );
    } on PasswordReusedException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSaving: false,
        newPasswordError:
        'Your new password must differ from the current password.',
      );
    } on RecentAuthenticationRequiredException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSaving: false,
        requiresRecentGoogleAuthentication: true,
        logoutRequested: true,
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSaving: false,
        errorMessage: 'Unable to ${wasSetMode ? 'set' : 'change'} your password. Please try again.',
      );
    }
    _notify();
  }

  String? _validateNewPassword(String value) {
    final error = InputValidator.validateNewPassword(value);
    if (error != null) return error;
    if (!_uiState.isSetMode && value == _uiState.currentPassword) {
      return 'Your new password must differ from the current password.';
    }
    return null;
  }

  void consumeLogoutRequest() {
    _uiState = _uiState.copyWith(logoutRequested: false);
  }

  Future<void> logoutForGoogleReauthentication() async {
    if (_uiState.isLoggingOut) return;
    _uiState = _uiState.copyWith(isLoggingOut: true, clearErrorMessage: true);
    _notify();
    try {
      await _authService.logout();
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoggingOut: false,
        errorMessage: 'Unable to log out. Please try again.',
      );
      _notify();
    }
  }

  void consumeMessages() {
    _uiState = _uiState.copyWith(
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
  }

  void consumePasswordSaved() {
    _uiState = _uiState.copyWith(passwordSaved: false);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_syncAccountMode);
    super.dispose();
  }
}

class ChangePasswordViewModelScope extends StatelessWidget {
  final Widget child;

  const ChangePasswordViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChangePasswordViewModel(context.read<IAuthService>()),
      child: child,
    );
  }
}
