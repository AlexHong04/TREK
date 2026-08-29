import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/email_submission_ui_state.dart';

class EmailSubmissionViewModel extends ChangeNotifier {
  final IAuthService _authService;

  EmailSubmissionViewModel(this._authService);

  EmailSubmissionUiState _uiState = const EmailSubmissionUiState();
  EmailSubmissionUiState get uiState => _uiState;
  bool _emailTouched = false;

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  void onEmailChanged(String value) {
    final emailError = _emailTouched ? _validateEmail(value) : null;
    _uiState = _uiState.copyWith(
      email: value,
      linkSent: false,
      emailError: emailError,
      clearEmailError: emailError == null,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void onEmailFocusLost() {
    _emailTouched = true;
    final error = _validateEmail(_uiState.email);
    _uiState = _uiState.copyWith(
      emailError: error,
      clearEmailError: error == null,
    );
    notifyListeners();
  }

  Future<void> onSendPressed() async {
    _emailTouched = true;
    final email = _uiState.email.trim();
    final emailError = _validateEmail(email);
    if (emailError != null) {
      _uiState = _uiState.copyWith(emailError: emailError);
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isLoading: true,
      clearEmailError: true,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      // Supabase deliberately returns the same response for registered and
      // unregistered emails, satisfying FR100_55 without account enumeration.
      await _authService.sendPasswordResetEmail(email: email);
      _uiState = _uiState.copyWith(isLoading: false, linkSent: true);
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to send the reset link. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> onResendPressed() => onSendPressed();

  void onUseAnotherEmailPressed() {
    _emailTouched = false;
    _uiState = const EmailSubmissionUiState();
    notifyListeners();
  }

  void consumeErrorMessage() {
    _uiState = _uiState.copyWith(clearErrorMessage: true);
  }

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Email address is required.';
    if (!_emailPattern.hasMatch(email)) {
      return 'Invalid email address. Email must follow local@domain.com format.';
    }
    return null;
  }
}

class EmailSubmissionViewModelScope extends StatelessWidget {
  final Widget child;

  const EmailSubmissionViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmailSubmissionViewModel(context.read<IAuthService>()),
      child: child,
    );
  }
}
