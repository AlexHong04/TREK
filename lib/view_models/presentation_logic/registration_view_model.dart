import 'package:flutter/foundation.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/registration_ui_state.dart';

/// Presentation logic for UC100 A1 — Register Account.
class RegistrationViewModel extends ChangeNotifier {
  final IAuthService _authService;

  RegistrationViewModel(this._authService);

  RegistrationUiState _uiState = const RegistrationUiState();
  RegistrationUiState get uiState => _uiState;

  static const List<String> supportedCurrencies = [
    'MYR',
    'USD',
    'SGD',
    'EUR',
    'GBP',
    'JPY',
  ];

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );
  static final RegExp _uppercasePattern = RegExp(r'[A-Z]');
  static final RegExp _lowercasePattern = RegExp(r'[a-z]');
  static final RegExp _digitPattern = RegExp(r'\d');
  static final RegExp _specialPattern =
  RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\;\[\]~`]');

  void onFullNameChanged(String value) {
    _uiState = _uiState.copyWith(
      fullName: value,
      clearFullNameError: true,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void onEmailChanged(String value) {
    _uiState = _uiState.copyWith(
      email: value,
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
      final result = await _authService.register(
        fullName: _uiState.fullName,
        email: _uiState.email,
        password: _uiState.password,
        currency: _uiState.currency,
      );
      _uiState = _uiState.copyWith(
        isLoading: false,
        registrationSucceeded: true,
        successMessage: result.requiresEmailVerification
            ? 'Registered successfully. Please check your email to verify your account.'
            : 'Registered successfully.',
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

  /// Prevents a successful navigation/snackbar event from firing twice.
  void consumeRegistrationSuccess() {
    _uiState = _uiState.copyWith(registrationSucceeded: false);
    notifyListeners();
  }

  bool _validate() {
    final fullName = _uiState.fullName.trim();
    final email = _uiState.email.trim();
    final password = _uiState.password;

    final fullNameError =
    fullName.isEmpty ? 'Full name is required.' : null;
    String? emailError;
    if (email.isEmpty) {
      emailError = 'Email address is required.';
    } else if (!_emailPattern.hasMatch(email)) {
      emailError =
      'Invalid email address. Email must follow local@domain.com format.';
    }

    String? passwordError;
    if (password.isEmpty) {
      passwordError = 'Password is required.';
    } else if (!_isValidPassword(password)) {
      passwordError =
      'Password must have at least 8 characters, one uppercase letter, one lowercase letter, one digit, and one special character.';
    }

    final currencyError =
    _uiState.currency.isEmpty ? 'Please select a currency.' : null;
    final isValid = fullNameError == null &&
        emailError == null &&
        passwordError == null &&
        currencyError == null;

    _uiState = _uiState.copyWith(
      fullNameError: fullNameError,
      emailError: emailError,
      passwordError: passwordError,
      currencyError: currencyError,
      clearFullNameError: fullNameError == null,
      clearEmailError: emailError == null,
      clearPasswordError: passwordError == null,
      clearCurrencyError: currencyError == null,
      clearErrorMessage: true,
    );
    notifyListeners();
    return isValid;
  }

  bool _isValidPassword(String password) {
    return password.length >= 8 &&
        _uppercasePattern.hasMatch(password) &&
        _lowercasePattern.hasMatch(password) &&
        _digitPattern.hasMatch(password) &&
        _specialPattern.hasMatch(password);
  }
}
