import 'package:flutter/foundation.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/login_ui_state.dart';

class LoginViewModel extends ChangeNotifier {
  final IAuthService _authService;

  LoginViewModel(this._authService);

  LoginUiState _uiState = const LoginUiState();
  LoginUiState get uiState => _uiState;

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  void onEmailChanged(String value) {
    _uiState = _uiState.copyWith(
      email: value,
      canResendVerification: false,
      verificationEmailSent: false,
      showMagicLinkOption: false,
      magicLinkSent: false,
      clearEmailError: true,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void onPasswordChanged(String value) {
    _uiState = _uiState.copyWith(
      password: value,
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

  Future<void> onLoginPressed() async {
    if (!_validate()) return;
    _uiState = _uiState.copyWith(
      isLoading: true,
      loginSucceeded: false,
      canResendVerification: false,
      verificationEmailSent: false,
      showMagicLinkOption: false,
      magicLinkSent: false,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      await _authService.login(
        email: _uiState.email,
        password: _uiState.password,
      );
      _uiState = _uiState.copyWith(
        isLoading: false,
        loginSucceeded: true,
      );
    } on InvalidCredentialsException {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Invalid email or password.',
      );
    } on AccountLockedException catch (error) {
      final time = error.lockedUntil;
      final suffix = time == null
          ? 'Please try again after 5 minutes.'
          : 'Try again after ${_formatTime(time)}.';
      _uiState = _uiState.copyWith(
        isLoading: false,
        showMagicLinkOption: true,
        errorMessage: 'Your account has been temporarily locked. $suffix',
      );
    } on EmailNotVerifiedException {
      _uiState = _uiState.copyWith(
        isLoading: false,
        canResendVerification: true,
        errorMessage:
        'Your email address has not been verified. Please check your inbox.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to log in. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> onGoogleSignInPressed() async {
    _uiState = _uiState.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      await _authService.signInWithGoogle();
      _uiState = _uiState.copyWith(isLoading: false);
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Google sign-in failed. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> onResendVerificationPressed() async {
    if (_uiState.isLoading || !_uiState.canResendVerification) return;
    _uiState = _uiState.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      await _authService.resendVerificationEmail(email: _uiState.email);
      _uiState = _uiState.copyWith(
        isLoading: false,
        verificationEmailSent: true,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage:
        'Unable to resend verification email. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> onSendMagicLinkPressed() async {
    if (_uiState.isLoading || !_uiState.showMagicLinkOption) return;
    _uiState = _uiState.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      await _authService.sendMagicLinkForLockedAccount(
        email: _uiState.email,
      );
      _uiState = _uiState.copyWith(
        isLoading: false,
        magicLinkSent: true,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to send secure login link. Please try again.',
      );
    }
    notifyListeners();
  }

  void consumeLoginSuccess() {
    _uiState = _uiState.copyWith(loginSucceeded: false);
    notifyListeners();
  }

  bool _validate() {
    final email = _uiState.email.trim();
    String? emailError;
    if (email.isEmpty) {
      emailError = 'Email address is required.';
    } else if (!_emailPattern.hasMatch(email)) {
      emailError =
      'Invalid email address. Email must follow local@domain.com format.';
    }
    final passwordError =
    _uiState.password.isEmpty ? 'Password is required.' : null;
    final isValid = emailError == null && passwordError == null;

    _uiState = _uiState.copyWith(
      emailError: emailError,
      passwordError: passwordError,
      clearEmailError: emailError == null,
      clearPasswordError: passwordError == null,
      clearErrorMessage: true,
    );
    notifyListeners();
    return isValid;
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
