import 'package:flutter/foundation.dart';

@immutable
class RegistrationUiState {
  final String email;
  final String password;
  final String currency;
  final bool obscurePassword;
  final bool isLoading;
  final bool isLoadingCurrencies;
  final List<String> availableCurrencies;
  final bool registrationSucceeded;
  final String? successMessage;
  final String? emailError;
  final String? passwordError;
  final String? currencyError;
  final String? errorMessage;

  const RegistrationUiState({
    this.email = '',
    this.password = '',
    this.currency = 'MYR',
    this.obscurePassword = true,
    this.isLoading = false,
    this.isLoadingCurrencies = false,
    this.availableCurrencies = const [
      'MYR',
      'USD',
      'SGD',
      'EUR',
      'GBP',
      'JPY',
    ],
    this.registrationSucceeded = false,
    this.successMessage,
    this.emailError,
    this.passwordError,
    this.currencyError,
    this.errorMessage,
  });

  RegistrationUiState copyWith({
    String? email,
    String? password,
    String? currency,
    bool? obscurePassword,
    bool? isLoading,
    bool? isLoadingCurrencies,
    List<String>? availableCurrencies,
    bool? registrationSucceeded,
    String? successMessage,
    String? emailError,
    String? passwordError,
    String? currencyError,
    String? errorMessage,
    bool clearSuccessMessage = false,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearCurrencyError = false,
    bool clearErrorMessage = false,
  }) {
    return RegistrationUiState(
      email: email ?? this.email,
      password: password ?? this.password,
      currency: currency ?? this.currency,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isLoading: isLoading ?? this.isLoading,
      isLoadingCurrencies:
      isLoadingCurrencies ?? this.isLoadingCurrencies,
      availableCurrencies:
      availableCurrencies ?? this.availableCurrencies,
      registrationSucceeded:
      registrationSucceeded ?? this.registrationSucceeded,
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
      emailError: clearEmailError ? null : (emailError ?? this.emailError),
      passwordError:
      clearPasswordError ? null : (passwordError ?? this.passwordError),
      currencyError:
      clearCurrencyError ? null : (currencyError ?? this.currencyError),
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
