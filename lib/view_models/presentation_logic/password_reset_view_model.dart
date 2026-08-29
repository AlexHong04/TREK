import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/password_reset_ui_state.dart';

class PasswordResetViewModel extends ChangeNotifier {
  final IAuthService _authService;

  PasswordResetViewModel(this._authService);

  PasswordResetUiState _uiState = const PasswordResetUiState();
  PasswordResetUiState get uiState => _uiState;
  bool _passwordTouched = false;

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _special =
  RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\;\[\]~`]');

  void onNewPasswordChanged(String value) {
    final passwordError =
    _passwordTouched ? _validatePassword(value) : null;
    _uiState = _uiState.copyWith(
      newPassword: value,
      passwordError: passwordError,
      clearPasswordError: passwordError == null,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void onNewPasswordFocusLost() {
    _passwordTouched = true;
    final error = _validatePassword(_uiState.newPassword);
    _uiState = _uiState.copyWith(
      passwordError: error,
      clearPasswordError: error == null,
    );
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _uiState = _uiState.copyWith(
      obscurePassword: !_uiState.obscurePassword,
    );
    notifyListeners();
  }

  Future<void> onResetPressed() async {
    _passwordTouched = true;
    final passwordError = _validatePassword(_uiState.newPassword);
    if (passwordError != null) {
      _uiState = _uiState.copyWith(passwordError: passwordError);
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isLoading: true,
      clearPasswordError: true,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      await _authService.setNewPassword(newPassword: _uiState.newPassword);
      await _authService.logout();
      _uiState = _uiState.copyWith(
        isLoading: false,
        resetSucceeded: true,
      );
    } on PasswordReusedException {
      _uiState = _uiState.copyWith(
        isLoading: false,
        passwordError:
        'Your new password must be different from your old password.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage:
        'Unable to reset your password. The reset link may have expired.',
      );
    }
    notifyListeners();
  }

  void consumeResetSuccess() {
    _uiState = _uiState.copyWith(resetSucceeded: false);
    notifyListeners();
  }

  void consumeErrorMessage() {
    _uiState = _uiState.copyWith(clearErrorMessage: true);
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'New password is required.';
    if (password.length < 8 ||
        !_uppercase.hasMatch(password) ||
        !_lowercase.hasMatch(password) ||
        !_digit.hasMatch(password) ||
        !_special.hasMatch(password)) {
      return 'Complete the password requirements shown below.';
    }
    return null;
  }
}

class PasswordResetViewModelScope extends StatelessWidget {
  final Widget child;

  const PasswordResetViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PasswordResetViewModel(context.read<IAuthService>()),
      child: child,
    );
  }
}
