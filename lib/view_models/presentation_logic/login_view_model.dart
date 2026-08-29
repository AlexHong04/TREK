import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/login_ui_state.dart';

class LoginViewModel extends ChangeNotifier {
  final IAuthService _authService;

  LoginViewModel(this._authService);

  LoginUiState _uiState = const LoginUiState();
  LoginUiState get uiState => _uiState;
  bool _emailTouched = false;
  bool _passwordTouched = false;

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  void onEmailChanged(String value) {
    final emailError = _emailTouched ? _validateEmail(value) : null;
    _uiState = _uiState.copyWith(
      email: value,
      canResendVerification: false,
      verificationEmailSent: false,
      showMagicLinkOption: false,
      magicLinkSent: false,
      emailError: emailError,
      clearEmailError: emailError == null,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void onPasswordChanged(String value) {
    final passwordError =
    _passwordTouched ? _validatePassword(value) : null;
    _uiState = _uiState.copyWith(
      password: value,
      passwordError: passwordError,
      clearPasswordError: passwordError == null,
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

  void onPasswordFocusLost() {
    _passwordTouched = true;
    final error = _validatePassword(_uiState.password);
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
        errorMessage:
        'Your account has been temporarily locked. $suffix You can also continue with an email magic link.',
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
    _emailTouched = true;
    _passwordTouched = true;
    final emailError = _validateEmail(_uiState.email);
    final passwordError = _validatePassword(_uiState.password);
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

  String? _validatePassword(String value) {
    return value.isEmpty ? 'Password is required.' : null;
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class LoginViewModelScope extends StatelessWidget {
  final Widget child;

  const LoginViewModelScope({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginViewModel>(
      create: (_) => LoginViewModel(context.read<IAuthService>()),
      child: child,
    );
  }
}
