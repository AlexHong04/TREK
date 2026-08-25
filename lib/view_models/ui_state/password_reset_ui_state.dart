import 'package:flutter/foundation.dart';

@immutable
class PasswordResetUiState {
  final String newPassword;
  final bool obscurePassword;
  final bool isLoading;
  final bool resetSucceeded;
  final String? passwordError;
  final String? errorMessage;

  const PasswordResetUiState({
    this.newPassword = '',
    this.obscurePassword = true,
    this.isLoading = false,
    this.resetSucceeded = false,
    this.passwordError,
    this.errorMessage,
  });

  PasswordResetUiState copyWith({
    String? newPassword,
    bool? obscurePassword,
    bool? isLoading,
    bool? resetSucceeded,
    String? passwordError,
    String? errorMessage,
    bool clearPasswordError = false,
    bool clearErrorMessage = false,
  }) {
    return PasswordResetUiState(
      newPassword: newPassword ?? this.newPassword,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isLoading: isLoading ?? this.isLoading,
      resetSucceeded: resetSucceeded ?? this.resetSucceeded,
      passwordError: clearPasswordError
          ? null
          : (passwordError ?? this.passwordError),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

