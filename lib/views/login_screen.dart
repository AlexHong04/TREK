import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/services/i_auth_service.dart';
import '../theme/app_colors.dart';
import '../view_models/presentation_logic/login_view_model.dart';

class LoginScreen extends StatelessWidget {
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
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(context.read<IAuthService>()),
      child: LoginScreen(
        onLoginSuccess: onLoginSuccess,
        onRegister: onRegister,
        onForgotPassword: onForgotPassword,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        if (state.loginSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeLoginSuccess();
            if (onLoginSuccess != null) {
              onLoginSuccess!();
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/homeScreen',
                    (route) => false,
              );
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.gray50_02,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset('assets/logo.png', height: 84),
                        const SizedBox(height: 24),
                        const Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.blueGray900,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Log in to continue planning your trip.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.blueGray700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          enabled: !state.isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          onChanged: viewModel.onEmailChanged,
                          decoration: _inputDecoration(
                            label: 'Email address',
                            hint: 'name@example.com',
                            icon: Icons.email_outlined,
                            errorText: state.emailError,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          enabled: !state.isLoading,
                          obscureText: state.obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onChanged: viewModel.onPasswordChanged,
                          onFieldSubmitted: (_) => viewModel.onLoginPressed(),
                          decoration: _inputDecoration(
                            label: 'Password',
                            hint: 'Enter your password',
                            icon: Icons.lock_outline,
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
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: state.isLoading
                                ? null
                                : () {
                              if (onForgotPassword != null) {
                                onForgotPassword!();
                              } else {
                                Navigator.pushNamed(
                                  context,
                                  '/forgotPassword',
                                );
                              }
                            },
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        if (state.errorMessage != null) ...[
                          _MessageCard(
                            message: state.errorMessage!,
                            isError: true,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (state.verificationEmailSent) ...[
                          const _MessageCard(
                            message:
                            'Verification email sent. Please check your inbox.',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (state.magicLinkSent) ...[
                          const _MessageCard(
                            message:
                            'Secure login link sent. Please check your email.',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (state.canResendVerification)
                          OutlinedButton(
                            onPressed: state.isLoading
                                ? null
                                : viewModel.onResendVerificationPressed,
                            child: const Text('Resend verification email'),
                          ),
                        if (state.showMagicLinkOption)
                          OutlinedButton.icon(
                            onPressed: state.isLoading
                                ? null
                                : viewModel.onSendMagicLinkPressed,
                            icon: const Icon(Icons.mark_email_read_outlined),
                            label: const Text('Send secure login link'),
                          ),
                        const SizedBox(height: 4),
                        FilledButton(
                          onPressed:
                          state.isLoading ? null : viewModel.onLoginPressed,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: AppColors.tealA700,
                          ),
                          child: state.isLoading
                              ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.white,
                            ),
                          )
                              : const Text('Log In'),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: state.isLoading
                              ? null
                              : viewModel.onGoogleSignInPressed,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('New to TREK?'),
                            TextButton(
                              onPressed: state.isLoading
                                  ? null
                                  : () {
                                if (onRegister != null) {
                                  onRegister!();
                                } else {
                                  Navigator.pushNamed(
                                    context,
                                    '/register',
                                  );
                                }
                              },
                              child: const Text('Register an Account'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      errorText: errorText,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.tealA700, width: 1.5),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageCard({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? AppColors.budgetAlertBg : AppColors.goodPercentageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
          isError ? AppColors.budgetAlertStroke : AppColors.goodPercentageStroke,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color:
          isError ? AppColors.budgetAlertText : AppColors.goodPercentageText,
          fontSize: 13,
        ),
      ),
    );
  }
}
