import 'package:flutter/foundation.dart';

import '../../models/entities/personal_constraint.dart';
import '../../models/entities/user.dart';

@immutable
class EditProfileUiState {
  final User? user;
  final String fullName;
  final String currency;
  final List<PersonalConstraint> availableConstraints;
  final Set<String> selectedConstraintIds;
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final bool isLoading;
  final bool isSavingProfile;
  final bool isUploadingPicture;
  final bool isSavingConstraints;
  final bool isChangingPassword;
  final bool isLoggingOut;
  final bool passwordChanged;
  final bool logoutSucceeded;
  final String? fullNameError;
  final String? currencyError;
  final String? currentPasswordError;
  final String? newPasswordError;
  final String? confirmPasswordError;
  final String? successMessage;
  final String? errorMessage;

  const EditProfileUiState({
    this.user,
    this.fullName = '',
    this.currency = '',
    this.availableConstraints = const [],
    this.selectedConstraintIds = const {},
    this.currentPassword = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.obscureCurrentPassword = true,
    this.obscureNewPassword = true,
    this.obscureConfirmPassword = true,
    this.isLoading = false,
    this.isSavingProfile = false,
    this.isUploadingPicture = false,
    this.isSavingConstraints = false,
    this.isChangingPassword = false,
    this.isLoggingOut = false,
    this.passwordChanged = false,
    this.logoutSucceeded = false,
    this.fullNameError,
    this.currencyError,
    this.currentPasswordError,
    this.newPasswordError,
    this.confirmPasswordError,
    this.successMessage,
    this.errorMessage,
  });

  bool get isBusy =>
      isLoading ||
          isSavingProfile ||
          isUploadingPicture ||
          isSavingConstraints ||
          isChangingPassword ||
          isLoggingOut;

  EditProfileUiState copyWith({
    User? user,
    String? fullName,
    String? currency,
    List<PersonalConstraint>? availableConstraints,
    Set<String>? selectedConstraintIds,
    String? currentPassword,
    String? newPassword,
    String? confirmPassword,
    bool? obscureCurrentPassword,
    bool? obscureNewPassword,
    bool? obscureConfirmPassword,
    bool? isLoading,
    bool? isSavingProfile,
    bool? isUploadingPicture,
    bool? isSavingConstraints,
    bool? isChangingPassword,
    bool? isLoggingOut,
    bool? passwordChanged,
    bool? logoutSucceeded,
    String? fullNameError,
    String? currencyError,
    String? currentPasswordError,
    String? newPasswordError,
    String? confirmPasswordError,
    String? successMessage,
    String? errorMessage,
    bool clearFullNameError = false,
    bool clearCurrencyError = false,
    bool clearCurrentPasswordError = false,
    bool clearNewPasswordError = false,
    bool clearConfirmPasswordError = false,
    bool clearSuccessMessage = false,
    bool clearErrorMessage = false,
  }) {
    return EditProfileUiState(
      user: user ?? this.user,
      fullName: fullName ?? this.fullName,
      currency: currency ?? this.currency,
      availableConstraints:
      availableConstraints ?? this.availableConstraints,
      selectedConstraintIds:
      selectedConstraintIds ?? this.selectedConstraintIds,
      currentPassword: currentPassword ?? this.currentPassword,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      obscureCurrentPassword:
      obscureCurrentPassword ?? this.obscureCurrentPassword,
      obscureNewPassword: obscureNewPassword ?? this.obscureNewPassword,
      obscureConfirmPassword:
      obscureConfirmPassword ?? this.obscureConfirmPassword,
      isLoading: isLoading ?? this.isLoading,
      isSavingProfile: isSavingProfile ?? this.isSavingProfile,
      isUploadingPicture: isUploadingPicture ?? this.isUploadingPicture,
      isSavingConstraints: isSavingConstraints ?? this.isSavingConstraints,
      isChangingPassword: isChangingPassword ?? this.isChangingPassword,
      isLoggingOut: isLoggingOut ?? this.isLoggingOut,
      passwordChanged: passwordChanged ?? this.passwordChanged,
      logoutSucceeded: logoutSucceeded ?? this.logoutSucceeded,
      fullNameError:
      clearFullNameError ? null : (fullNameError ?? this.fullNameError),
      currencyError:
      clearCurrencyError ? null : (currencyError ?? this.currencyError),
      currentPasswordError: clearCurrentPasswordError
          ? null
          : (currentPasswordError ?? this.currentPasswordError),
      newPasswordError: clearNewPasswordError
          ? null
          : (newPasswordError ?? this.newPasswordError),
      confirmPasswordError: clearConfirmPasswordError
          ? null
          : (confirmPasswordError ?? this.confirmPasswordError),
      successMessage:
      clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
