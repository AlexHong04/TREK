import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_button/sign_in_button.dart';

import '../view_models/presentation_logic/login_view_model.dart';
import '../widgets/auth_form_widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onRegister;
  final VoidCallback? onForgotPassword;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.onRegister,
    this.onForgotPassword,
  });

  static Widget builder(
      BuildContext context, {
        VoidCallback? onLoginSuccess,
        VoidCallback? onRegister,
        VoidCallback? onForgotPassword,
      }) {
    return LoginViewModelScope(
      child: LoginScreen(
        onLoginSuccess: onLoginSuccess,
        onRegister: onRegister,
        onForgotPassword: onForgotPassword,
      ),
    );
  }

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Duration _exitConfirmationWindow = Duration(seconds: 2);
  DateTime? _lastBackPressedAt;

  void _handleSystemBack() {
    final now = DateTime.now();
    final lastBackPressedAt = _lastBackPressedAt;
    if (lastBackPressedAt != null &&
        now.difference(lastBackPressedAt) <= _exitConfirmationWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    FocusManager.instance.primaryFocus?.unfocus();
    showAuthToast(context, 'Press back again to exit TREK.');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginViewModel>(
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
        if (state.loginSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeLoginSuccess();
            if (widget.onLoginSuccess != null) {
              widget.onLoginSuccess!();
            }
            // Normal app navigation is owned by MyApp's auth listener. This
            // prevents Login and the root navigator from pushing Home twice.
          });
        }

        void openRegistration() {
          if (widget.onRegister != null) {
            widget.onRegister!();
          } else {
            Navigator.pushNamed(context, '/register');
          }
        }

        void openForgotPassword() {
          if (widget.onForgotPassword != null) {
            widget.onForgotPassword!();
          } else {
            Navigator.pushNamed(context, '/forgotPassword');
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleSystemBack();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: AuthPage(
              title: 'Sign in to your account',
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
                        if (!hasFocus) viewModel.onPasswordFocusLost();
                      },
                      child: TextFormField(
                        enabled: !state.isLoading,
                        obscureText: state.obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onChanged: viewModel.onPasswordChanged,
                        onFieldSubmitted: (_) => viewModel.onLoginPressed(),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: state.isLoading ? null : openForgotPassword,
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    if (state.canResendVerification)
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : viewModel.onResendVerificationPressed,
                        child: Text(
                          state.verificationEmailSent
                              ? 'Verification email sent'
                              : 'Resend verification email',
                        ),
                      ),
                    if (state.showMagicLinkOption)
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : viewModel.onSendMagicLinkPressed,
                        child: Text(
                          state.magicLinkSent
                              ? 'Secure login link sent'
                              : 'Continue with email (magic link)',
                        ),
                      ),
                    const SizedBox(height: 22),
                    AuthPrimaryButton(
                      label: 'Log in',
                      isLoading: state.isLoading,
                      onPressed: viewModel.onLoginPressed,
                    ),
                    const SizedBox(height: 7),
                    AuthLinkLine(
                      text: "Don't have an account? ",
                      linkText: 'Register with an email.',
                      onTap: state.isLoading ? null : openRegistration,
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
                            text: 'Continue with Google',
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
