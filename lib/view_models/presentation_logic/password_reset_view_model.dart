import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../ui_state/password_reset_ui_state.dart';

class PasswordResetViewModel extends ChangeNotifier {
  final IAuthService _authService;
  bool _disposed = false;
  bool _passwordTouched = false;

  PasswordResetViewModel(this._authService);

  PasswordResetUiState _uiState = const PasswordResetUiState();
  PasswordResetUiState get uiState => _uiState;

  void onNewPasswordChanged(String value) {
    final passwordError =
    _passwordTouched ? InputValidator.validateNewPassword(value) : null;
    _uiState = _uiState.copyWith(
      newPassword: value,
      passwordError: passwordError,
      clearPasswordError: passwordError == null,
      clearErrorMessage: true,
    );
    _notify();
  }

  void onNewPasswordFocusLost() {
    _passwordTouched = true;
    final error = InputValidator.validateNewPassword(_uiState.newPassword);
    _uiState = _uiState.copyWith(
      passwordError: error,
      clearPasswordError: error == null,
    );
    _notify();
  }

  void togglePasswordVisibility() {
    if (_uiState.isLoading) return;
    _uiState = _uiState.copyWith(
      obscurePassword: !_uiState.obscurePassword,
    );
    _notify();
  }

  Future<void> onResetPressed() async {
    if (_uiState.isLoading) return;
    _passwordTouched = true;
    final passwordError =
    InputValidator.validateNewPassword(_uiState.newPassword);
    if (passwordError != null) {
      _uiState = _uiState.copyWith(
        passwordError: passwordError,
        clearPasswordError: passwordError == null,
      );
      _notify();
      return;
    }

    _uiState = _uiState.copyWith(
      isLoading: true,
      clearPasswordError: true,
      clearErrorMessage: true,
    );
    _notify();
    try {
      await _authService.setNewPasswordFromRecovery(
        newPassword: _uiState.newPassword,
      );
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        resetSucceeded: true,
      );
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } on PasswordReusedException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        passwordError: 'Your new password must differ from your old password.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage:
        'Unable to reset your password. The reset link may have expired.',
      );
    }
    _notify();
  }

  void consumeResetSuccess() {
    _uiState = _uiState.copyWith(resetSucceeded: false);
  }

  void consumeErrorMessage() {
    _uiState = _uiState.copyWith(clearErrorMessage: true);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
