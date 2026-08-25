import 'package:flutter/foundation.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/email_submission_ui_state.dart';

class EmailSubmissionViewModel extends ChangeNotifier {
  final IAuthService _authService;

  EmailSubmissionViewModel(this._authService);

  EmailSubmissionUiState _uiState = const EmailSubmissionUiState();
  EmailSubmissionUiState get uiState => _uiState;

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  void onEmailChanged(String value) {
    _uiState = _uiState.copyWith(
      email: value,
      linkSent: false,
      clearEmailError: true,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  Future<void> onSendPressed() async {
    final email = _uiState.email.trim();
    String? emailError;
    if (email.isEmpty) {
      emailError = 'Email address is required.';
    } else if (!_emailPattern.hasMatch(email)) {
      emailError =
      'Invalid email address. Email must follow local@domain.com format.';
    }
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
}

