import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/delete_account_view_model.dart';
import '../widgets/auth_form_widgets.dart';

class DeleteAccountConfirmationScreen extends StatelessWidget {
  const DeleteAccountConfirmationScreen({super.key});

  static Widget builder(BuildContext context) {
    return const DeleteAccountViewModelScope(
      child: DeleteAccountConfirmationScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeleteAccountViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        return PopScope(
          canPop: false,
          child: AuthPage(
            title: 'Final Confirmation',
            subtitle:
            'Your deletion request has been confirmed. This final action cannot be undone.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: appTheme.wholeAlertBudgetBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: appTheme.wholeAlertBudgetStroke),
                  ),
                  child: Text(
                    'Deleting removes your TREK account, profile picture, personal constraints and associated app data.',
                    style: TextStyle(
                      color: appTheme.wholeAlertBudgetText,
                      height: 1.45,
                    ),
                  ),
                ),
                if (state.errorMessage != null)
                  AuthMessage(message: state.errorMessage),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: state.isDeleting || state.isCancelling
                      ? null
                      : () => _showFinalDialog(context, viewModel),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: appTheme.errorRed,
                    foregroundColor: appTheme.white_A700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: state.isDeleting
                      ? SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: appTheme.white_A700,
                    ),
                  )
                      : const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete Permanently'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: state.isDeleting || state.isCancelling
                      ? null
                      : viewModel.cancelDeletion,
                  child: state.isCancelling
                      ? const Text('Cancelling…')
                      : const Text('Keep My Account'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFinalDialog(
      BuildContext context,
      DeleteAccountViewModel viewModel,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently delete account?'),
        content: const Text(
          'This is your final confirmation. Your account and associated TREK data cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: appTheme.errorRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.deletePermanently();
  }
}
