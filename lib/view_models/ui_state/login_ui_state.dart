import 'package:flutter/foundation.dart';

@immutable
class LoginUiState {
  final String email;
  final String password;
  final bool obscurePassword;
  final bool isLoading;
  final bool loginSucceeded;
  final bool showMagicLinkOption;
  final bool magicLinkSent;
  final String? emailError;
  final String? passwordError;
  final String? errorMessage;
  final String? infoMessage;

  const LoginUiState({
    this.email = '',
    this.password = '',
    this.obscurePassword = true,
    this.isLoading = false,
    this.loginSucceeded = false,
    this.showMagicLinkOption = false,
    this.magicLinkSent = false,
    this.emailError,
    this.passwordError,
    this.errorMessage,
    this.infoMessage,
  });

  LoginUiState copyWith({
    String? email,
    String? password,
    bool? obscurePassword,
    bool? isLoading,
    bool? loginSucceeded,
    bool? showMagicLinkOption,
    bool? magicLinkSent,
    String? emailError,
    String? passwordError,
    String? errorMessage,
    String? infoMessage,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearErrorMessage = false,
    bool clearInfoMessage = false,
  }) {
    return LoginUiState(
      email: email ?? this.email,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isLoading: isLoading ?? this.isLoading,
      loginSucceeded: loginSucceeded ?? this.loginSucceeded,
      showMagicLinkOption: showMagicLinkOption ?? this.showMagicLinkOption,
      magicLinkSent: magicLinkSent ?? this.magicLinkSent,
      emailError: clearEmailError ? null : (emailError ?? this.emailError),
      passwordError:
      clearPasswordError ? null : (passwordError ?? this.passwordError),
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      infoMessage:
      clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
    );
  }
}
