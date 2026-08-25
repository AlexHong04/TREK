import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/services/i_auth_service.dart';
import '../theme/app_colors.dart';
import '../view_models/presentation_logic/password_reset_view_model.dart';
import '../widgets/custom_app_bar.dart';

class PasswordResetScreen extends StatelessWidget {
  final VoidCallback? onResetSuccess;

  const PasswordResetScreen({
    super.key,
    this.onResetSuccess,
  });

  static Widget builder(
      BuildContext context, {
        VoidCallback? onResetSuccess,
      }) {
    return ChangeNotifierProvider(
      create: (_) => PasswordResetViewModel(context.read<IAuthService>()),
      child: PasswordResetScreen(onResetSuccess: onResetSuccess),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PasswordResetViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        if (state.resetSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeResetSuccess();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password reset successfully. Please log in.'),
              ),
            );
            if (onResetSuccess != null) {
              onResetSuccess!();
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                    (route) => false,
              );
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.gray50_02,
          appBar: const CustomAppBar(title: 'Create New Password'),
          body: SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Choose a strong password',
                        style: TextStyle(
                          color: AppColors.blueGray900,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your new password must be at least 8 characters and include uppercase, lowercase, a digit, and a special character.',
                        style: TextStyle(
                          color: AppColors.blueGray700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        enabled: !state.isLoading,
                        obscureText: state.obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onChanged: viewModel.onNewPasswordChanged,
                        onFieldSubmitted: (_) => viewModel.onResetPressed(),
                        decoration: InputDecoration(
                          labelText: 'New password',
                          hintText: 'Enter your new password',
                          prefixIcon: const Icon(Icons.lock_outline),
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
                          filled: true,
                          fillColor: AppColors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: AppColors.gray200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.tealA700,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          state.errorMessage!,
                          style: const TextStyle(color: AppColors.errorRed),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed:
                        state.isLoading ? null : viewModel.onResetPressed,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.tealA700,
                        ),
                        child: state.isLoading
                            ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                            : const Text('Reset Password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
