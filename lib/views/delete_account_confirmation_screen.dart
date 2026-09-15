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
            'Your account will be disabled now and permanently deleted after 30 days.',
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
                    'Your TREK data will be retained for 30 days, then permanently deleted. You cannot sign in or register another account with this email during that time.',
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
                  label: const Text('Confirm Deletion'),
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
        icon: Icon(Icons.delete_forever_outlined, color: appTheme.errorRed),
        title: const Text('Schedule account deletion?'),
        content: const Text(
          'Your account will be disabled immediately and permanently deleted after 30 days. An administrator can reactivate it before the deadline.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: Row(
              children: [
                Expanded(
                  child: _DeleteAccountDialogButton(
                    text: 'Cancel',
                    outlined: true,
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DeleteAccountDialogButton(
                    text: 'Confirm',
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.deletePermanently();
  }
}

class _DeleteAccountDialogButton extends StatelessWidget {
  final String text;
  final bool outlined;
  final VoidCallback onPressed;

  const _DeleteAccountDialogButton({
    required this.text,
    this.outlined = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    return SizedBox(
      height: 48,
      child: outlined
          ? OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: appTheme.blue_gray_300,
          backgroundColor: appTheme.white_A700,
          side: BorderSide(color: appTheme.gray_200, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: label,
      )
          : FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: appTheme.teal_A700,
          foregroundColor: appTheme.white_A700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: label,
      ),
    );
  }
}
