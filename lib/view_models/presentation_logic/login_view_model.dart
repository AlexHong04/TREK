import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../ui_state/login_ui_state.dart';

class LoginViewModel extends ChangeNotifier {
  final IAuthService _authService;
  bool _disposed = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _googleSignInPending = false;
  int _googleSignInAttempt = 0;

  LoginViewModel(
      this._authService, {
        String initialEmail = '',
      })
      : _uiState = LoginUiState(
    email: initialEmail.trim(),
    infoMessage: _authService.consumeSessionMessage(),
  ) {
    _authService.addListener(_handleAuthStateChanged);
  }

  LoginUiState _uiState;
  LoginUiState get uiState => _uiState;

  void onEmailChanged(String value) {
    final error = _emailTouched ? InputValidator.validateEmail(value) : null;
    _uiState = _uiState.copyWith(
      email: value,
      showMagicLinkOption: false,
      magicLinkSent: false,
      emailError: error,
      clearEmailError: error == null,
      clearErrorMessage: true,
    );
    _notify();
  }

  void onPasswordChanged(String value) {
    final error =
    _passwordTouched ? InputValidator.validateLoginPassword(value) : null;
    _uiState = _uiState.copyWith(
      password: value,
      passwordError: error,
      clearPasswordError: error == null,
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

  void onPasswordFocusLost() {
    _passwordTouched = true;
    final error = InputValidator.validateLoginPassword(_uiState.password);
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

  Future<void> onLoginPressed() async {
    // This guard runs synchronously, before Flutter has time to rebuild and
    // disable the button. Rapid taps therefore create only one request.
    if (_uiState.isLoading || !_validate()) return;
    _uiState = _uiState.copyWith(
      isLoading: true,
      loginSucceeded: false,
      showMagicLinkOption: false,
      magicLinkSent: false,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );
    _notify();

    try {
      await _authService.login(
        email: InputValidator.normalizeEmail(_uiState.email),
        password: _uiState.password,
      );
      if (_disposed) return;
      _uiState = _uiState.copyWith(isLoading: false, loginSucceeded: true);
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } on InvalidCredentialsException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Invalid email or password.',
      );
    } on AccountLockedException catch (error) {
      if (_disposed) return;
      final time = error.lockedUntil;
      final suffix = time == null
          ? 'Please try again after 5 minutes.'
          : 'Try again after ${_formatTime(time)}.';
      _uiState = _uiState.copyWith(
        isLoading: false,
        showMagicLinkOption: true,
        errorMessage:
        'Your account is temporarily locked. $suffix You can also use a secure email link.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to log in. Please try again.',
      );
    }
    _notify();
  }

  Future<void> onGoogleSignInPressed() async {
    if (_uiState.isLoading) return;
    _googleSignInPending = true;
    _googleSignInAttempt++;
    _uiState = _uiState.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );
    _notify();
    try {
      await _authService.signInWithGoogle();
      // Keep the form disabled while the browser hands control back to the
      // app. AuthService will navigate as soon as the OAuth session arrives.
    } on NetworkUnavailableException {
      if (_disposed) return;
      _googleSignInPending = false;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } catch (_) {
      if (_disposed) return;
      _googleSignInPending = false;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Google sign-in failed. Please try again.',
      );
    }
    _notify();
  }

  Future<void> onAppResumedAfterGoogleSignIn() async {
    if (!_googleSignInPending) return;
    final attempt = _googleSignInAttempt;
    await Future<void>.delayed(const Duration(seconds: 5));
    if (_disposed ||
        !_googleSignInPending ||
        attempt != _googleSignInAttempt ||
        _authService.isLoggedIn) {
      return;
    }
    // The user most likely cancelled or closed Google's browser flow.
    _googleSignInPending = false;
    _uiState = _uiState.copyWith(isLoading: false);
    _notify();
  }

  void _handleAuthStateChanged() {
    if (!_googleSignInPending || !_authService.isLoggedIn) return;
    _googleSignInPending = false;
    _uiState = _uiState.copyWith(isLoading: false);
    _notify();
  }

  Future<void> onSendMagicLinkPressed() async {
    if (_uiState.isLoading || !_uiState.showMagicLinkOption) return;
    _uiState = _uiState.copyWith(isLoading: true, clearErrorMessage: true);
    _notify();
    try {
      await _authService.sendMagicLinkForLockedAccount(
        email: InputValidator.normalizeEmail(_uiState.email),
      );
      if (_disposed) return;
      _uiState = _uiState.copyWith(isLoading: false, magicLinkSent: true);
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
        errorMessage: 'Unable to send the secure login link. Please try again.',
      );
    }
    _notify();
  }

  bool _validate() {
    _emailTouched = true;
    _passwordTouched = true;
    final emailError = InputValidator.validateEmail(_uiState.email);
    final passwordError =
    InputValidator.validateLoginPassword(_uiState.password);
    _uiState = _uiState.copyWith(
      emailError: emailError,
      passwordError: passwordError,
      clearEmailError: emailError == null,
      clearPasswordError: passwordError == null,
      clearErrorMessage: true,
    );
    _notify();
    return emailError == null && passwordError == null;
  }

  void consumeLoginSuccess() {
    _uiState = _uiState.copyWith(loginSucceeded: false);
  }

  void consumeMessages() {
    _uiState = _uiState.copyWith(
      clearErrorMessage: true,
      clearInfoMessage: true,
    );
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_handleAuthStateChanged);
    super.dispose();
  }
}

class LoginViewModelScope extends StatelessWidget {
  final Widget child;
  final String initialEmail;

  const LoginViewModelScope({
    super.key,
    required this.child,
    this.initialEmail = '',
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginViewModel>(
      create: (_) => LoginViewModel(
        context.read<IAuthService>(),
        initialEmail: initialEmail,
      ),
      child: child,
    );
  }
}
