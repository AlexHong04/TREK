import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_button/sign_in_button.dart';

import '../view_models/presentation_logic/registration_view_model.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/currency_picker_field.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  static Widget builder(BuildContext context) {
    return const RegistrationViewModelScope(child: RegistrationScreen());
  }

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  bool _isPasswordFocused = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        if (state.errorMessage != null) {
          final message = state.errorMessage!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeErrorMessage();
            showAuthToast(context, message, isError: true);
          });
        }
        if (state.registrationSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final message = state.successMessage;
            viewModel.consumeRegistrationSuccess();
            if (message != null) {
              showAuthToast(context, message);
            }
            // MyApp's auth listener opens Home after registration.
          });
        }

        void goToLogin() {
          if (state.isLoading) return;
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) goToLogin();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: AuthPage(
              title: 'Create new account',
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthFieldLabel('EMAIL ADDRESS'),
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) viewModel.onEmailFocusLost();
                      },
                      child: TextFormField(
                        enabled: !state.isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        onChanged: viewModel.onEmailChanged,
                        decoration: authFieldDecoration(
                          hint: 'Enter your email address',
                          errorText: state.emailError,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const AuthFieldLabel('PASSWORD'),
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (_isPasswordFocused != hasFocus) {
                          setState(() => _isPasswordFocused = hasFocus);
                        }
                        if (!hasFocus) viewModel.onPasswordFocusLost();
                      },
                      child: TextFormField(
                        enabled: !state.isLoading,
                        obscureText: state.obscurePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        onChanged: viewModel.onPasswordChanged,
                        decoration: authFieldDecoration(
                          hint: 'Enter your password',
                          errorText: state.passwordError,
                          suffixIcon: IconButton(
                            tooltip: state.obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: state.isLoading
                                ? null
                                : viewModel.togglePasswordVisibility,
                            icon: Icon(
                              state.obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                    PasswordPolicyChecklist(
                      password: state.password,
                      isVisible: _isPasswordFocused,
                    ),
                    const SizedBox(height: 20),
                    const AuthFieldLabel('PREFERRED CURRENCY'),
                    CurrencyPickerField(
                      value: state.currency,
                      currencies: state.availableCurrencies,
                      errorText: state.currencyError,
                      enabled: !state.isLoading && !state.isLoadingCurrencies,
                      onChanged: viewModel.onCurrencyChanged,
                    ),
                    const SizedBox(height: 28),
                    AuthPrimaryButton(
                      label: 'Register',
                      isLoading: state.isLoading,
                      onPressed: viewModel.onRegisterPressed,
                    ),
                    const SizedBox(height: 7),
                    AuthLinkLine(
                      text: 'Already have an account? ',
                      linkText: 'Click here to sign in.',
                      onTap: state.isLoading ? null : goToLogin,
                    ),
                    const SizedBox(height: 20),
                    const AuthOrDivider(),
                    const SizedBox(height: 20),
                    IgnorePointer(
                      ignoring: state.isLoading,
                      child: Opacity(
                        opacity: state.isLoading ? 0.55 : 1,
                        child: Center(
                          child: SignInButton(
                            Buttons.google,
                            text: 'Sign up with Google',
                            onPressed: viewModel.onGoogleSignInPressed,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
