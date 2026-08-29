import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/presentation_logic/password_reset_view_model.dart';
import '../widgets/auth_form_widgets.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  static Widget builder(BuildContext context) {
    return const PasswordResetViewModelScope(child: PasswordResetScreen());
  }

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  bool _isNewPasswordFocused = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<PasswordResetViewModel>(
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
        if (state.resetSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeResetSuccess();
            showAuthToast(context, 'Password reset successfully.');
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
                  (_) => false,
            );
          });
        }

        return PopScope(
          canPop: false,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: AuthPage(
              title: 'New Password',
              subtitle: 'Enter a new password for your TREK account.',
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthFieldLabel('NEW PASSWORD'),
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (_isNewPasswordFocused != hasFocus) {
                          setState(() => _isNewPasswordFocused = hasFocus);
                        }
                        if (!hasFocus) viewModel.onNewPasswordFocusLost();
                      },
                      child: TextFormField(
                        enabled: !state.isLoading,
                        obscureText: state.obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onChanged: viewModel.onNewPasswordChanged,
                        onFieldSubmitted: (_) => viewModel.onResetPressed(),
                        decoration: authFieldDecoration(
                          hint: 'Enter your new password',
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
                      password: state.newPassword,
                      isVisible: _isNewPasswordFocused,
                    ),
                    const SizedBox(height: 32),
                    AuthPrimaryButton(
                      label: 'Reset Password',
                      isLoading: state.isLoading,
                      onPressed: viewModel.onResetPressed,
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
