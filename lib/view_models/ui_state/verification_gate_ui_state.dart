import 'package:flutter/foundation.dart';

@immutable
class VerificationGateUiState {
  final String email;
  final bool isSending;
  final bool isLoggingOut;
  final bool linkSent;
  final int cooldownSeconds;
  final String? errorMessage;

  const VerificationGateUiState({
    this.email = '',
    this.isSending = false,
    this.isLoggingOut = false,
    this.linkSent = false,
    this.cooldownSeconds = 0,
    this.errorMessage,
  });

  bool get isBusy => isSending || isLoggingOut;

  VerificationGateUiState copyWith({
    String? email,
    bool? isSending,
    bool? isLoggingOut,
    bool? linkSent,
    int? cooldownSeconds,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return VerificationGateUiState(
      email: email ?? this.email,
      isSending: isSending ?? this.isSending,
      isLoggingOut: isLoggingOut ?? this.isLoggingOut,
      linkSent: linkSent ?? this.linkSent,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
