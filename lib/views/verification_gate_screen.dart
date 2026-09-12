import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/verification_gate_view_model.dart';
import '../widgets/auth_form_widgets.dart';
import 'edit_account_screen.dart';

class VerificationGateScreen extends StatelessWidget {
  const VerificationGateScreen({super.key});

  static Widget builder(BuildContext context) {
    return const VerificationGateViewModelScope(
      child: VerificationGateScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VerificationGateViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        return PopScope(
          canPop: false,
          child: AuthPage(
            title: 'Verify Your Email',
            subtitle:
            'Your 7-day verification period has ended. Verify ${state.email} to continue using TREK.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.linkSent) ...[
                  AuthMessage(
                    message:
                    'Verification link sent. You may open it on any device.',
                    isError: false,
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.errorMessage != null) ...[
                  AuthMessage(message: state.errorMessage),
                  const SizedBox(height: 12),
                ],
                AuthPrimaryButton(
                  label: state.linkSent ? 'Resend Verification Link' : 'Send Verification Link',
                  isLoading: state.isSending,
                  onPressed: state.isBusy ? null : viewModel.sendVerificationLink,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: state.isBusy
                      ? null
                      : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: EditAccountScreen.builder,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: appTheme.teal_A700,
                    side: BorderSide(color: appTheme.teal_A700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text('Correct Email or Delete Account'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: state.isBusy
                      ? null
                      : () => Navigator.pushNamed(context, '/forgotPassword'),
                  child: const Text('Reset Password'),
                ),
                TextButton.icon(
                  onPressed: state.isBusy ? null : viewModel.logout,
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
