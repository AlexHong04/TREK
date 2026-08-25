import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/services/i_auth_service.dart';
import '../theme/app_colors.dart';
import '../view_models/presentation_logic/email_submission_view_model.dart';
import '../widgets/custom_app_bar.dart';

class EmailSubmissionScreen extends StatelessWidget {
  const EmailSubmissionScreen({super.key});

  static Widget builder(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmailSubmissionViewModel(context.read<IAuthService>()),
      child: const EmailSubmissionScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmailSubmissionViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        return Scaffold(
          backgroundColor: AppColors.gray50_02,
          appBar: const CustomAppBar(title: 'Forgot Password'),
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
                      const Icon(
                        Icons.lock_reset_outlined,
                        size: 72,
                        color: AppColors.tealA700,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Reset your password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.blueGray900,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your registered email address. If an account exists, we will send a secure reset link.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.blueGray700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        enabled: !state.isLoading && !state.linkSent,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        onChanged: viewModel.onEmailChanged,
                        onFieldSubmitted: (_) => viewModel.onSendPressed(),
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          hintText: 'name@example.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          errorText: state.emailError,
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
                      if (state.linkSent) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.goodPercentageBg,
                            border: Border.all(
                              color: AppColors.goodPercentageStroke,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.mark_email_read_outlined,
                                color: AppColors.goodPercentageText,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'If an account is registered with that email, a reset link has been sent. Please also check your spam folder.',
                                  style: TextStyle(
                                    color: AppColors.goodPercentageText,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: state.isLoading || state.linkSent
                            ? null
                            : viewModel.onSendPressed,
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
                            : const Text('Send Reset Link'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : () => Navigator.maybePop(context),
                        child: const Text('Back to Login'),
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
