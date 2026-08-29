import 'package:flutter/foundation.dart';

@immutable
class ProfileUiState {
  final String fullName;
  final String email;
  final String currency;
  final String? profilePictureUrl;
  final bool isEmailVerified;
  final bool isLoading;
  final bool isUploadingPicture;
  final bool isSendingVerification;
  final bool isLoggingOut;
  final bool logoutSucceeded;
  final String? successMessage;
  final String? errorMessage;

  const ProfileUiState({
    this.fullName = '',
    this.email = '',
    this.currency = 'MYR',
    this.profilePictureUrl,
    this.isEmailVerified = false,
    this.isLoading = false,
    this.isUploadingPicture = false,
    this.isSendingVerification = false,
    this.isLoggingOut = false,
    this.logoutSucceeded = false,
    this.successMessage,
    this.errorMessage,
  });

  bool get isBusy =>
      isLoading ||
          isUploadingPicture ||
          isSendingVerification ||
          isLoggingOut;

  ProfileUiState copyWith({
    String? fullName,
    String? email,
    String? currency,
    String? profilePictureUrl,
    bool? isEmailVerified,
    bool? isLoading,
    bool? isUploadingPicture,
    bool? isSendingVerification,
    bool? isLoggingOut,
    bool? logoutSucceeded,
    String? successMessage,
    String? errorMessage,
    bool clearProfilePicture = false,
    bool clearSuccessMessage = false,
    bool clearErrorMessage = false,
  }) {
    return ProfileUiState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      profilePictureUrl: clearProfilePicture
          ? null
          : (profilePictureUrl ?? this.profilePictureUrl),
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isLoading: isLoading ?? this.isLoading,
      isUploadingPicture: isUploadingPicture ?? this.isUploadingPicture,
      isSendingVerification:
      isSendingVerification ?? this.isSendingVerification,
      isLoggingOut: isLoggingOut ?? this.isLoggingOut,
      logoutSucceeded: logoutSucceeded ?? this.logoutSucceeded,
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
