import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/registration_ui_state.dart';

/// Presentation logic for UC100 A1 — Register Account.
class RegistrationViewModel extends ChangeNotifier {
  final IAuthService _authService;

  RegistrationViewModel(this._authService);

  RegistrationUiState _uiState = const RegistrationUiState();
  RegistrationUiState get uiState => _uiState;
  bool _emailTouched = false;
  bool _passwordTouched = false;

  Future<void> loadCurrencies() async {
    if (_uiState.isLoadingCurrencies) return;
    _uiState = _uiState.copyWith(isLoadingCurrencies: true);
    notifyListeners();
    try {
      final currencies = await _authService.getSupportedCurrencies();
      _uiState = _uiState.copyWith(
        availableCurrencies: currencies,
        isLoadingCurrencies: false,
      );
    } catch (_) {
      // Keep the bundled fallback list so registration remains usable offline.
      _uiState = _uiState.copyWith(isLoadingCurrencies: false);
    }
    notifyListeners();
  }

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );
  static final RegExp _uppercasePattern = RegExp(r'[A-Z]');
  static final RegExp _lowercasePattern = RegExp(r'[a-z]');
  static final RegExp _digitPattern = RegExp(r'\d');
  static final RegExp _specialPattern =
  RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\;\[\]~`]');

  void onEmailChanged(String value) {
    final emailError = _emailTouched ? _validateEmail(value) : null;
    _uiState = _uiState.copyWith(
      email: value,
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

  void onCurrencyChanged(String? value) {
    _uiState = _uiState.copyWith(
      currency: value ?? '',
      clearCurrencyError: true,
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

  Future<void> onRegisterPressed() async {
    if (!_validate()) return;

    _uiState = _uiState.copyWith(
      isLoading: true,
      registrationSucceeded: false,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();

    try {
      await _authService.register(
        email: _uiState.email,
        password: _uiState.password,
        currency: _uiState.currency,
      );
      _uiState = _uiState.copyWith(
        isLoading: false,
        registrationSucceeded: true,
        successMessage: 'Account created successfully. Welcome to TREK!',
      );
    } on EmailAlreadyExistsException {
      _uiState = _uiState.copyWith(
        isLoading: false,
        emailError: 'Email already exists.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to register. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> onGoogleSignInPressed() async {
    if (_uiState.isLoading) return;
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

  /// Prevents a successful navigation/snackbar event from firing twice.
  void consumeRegistrationSuccess() {
    _uiState = _uiState.copyWith(registrationSucceeded: false);
    notifyListeners();
  }

  bool _validate() {
    _emailTouched = true;
    _passwordTouched = true;
    final emailError = _validateEmail(_uiState.email);
    final passwordError = _validatePassword(_uiState.password);

    final currencyError = _uiState.currency.isEmpty
        ? 'Please select a currency.'
        : !_uiState.availableCurrencies.contains(_uiState.currency)
        ? 'Please select a supported currency.'
        : null;
    final isValid = emailError == null &&
        passwordError == null &&
        currencyError == null;

    _uiState = _uiState.copyWith(
      emailError: emailError,
      passwordError: passwordError,
      currencyError: currencyError,
      clearEmailError: emailError == null,
      clearPasswordError: passwordError == null,
      clearCurrencyError: currencyError == null,
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

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password is required.';
    if (!_isValidPassword(password)) {
      return 'Complete the password requirements shown below.';
    }
    return null;
  }

  bool _isValidPassword(String password) {
    return password.length >= 8 &&
        _uppercasePattern.hasMatch(password) &&
        _lowercasePattern.hasMatch(password) &&
        _digitPattern.hasMatch(password) &&
        _specialPattern.hasMatch(password);
  }
}

class RegistrationViewModelScope extends StatelessWidget {
  final Widget child;

  const RegistrationViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegistrationViewModel(context.read<IAuthService>())
        ..loadCurrencies(),
      child: child,
    );
  }
}
