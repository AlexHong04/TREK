import 'package:flutter/foundation.dart';

@immutable
class VerificationGateUiState {
  final String email;
  final bool isSending;
  final bool isLoggingOut;
  final bool linkSent;
  final String? errorMessage;

  const VerificationGateUiState({
    this.email = '',
    this.isSending = false,
    this.isLoggingOut = false,
    this.linkSent = false,
    this.errorMessage,
  });

  bool get isBusy => isSending || isLoggingOut;

  VerificationGateUiState copyWith({
    String? email,
    bool? isSending,
    bool? isLoggingOut,
    bool? linkSent,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return VerificationGateUiState(
      email: email ?? this.email,
      isSending: isSending ?? this.isSending,
      isLoggingOut: isLoggingOut ?? this.isLoggingOut,
      linkSent: linkSent ?? this.linkSent,
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
