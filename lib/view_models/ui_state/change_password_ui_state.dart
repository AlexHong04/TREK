import 'package:flutter/foundation.dart';

enum PasswordPageMode { loading, setPassword, changePassword }

@immutable
class ChangePasswordUiState {
  final PasswordPageMode mode;
  final String currentPassword;
  final String newPassword;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool isOffline;
  final bool logoutRequested;
  final bool isLoggingOut;
  final bool isSaving;
  final bool passwordSaved;
  final bool requiresRecentGoogleAuthentication;
  final String? currentPasswordError;
  final String? newPasswordError;
  final String? errorMessage;
  final String? successMessage;

  const ChangePasswordUiState({
    this.mode = PasswordPageMode.loading,
    this.currentPassword = '',
    this.newPassword = '',
    this.obscureCurrentPassword = true,
    this.obscureNewPassword = true,
    this.isOffline = false,
    this.logoutRequested = false,
    this.isLoggingOut = false,
    this.isSaving = false,
    this.passwordSaved = false,
    this.requiresRecentGoogleAuthentication = false,
    this.currentPasswordError,
    this.newPasswordError,
    this.errorMessage,
    this.successMessage,
  });

  bool get isSetMode => mode == PasswordPageMode.setPassword;

  String get title => isSetMode ? 'Set Password' : 'Change Password';

  ChangePasswordUiState copyWith({
    PasswordPageMode? mode,
    String? currentPassword,
    String? newPassword,
    bool? obscureCurrentPassword,
    bool? obscureNewPassword,
    bool? isOffline,
    bool? logoutRequested,
    bool? isLoggingOut,
    bool? isSaving,
    bool? passwordSaved,
    bool? requiresRecentGoogleAuthentication,
    String? currentPasswordError,
    String? newPasswordError,
    String? errorMessage,
    String? successMessage,
    bool clearCurrentPasswordError = false,
    bool clearNewPasswordError = false,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
  }) {
    return ChangePasswordUiState(
      mode: mode ?? this.mode,
      currentPassword: currentPassword ?? this.currentPassword,
      newPassword: newPassword ?? this.newPassword,
      obscureCurrentPassword:
      obscureCurrentPassword ?? this.obscureCurrentPassword,
      obscureNewPassword: obscureNewPassword ?? this.obscureNewPassword,
      isOffline: isOffline ?? this.isOffline,
      logoutRequested: logoutRequested ?? this.logoutRequested,
      isLoggingOut: isLoggingOut ?? this.isLoggingOut,
      isSaving: isSaving ?? this.isSaving,
      passwordSaved: passwordSaved ?? this.passwordSaved,
      requiresRecentGoogleAuthentication: requiresRecentGoogleAuthentication ??
          this.requiresRecentGoogleAuthentication,
      currentPasswordError: clearCurrentPasswordError
          ? null
          : (currentPasswordError ?? this.currentPasswordError),
      newPasswordError: clearNewPasswordError
          ? null
          : (newPasswordError ?? this.newPasswordError),
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successMessage:
      clearSuccessMessage ? null : (successMessage ?? this.successMessage),
    );
  }
}
