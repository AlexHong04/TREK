import 'package:flutter/foundation.dart';

@immutable
class EditAccountUiState {
  final String accountEmail;
  final String newEmail;
  final String currentPassword;
  final String? googleEmail;
  final bool isEmailVerified;
  final bool hasPasswordSignIn;
  final bool hasEmailIdentity;
  final bool hasGoogleIdentity;
  final bool canUnlinkGoogle;
  final bool isOffline;
  final bool isLoading;
  final bool isSavingEmail;
  final bool isLinkingGoogle;
  final bool isUnlinkingGoogle;
  final bool isRequestingDeletion;
  final bool emailChangeRequested;
  final bool googleUnlinked;
  final bool deletionEmailSent;
  final bool deletionReady;
  final bool obscureCurrentPassword;
  final String? newEmailError;
  final String? currentPasswordError;
  final String? errorMessage;
  final String? successMessage;

  const EditAccountUiState({
    this.accountEmail = '',
    this.newEmail = '',
    this.currentPassword = '',
    this.googleEmail,
    this.isEmailVerified = false,
    this.hasPasswordSignIn = false,
    this.hasEmailIdentity = false,
    this.hasGoogleIdentity = false,
    this.canUnlinkGoogle = false,
    this.isOffline = false,
    this.isLoading = true,
    this.isSavingEmail = false,
    this.isLinkingGoogle = false,
    this.isUnlinkingGoogle = false,
    this.isRequestingDeletion = false,
    this.emailChangeRequested = false,
    this.googleUnlinked = false,
    this.deletionEmailSent = false,
    this.deletionReady = false,
    this.obscureCurrentPassword = true,
    this.newEmailError,
    this.currentPasswordError,
    this.errorMessage,
    this.successMessage,
  });

  bool get isBusy =>
      isLoading ||
          isSavingEmail ||
          isLinkingGoogle ||
          isUnlinkingGoogle ||
          isRequestingDeletion;

  bool get needsPasswordForSensitiveAction => hasPasswordSignIn;

  bool get isGoogleManagedAccount => hasGoogleIdentity && !hasEmailIdentity;

  EditAccountUiState copyWith({
    String? accountEmail,
    String? newEmail,
    String? currentPassword,
    String? googleEmail,
    bool? isEmailVerified,
    bool? hasPasswordSignIn,
    bool? hasEmailIdentity,
    bool? hasGoogleIdentity,
    bool? canUnlinkGoogle,
    bool? isOffline,
    bool? isLoading,
    bool? isSavingEmail,
    bool? isLinkingGoogle,
    bool? isUnlinkingGoogle,
    bool? isRequestingDeletion,
    bool? emailChangeRequested,
    bool? googleUnlinked,
    bool? deletionEmailSent,
    bool? deletionReady,
    bool? obscureCurrentPassword,
    String? newEmailError,
    String? currentPasswordError,
    String? errorMessage,
    String? successMessage,
    bool clearGoogleEmail = false,
    bool clearNewEmailError = false,
    bool clearCurrentPasswordError = false,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
  }) {
    return EditAccountUiState(
      accountEmail: accountEmail ?? this.accountEmail,
      newEmail: newEmail ?? this.newEmail,
      currentPassword: currentPassword ?? this.currentPassword,
      googleEmail:
      clearGoogleEmail ? null : (googleEmail ?? this.googleEmail),
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      hasPasswordSignIn:
      hasPasswordSignIn ?? this.hasPasswordSignIn,
      hasEmailIdentity: hasEmailIdentity ?? this.hasEmailIdentity,
      hasGoogleIdentity: hasGoogleIdentity ?? this.hasGoogleIdentity,
      canUnlinkGoogle: canUnlinkGoogle ?? this.canUnlinkGoogle,
      isOffline: isOffline ?? this.isOffline,
      isLoading: isLoading ?? this.isLoading,
      isSavingEmail: isSavingEmail ?? this.isSavingEmail,
      isLinkingGoogle: isLinkingGoogle ?? this.isLinkingGoogle,
      isUnlinkingGoogle: isUnlinkingGoogle ?? this.isUnlinkingGoogle,
      isRequestingDeletion:
      isRequestingDeletion ?? this.isRequestingDeletion,
      emailChangeRequested:
      emailChangeRequested ?? this.emailChangeRequested,
      googleUnlinked: googleUnlinked ?? this.googleUnlinked,
      deletionEmailSent: deletionEmailSent ?? this.deletionEmailSent,
      deletionReady: deletionReady ?? this.deletionReady,
      obscureCurrentPassword:
      obscureCurrentPassword ?? this.obscureCurrentPassword,
      newEmailError: clearNewEmailError
          ? null
          : (newEmailError ?? this.newEmailError),
      currentPasswordError: clearCurrentPasswordError
          ? null
          : (currentPasswordError ?? this.currentPasswordError),
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}
