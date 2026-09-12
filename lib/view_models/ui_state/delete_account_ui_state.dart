import 'package:flutter/foundation.dart';

@immutable
class DeleteAccountUiState {
  final bool isDeleting;
  final bool isCancelling;
  final bool deletionSucceeded;
  final String? errorMessage;

  const DeleteAccountUiState({
    this.isDeleting = false,
    this.isCancelling = false,
    this.deletionSucceeded = false,
    this.errorMessage,
  });

  DeleteAccountUiState copyWith({
    bool? isDeleting,
    bool? isCancelling,
    bool? deletionSucceeded,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DeleteAccountUiState(
      isDeleting: isDeleting ?? this.isDeleting,
      isCancelling: isCancelling ?? this.isCancelling,
      deletionSucceeded: deletionSucceeded ?? this.deletionSucceeded,
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
