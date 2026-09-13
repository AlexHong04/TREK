import 'package:flutter/foundation.dart';

@immutable
class ProfileUiState {
  final String fullName;
  final String email;
  final String currency;
  final String? profilePictureUrl;
  final String? cachedProfilePicturePath;
  final bool isEmailVerified;
  final int verificationDaysRemaining;
  final bool hasPasswordSignIn;
  final bool isOffline;
  final bool isLoading;
  final bool isUploadingPicture;
  final bool isSendingVerification;
  final int verificationCooldownSeconds;
  final bool isLoggingOut;
  final bool logoutSucceeded;
  final String? successMessage;
  final String? errorMessage;

  const ProfileUiState({
    this.fullName = '',
    this.email = '',
    this.currency = 'MYR',
    this.profilePictureUrl,
    this.cachedProfilePicturePath,
    this.isEmailVerified = false,
    this.verificationDaysRemaining = 0,
    this.hasPasswordSignIn = false,
    this.isOffline = false,
    this.isLoading = false,
    this.isUploadingPicture = false,
    this.isSendingVerification = false,
    this.verificationCooldownSeconds = 0,
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

  String get passwordActionLabel =>
      hasPasswordSignIn ? 'Change Password' : 'Set Password';

  ProfileUiState copyWith({
    String? fullName,
    String? email,
    String? currency,
    String? profilePictureUrl,
    String? cachedProfilePicturePath,
    bool? isEmailVerified,
    int? verificationDaysRemaining,
    bool? hasPasswordSignIn,
    bool? isOffline,
    bool? isLoading,
    bool? isUploadingPicture,
    bool? isSendingVerification,
    int? verificationCooldownSeconds,
    bool? isLoggingOut,
    bool? logoutSucceeded,
    String? successMessage,
    String? errorMessage,
    bool clearProfilePicture = false,
    bool clearCachedProfilePicture = false,
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
      cachedProfilePicturePath: clearCachedProfilePicture
          ? null
          : (cachedProfilePicturePath ?? this.cachedProfilePicturePath),
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      verificationDaysRemaining:
      verificationDaysRemaining ?? this.verificationDaysRemaining,
      hasPasswordSignIn:
      hasPasswordSignIn ?? this.hasPasswordSignIn,
      isOffline: isOffline ?? this.isOffline,
      isLoading: isLoading ?? this.isLoading,
      isUploadingPicture: isUploadingPicture ?? this.isUploadingPicture,
      isSendingVerification:
      isSendingVerification ?? this.isSendingVerification,
      verificationCooldownSeconds:
      verificationCooldownSeconds ?? this.verificationCooldownSeconds,
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
