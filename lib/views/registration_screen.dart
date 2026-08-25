import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/services/i_auth_service.dart';
import '../theme/app_colors.dart';
import '../view_models/presentation_logic/registration_view_model.dart';
import '../widgets/custom_app_bar.dart';

class RegistrationScreen extends StatelessWidget {
  final VoidCallback? onRegistrationSuccess;

  const RegistrationScreen({
    super.key,
    this.onRegistrationSuccess,
  });

  static Widget builder(
      BuildContext context, {
        VoidCallback? onRegistrationSuccess,
      }) {
    return ChangeNotifierProvider(
      create: (_) => RegistrationViewModel(context.read<IAuthService>()),
      child: RegistrationScreen(
        onRegistrationSuccess: onRegistrationSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        if (state.registrationSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final message = state.successMessage ?? 'Registered successfully.';
            viewModel.consumeRegistrationSuccess();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
            if (onRegistrationSuccess != null) {
              onRegistrationSuccess!();
            } else {
              Navigator.pop(context);
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.gray50_02,
          appBar: const CustomAppBar(title: 'Register Account'),
          body: SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create your TREK account',
                          style: TextStyle(
                            color: AppColors.blueGray900,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your details to start planning personalised trips.',
                          style: TextStyle(
                            color: AppColors.blueGray700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          enabled: !state.isLoading,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          onChanged: viewModel.onFullNameChanged,
                          decoration: _decoration(
                            label: 'Full name',
                            hint: 'Enter your full name',
                            icon: Icons.person_outline,
                            errorText: state.fullNameError,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          enabled: !state.isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          onChanged: viewModel.onEmailChanged,
                          decoration: _decoration(
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
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: viewModel.onPasswordChanged,
                          decoration: _decoration(
                            label: 'Password',
                            hint: 'Create a strong password',
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
                        const SizedBox(height: 8),
                        const Text(
                          'At least 8 characters with uppercase, lowercase, a digit, and a special character.',
                          style: TextStyle(
                            color: AppColors.blueGray700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue:
                          state.currency.isEmpty ? null : state.currency,
                          decoration: _decoration(
                            label: 'Preferred currency',
                            hint: 'Select a currency',
                            icon: Icons.payments_outlined,
                            errorText: state.currencyError,
                          ),
                          items: RegistrationViewModel.supportedCurrencies
                              .map(
                                (currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ),
                          )
                              .toList(growable: false),
                          onChanged:
                          state.isLoading ? null : viewModel.onCurrencyChanged,
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.errorRed,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: state.isLoading
                              ? null
                              : viewModel.onRegisterPressed,
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
                              : const Text('Register'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'By registering, you agree to keep your account credentials secure.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.blueGray700,
                            fontSize: 12,
                          ),
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

  static InputDecoration _decoration({
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
