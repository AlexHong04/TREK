import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../ui_state/email_submission_ui_state.dart';

class EmailSubmissionViewModel extends ChangeNotifier {
  final IAuthService _authService;
  bool _disposed = false;
  bool _emailTouched = false;

  EmailSubmissionViewModel(
      this._authService, {
        String initialEmail = '',
      }) : _uiState = EmailSubmissionUiState(email: initialEmail.trim());

  EmailSubmissionUiState _uiState;
  EmailSubmissionUiState get uiState => _uiState;

  void onEmailChanged(String value) {
    final error = _emailTouched ? InputValidator.validateEmail(value) : null;
    _uiState = _uiState.copyWith(
      email: value,
      linkSent: false,
      emailError: error,
      clearEmailError: error == null,
      clearErrorMessage: true,
    );
    _notify();
  }

  void onEmailFocusLost() {
    _emailTouched = true;
    final error = InputValidator.validateEmail(_uiState.email);
    _uiState = _uiState.copyWith(
      emailError: error,
      clearEmailError: error == null,
    );
    _notify();
  }

  Future<void> onSendPressed() async {
    if (_uiState.isLoading) return;
    _emailTouched = true;
    final error = InputValidator.validateEmail(_uiState.email);
    if (error != null) {
      _uiState = _uiState.copyWith(emailError: error);
      _notify();
      return;
    }

    _uiState = _uiState.copyWith(
      isLoading: true,
      clearEmailError: true,
      clearErrorMessage: true,
    );
    _notify();
    try {
      // Supabase deliberately returns the same outward result for registered
      // and unregistered addresses, preventing account enumeration.
      await _authService.sendPasswordResetEmail(
        email: InputValidator.normalizeEmail(_uiState.email),
      );
      if (_disposed) return;
      _uiState = _uiState.copyWith(isLoading: false, linkSent: true);
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to send the reset link. Please try again.',
      );
    }
    _notify();
  }

  Future<void> onResendPressed() => onSendPressed();

  void onUseAnotherEmailPressed() {
    if (_uiState.isLoading) return;
    _emailTouched = false;
    _uiState = const EmailSubmissionUiState();
    _notify();
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

class EmailSubmissionViewModelScope extends StatelessWidget {
  final Widget child;
  final String initialEmail;

  const EmailSubmissionViewModelScope({
    super.key,
    required this.child,
    this.initialEmail = '',
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmailSubmissionViewModel(
        context.read<IAuthService>(),
        initialEmail: initialEmail,
      ),
      child: child,
    );
  }
}
