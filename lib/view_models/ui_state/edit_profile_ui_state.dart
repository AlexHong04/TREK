import 'package:flutter/foundation.dart';

@immutable
class EditProfileUiState {
  final String fullName;
  final String originalFullName;
  final String currency;
  final List<String> availableCurrencies;
  final bool isLoading;
  final bool isSaving;
  final bool isOffline;
  final bool saveSucceeded;
  final bool usedDefaultName;
  final String? fullNameError;
  final String? currencyError;
  final String? errorMessage;

  const EditProfileUiState({
    this.fullName = '',
    this.originalFullName = '',
    this.currency = 'MYR',
    this.availableCurrencies = const ['MYR', 'USD', 'SGD', 'EUR', 'GBP', 'JPY'],
    this.isLoading = false,
    this.isSaving = false,
    this.isOffline = false,
    this.saveSucceeded = false,
    this.usedDefaultName = false,
    this.fullNameError,
    this.currencyError,
    this.errorMessage,
  });

  EditProfileUiState copyWith({
    String? fullName,
    String? originalFullName,
    String? currency,
    List<String>? availableCurrencies,
    bool? isLoading,
    bool? isSaving,
    bool? isOffline,
    bool? saveSucceeded,
    bool? usedDefaultName,
    String? fullNameError,
    String? currencyError,
    String? errorMessage,
    bool clearFullNameError = false,
    bool clearCurrencyError = false,
    bool clearErrorMessage = false,
  }) {
    return EditProfileUiState(
      fullName: fullName ?? this.fullName,
      originalFullName: originalFullName ?? this.originalFullName,
      currency: currency ?? this.currency,
      availableCurrencies: availableCurrencies ?? this.availableCurrencies,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isOffline: isOffline ?? this.isOffline,
      saveSucceeded: saveSucceeded ?? this.saveSucceeded,
      usedDefaultName: usedDefaultName ?? this.usedDefaultName,
      fullNameError: clearFullNameError
          ? null
          : (fullNameError ?? this.fullNameError),
      currencyError:
      clearCurrencyError ? null : (currencyError ?? this.currencyError),
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
