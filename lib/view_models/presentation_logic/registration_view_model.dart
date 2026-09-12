import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../../models/services/i_profile_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../ui_state/registration_ui_state.dart';

class RegistrationViewModel extends ChangeNotifier {
  final IAuthService _authService;
  final IProfileService _profileService;
  bool _disposed = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _googleSignInPending = false;
  int _googleSignInAttempt = 0;

  RegistrationViewModel(
      this._authService,
      this._profileService, {
        String initialEmail = '',
      }) : _uiState = RegistrationUiState(email: initialEmail.trim()) {
    _authService.addListener(_handleAuthStateChanged);
  }

  RegistrationUiState _uiState;
  RegistrationUiState get uiState => _uiState;

  Future<void> loadCurrencies() async {
    if (_uiState.isLoadingCurrencies) return;
    _uiState = _uiState.copyWith(isLoadingCurrencies: true);
    _notify();
    try {
      final currencies = await _profileService.getSupportedCurrencies();
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        availableCurrencies: currencies,
        isLoadingCurrencies: false,
      );
    } catch (_) {
      if (_disposed) return;
      // Keep the bundled fallback list. Registration itself still requires a
      // network connection and will display the dedicated offline message.
      _uiState = _uiState.copyWith(isLoadingCurrencies: false);
    }
    _notify();
  }

  void onEmailChanged(String value) {
    final error = _emailTouched ? InputValidator.validateEmail(value) : null;
    _uiState = _uiState.copyWith(
      email: value,
      emailError: error,
      clearEmailError: error == null,
      clearErrorMessage: true,
    );
    _notify();
  }

  void onPasswordChanged(String value) {
    final error =
    _passwordTouched ? InputValidator.validateNewPassword(value) : null;
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
    final error = InputValidator.validateNewPassword(_uiState.password);
    _uiState = _uiState.copyWith(
      passwordError: error,
      clearPasswordError: error == null,
    );
    _notify();
  }

  void onCurrencyChanged(String? value) {
    _uiState = _uiState.copyWith(
      currency: value ?? '',
      clearCurrencyError: true,
      clearErrorMessage: true,
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

  Future<void> onRegisterPressed() async {
    if (_uiState.isLoading || !_validate()) return;
    _uiState = _uiState.copyWith(
      isLoading: true,
      registrationSucceeded: false,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      final result = await _authService.register(
        email: InputValidator.normalizeEmail(_uiState.email),
        password: _uiState.password,
        currency: _uiState.currency,
      );
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        registrationSucceeded: true,
        successMessage: result.verificationEmailSent
            ? 'Account created. Verification link sent; verify within 7 days.'
            : 'Account created. Verify your email from Profile within 7 days.',
      );
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } on EmailAlreadyExistsException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        emailError: 'Email address is already registered.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to register. Please try again.',
      );
    }
    _notify();
  }

  Future<void> onGoogleSignInPressed() async {
    if (_uiState.isLoading) return;
    _googleSignInPending = true;
    _googleSignInAttempt++;
    _uiState = _uiState.copyWith(isLoading: true, clearErrorMessage: true);
    _notify();
    try {
      await _authService.signInWithGoogle();
      // Keep the form disabled while the OAuth browser returns to TREK.
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
    _googleSignInPending = false;
    _uiState = _uiState.copyWith(isLoading: false);
    _notify();
  }

  void _handleAuthStateChanged() {
    if (!_googleSignInPending || !_authService.isLoggedIn) return;
    _googleSignInPending = false;
    // Keep the form locked until the app-level auth listener replaces this
    // route. The profile synchronisation that follows OAuth can take a few
    // seconds, and controls must not become active during that hand-off.
  }

  bool _validate() {
    _emailTouched = true;
    _passwordTouched = true;
    final emailError = InputValidator.validateEmail(_uiState.email);
    final passwordError = InputValidator.validateNewPassword(_uiState.password);
    final currencyError = _uiState.currency.isEmpty
        ? 'Please select a currency.'
        : !_uiState.availableCurrencies.contains(_uiState.currency)
        ? 'Please select a supported currency.'
        : null;
    _uiState = _uiState.copyWith(
      emailError: emailError,
      passwordError: passwordError,
      currencyError: currencyError,
      clearEmailError: emailError == null,
      clearPasswordError: passwordError == null,
      clearCurrencyError: currencyError == null,
      clearErrorMessage: true,
    );
    _notify();
    return emailError == null &&
        passwordError == null &&
        currencyError == null;
  }

  void consumeRegistrationSuccess() {
    _uiState = _uiState.copyWith(
      registrationSucceeded: false,
      clearSuccessMessage: true,
    );
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
    _authService.removeListener(_handleAuthStateChanged);
    super.dispose();
  }
}

class RegistrationViewModelScope extends StatelessWidget {
  final Widget child;
  final String initialEmail;

  const RegistrationViewModelScope({
    super.key,
    required this.child,
    this.initialEmail = '',
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegistrationViewModel(
        context.read<IAuthService>(),
        context.read<IProfileService>(),
        initialEmail: initialEmail,
      )..loadCurrencies(),
      child: child,
    );
  }
}
