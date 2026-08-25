import 'package:flutter/foundation.dart';

@immutable
class EmailSubmissionUiState {
  final String email;
  final bool isLoading;
  final bool linkSent;
  final String? emailError;
  final String? errorMessage;

  const EmailSubmissionUiState({
    this.email = '',
    this.isLoading = false,
    this.linkSent = false,
    this.emailError,
    this.errorMessage,
  });

  EmailSubmissionUiState copyWith({
    String? email,
    bool? isLoading,
    bool? linkSent,
    String? emailError,
    String? errorMessage,
    bool clearEmailError = false,
    bool clearErrorMessage = false,
  }) {
    return EmailSubmissionUiState(
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      linkSent: linkSent ?? this.linkSent,
      emailError:
      clearEmailError ? null : (emailError ?? this.emailError),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

