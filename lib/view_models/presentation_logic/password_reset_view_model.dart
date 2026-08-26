import 'package:flutter/foundation.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/password_reset_ui_state.dart';

class PasswordResetViewModel extends ChangeNotifier {
  final IAuthService _authService;

  PasswordResetViewModel(this._authService);

  PasswordResetUiState _uiState = const PasswordResetUiState();
  PasswordResetUiState get uiState => _uiState;

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _special =
  RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\;\[\]~`]');

  void onNewPasswordChanged(String value) {
    _uiState = _uiState.copyWith(
      newPassword: value,
      clearPasswordError: true,
      clearErrorMessage: true,
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

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'New password is required.';
    if (password.length < 8 ||
        !_uppercase.hasMatch(password) ||
        !_lowercase.hasMatch(password) ||
        !_digit.hasMatch(password) ||
        !_special.hasMatch(password)) {
      return 'Password must have at least 8 characters, one uppercase letter, one lowercase letter, one digit, and one special character.';
    }
    return null;
  }
}

