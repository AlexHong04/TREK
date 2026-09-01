import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/presentation_logic/email_submission_view_model.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/custom_text_field.dart';

class EmailSubmissionScreen extends StatelessWidget {
  const EmailSubmissionScreen({super.key});

  static Widget builder(BuildContext context) {
    return const EmailSubmissionViewModelScope(child: EmailSubmissionScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmailSubmissionViewModel>(
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

        void goToLogin() {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !state.isLoading) goToLogin();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: state.linkSent
                  ? AuthPage(
                key: const ValueKey('link-sent'),
                title: 'Password Reset Link Sent',
                subtitle:
                'If an account exists for ${state.email.trim()}, a reset link has been sent. Open it on this device to return to TREK.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 44),
                    AuthPrimaryButton(
                      label: 'Resend',
                      isLoading: state.isLoading,
                      onPressed: viewModel.onResendPressed,
                    ),
                    const SizedBox(height: 7),
                    AuthLinkLine(
                      text: 'Enter another email? ',
                      linkText: 'Click here.',
                      onTap: state.isLoading
                          ? null
                          : viewModel.onUseAnotherEmailPressed,
                    ),
                  ],
                ),
              )
                  : AuthPage(
                key: const ValueKey('email-entry'),
                title: 'Forgot Password',
                subtitle:
                'Enter your account email and we will send a reset link.',
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Focus(
                        onFocusChange: (hasFocus) {
                          if (!hasFocus) viewModel.onEmailFocusLost();
                        },
                        child: CustomTextField(
                          sectionTitle: 'EMAIL ADDRESS',
                          hintText: 'Enter your email address',
                          prefixIcon: Icons.email_outlined,
                          margin: EdgeInsets.zero,
                          enabled: !state.isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: viewModel.onEmailChanged,
                          onFieldSubmitted: (_) => viewModel.onSendPressed(),
                          errorText: state.emailError,
                        ),
                      ),
                      const SizedBox(height: 42),
                      AuthPrimaryButton(
                        label: 'Send',
                        isLoading: state.isLoading,
                        onPressed: viewModel.onSendPressed,
                      ),
                      const SizedBox(height: 7),
                      AuthLinkLine(
                        text: 'Back to sign in? ',
                        linkText: 'Click here.',
                        onTap: state.isLoading ? null : goToLogin,
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
