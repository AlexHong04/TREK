import 'package:flutter/foundation.dart';

@immutable
class ChangePasswordUiState {
  final String currentPassword;
  final String newPassword;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool isSaving;
  final bool passwordChanged;
  final String? currentPasswordError;
  final String? newPasswordError;
  final String? errorMessage;

  const ChangePasswordUiState({
    this.currentPassword = '',
    this.newPassword = '',
    this.obscureCurrentPassword = true,
    this.obscureNewPassword = true,
    this.isSaving = false,
    this.passwordChanged = false,
    this.currentPasswordError,
    this.newPasswordError,
    this.errorMessage,
  });

  ChangePasswordUiState copyWith({
    String? currentPassword,
    String? newPassword,
    bool? obscureCurrentPassword,
    bool? obscureNewPassword,
    bool? isSaving,
    bool? passwordChanged,
    String? currentPasswordError,
    String? newPasswordError,
    String? errorMessage,
    bool clearCurrentPasswordError = false,
    bool clearNewPasswordError = false,
    bool clearErrorMessage = false,
  }) {
    return ChangePasswordUiState(
      currentPassword: currentPassword ?? this.currentPassword,
      newPassword: newPassword ?? this.newPassword,
      obscureCurrentPassword:
      obscureCurrentPassword ?? this.obscureCurrentPassword,
      obscureNewPassword: obscureNewPassword ?? this.obscureNewPassword,
      isSaving: isSaving ?? this.isSaving,
      passwordChanged: passwordChanged ?? this.passwordChanged,
      currentPasswordError: clearCurrentPasswordError
          ? null
          : (currentPasswordError ?? this.currentPasswordError),
      newPasswordError: clearNewPasswordError
          ? null
          : (newPasswordError ?? this.newPasswordError),
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
