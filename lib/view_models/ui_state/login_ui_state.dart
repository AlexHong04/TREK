import 'package:flutter/foundation.dart';

/// Immutable UI data for the Login screen.
@immutable
class LoginUiState {
  final String email;
  final String password;
  final bool obscurePassword;
  final bool isLoading;
  final bool loginSucceeded;
  final bool canResendVerification;
  final bool verificationEmailSent;
  final bool showMagicLinkOption;
  final bool magicLinkSent;
  final String? emailError;
  final String? passwordError;
  final String? errorMessage;

  const LoginUiState({
    this.email = '',
    this.password = '',
    this.obscurePassword = true,
    this.isLoading = false,
    this.loginSucceeded = false,
    this.canResendVerification = false,
    this.verificationEmailSent = false,
    this.showMagicLinkOption = false,
    this.magicLinkSent = false,
    this.emailError,
    this.passwordError,
    this.errorMessage,
  });

  LoginUiState copyWith({
    String? email,
    String? password,
    bool? obscurePassword,
    bool? isLoading,
    bool? loginSucceeded,
    bool? canResendVerification,
    bool? verificationEmailSent,
    bool? showMagicLinkOption,
    bool? magicLinkSent,
    String? emailError,
    String? passwordError,
    String? errorMessage,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearErrorMessage = false,
  }) {
    return LoginUiState(
      email: email ?? this.email,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isLoading: isLoading ?? this.isLoading,
      loginSucceeded: loginSucceeded ?? this.loginSucceeded,
      canResendVerification:
      canResendVerification ?? this.canResendVerification,
      verificationEmailSent:
      verificationEmailSent ?? this.verificationEmailSent,
      showMagicLinkOption:
      showMagicLinkOption ?? this.showMagicLinkOption,
      magicLinkSent: magicLinkSent ?? this.magicLinkSent,
      emailError:
      clearEmailError ? null : (emailError ?? this.emailError),
      passwordError: clearPasswordError
          ? null
          : (passwordError ?? this.passwordError),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
