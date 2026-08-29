import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/change_password_ui_state.dart';

class ChangePasswordViewModel extends ChangeNotifier {
  final IAuthService _authService;

  ChangePasswordViewModel(this._authService);

  ChangePasswordUiState _uiState = const ChangePasswordUiState();
  ChangePasswordUiState get uiState => _uiState;
  bool _currentPasswordTouched = false;
  bool _newPasswordTouched = false;

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _special =
  RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\;\[\]~`]');

  void onCurrentPasswordChanged(String value) {
    final error = _currentPasswordTouched && value.isEmpty
        ? 'Current password is required.'
        : null;
    _uiState = _uiState.copyWith(
      currentPassword: value,
      currentPasswordError: error,
      clearCurrentPasswordError: error == null,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void onNewPasswordChanged(String value) {
    final error = _newPasswordTouched ? _validateNewPassword(value) : null;
    _uiState = _uiState.copyWith(
      newPassword: value,
      newPasswordError: error,
      clearNewPasswordError: error == null,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void onCurrentPasswordFocusLost() {
    _currentPasswordTouched = true;
    final error = _uiState.currentPassword.isEmpty
        ? 'Current password is required.'
        : null;
    _uiState = _uiState.copyWith(
      currentPasswordError: error,
      clearCurrentPasswordError: error == null,
    );
    notifyListeners();
  }

  void onNewPasswordFocusLost() {
    _newPasswordTouched = true;
    final error = _validateNewPassword(_uiState.newPassword);
    _uiState = _uiState.copyWith(
      newPasswordError: error,
      clearNewPasswordError: error == null,
    );
    notifyListeners();
  }

  void toggleCurrentPasswordVisibility() {
    _uiState = _uiState.copyWith(
      obscureCurrentPassword: !_uiState.obscureCurrentPassword,
    );
    notifyListeners();
  }

  void toggleNewPasswordVisibility() {
    _uiState = _uiState.copyWith(
      obscureNewPassword: !_uiState.obscureNewPassword,
    );
    notifyListeners();
  }

  Future<void> changePassword() async {
    if (_uiState.isSaving) return;
    _currentPasswordTouched = true;
    _newPasswordTouched = true;
    final currentError = _uiState.currentPassword.isEmpty
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
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isSaving: true,
      passwordChanged: false,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      await _authService.changePassword(
        currentPassword: _uiState.currentPassword,
        newPassword: _uiState.newPassword,
      );
      _uiState = _uiState.copyWith(
        isSaving: false,
        passwordChanged: true,
      );
    } on IncorrectCurrentPasswordException {
      _uiState = _uiState.copyWith(
        isSaving: false,
        currentPasswordError: 'Current password is incorrect.',
      );
    } on PasswordReusedException {
      _uiState = _uiState.copyWith(
        isSaving: false,
        newPasswordError:
        'Your new password must be different from the current password.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isSaving: false,
        errorMessage: 'Unable to change your password. Please try again.',
      );
    }
    notifyListeners();
  }

  String? _validateNewPassword(String password) {
    if (password.isEmpty) return 'New password is required.';
    if (password == _uiState.currentPassword) {
      return 'Your new password must be different from the current password.';
    }
    if (password.length < 8 ||
        !_uppercase.hasMatch(password) ||
        !_lowercase.hasMatch(password) ||
        !_digit.hasMatch(password) ||
        !_special.hasMatch(password)) {
      return 'Complete the password requirements shown below.';
    }
    return null;
  }

  void consumeErrorMessage() {
    _uiState = _uiState.copyWith(clearErrorMessage: true);
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
