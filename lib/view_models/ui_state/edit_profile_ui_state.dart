import 'package:flutter/foundation.dart';

@immutable
class EditProfileUiState {
  final String fullName;
  final String originalFullName;
  final String email;
  final String currency;
  final List<String> availableCurrencies;
  final bool isLoading;
  final bool isSaving;
  final bool saveSucceeded;
  final String? currencyError;
  final String? errorMessage;

  const EditProfileUiState({
    this.fullName = '',
    this.originalFullName = '',
    this.email = '',
    this.currency = 'MYR',
    this.availableCurrencies = const ['MYR', 'USD', 'SGD', 'EUR', 'GBP', 'JPY'],
    this.isLoading = false,
    this.isSaving = false,
    this.saveSucceeded = false,
    this.currencyError,
    this.errorMessage,
  });

  EditProfileUiState copyWith({
    String? fullName,
    String? originalFullName,
    String? email,
    String? currency,
    List<String>? availableCurrencies,
    bool? isLoading,
    bool? isSaving,
    bool? saveSucceeded,
    String? currencyError,
    String? errorMessage,
    bool clearCurrencyError = false,
    bool clearErrorMessage = false,
  }) {
    return EditProfileUiState(
      fullName: fullName ?? this.fullName,
      originalFullName: originalFullName ?? this.originalFullName,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      availableCurrencies: availableCurrencies ?? this.availableCurrencies,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      saveSucceeded: saveSucceeded ?? this.saveSucceeded,
      currencyError:
      clearCurrencyError ? null : (currencyError ?? this.currencyError),
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
