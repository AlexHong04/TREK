import 'package:flutter/foundation.dart';

/// Immutable UI data for the Registration screen.
@immutable
class RegistrationUiState {
  final String fullName;
  final String email;
  final String password;
  final String currency;
  final bool obscurePassword;
  final bool isLoading;
  final bool registrationSucceeded;
  final String? successMessage;
  final String? fullNameError;
  final String? emailError;
  final String? passwordError;
  final String? currencyError;
  final String? errorMessage;

  const RegistrationUiState({
    this.fullName = '',
    this.email = '',
    this.password = '',
    this.currency = '',
    this.obscurePassword = true,
    this.isLoading = false,
    this.registrationSucceeded = false,
    this.successMessage,
    this.fullNameError,
    this.emailError,
    this.passwordError,
    this.currencyError,
    this.errorMessage,
  });

  RegistrationUiState copyWith({
    String? fullName,
    String? email,
    String? password,
    String? currency,
    bool? obscurePassword,
    bool? isLoading,
    bool? registrationSucceeded,
    String? successMessage,
    String? fullNameError,
    String? emailError,
    String? passwordError,
    String? currencyError,
    String? errorMessage,
    bool clearSuccessMessage = false,
    bool clearFullNameError = false,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearCurrencyError = false,
    bool clearErrorMessage = false,
  }) {
    return RegistrationUiState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      currency: currency ?? this.currency,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isLoading: isLoading ?? this.isLoading,
      registrationSucceeded:
      registrationSucceeded ?? this.registrationSucceeded,
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
      fullNameError: clearFullNameError
          ? null
          : (fullNameError ?? this.fullNameError),
      emailError:
      clearEmailError ? null : (emailError ?? this.emailError),
      passwordError: clearPasswordError
          ? null
          : (passwordError ?? this.passwordError),
      currencyError: clearCurrencyError
          ? null
          : (currencyError ?? this.currencyError),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

