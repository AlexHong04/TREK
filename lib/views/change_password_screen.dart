import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/change_password_view_model.dart';
import '../view_models/ui_state/change_password_ui_state.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  static Widget builder(BuildContext context) {
    return const ChangePasswordViewModelScope(child: ChangePasswordScreen());
  }

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _isNewPasswordFocused = false;
  bool _reauthenticationDialogOpen = false;
  bool _passwordResultHandled = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChangePasswordViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        if (state.passwordSaved && !_passwordResultHandled) {
          // Set this before scheduling. Auth refreshes can rebuild the screen
          // several times in one frame; without a guard each rebuild schedules
          // another Navigator.pop(), eventually removing Edit Account as well.
          _passwordResultHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final message = state.successMessage ??
                (state.isSetMode
                    ? 'Password set successfully.'
                    : 'Password changed. Please log in again.');
            viewModel.consumePasswordSaved();
            showThreeSecondMessage(
              context,
              message,
            );
            if (state.isSetMode) Navigator.pop(context, true);
          });
        }
        if (state.errorMessage != null) {
          final message = state.errorMessage!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeMessages();
            showThreeSecondMessage(context, message, isError: true);
          });
        }
        if (state.logoutRequested && !_reauthenticationDialogOpen) {
          _reauthenticationDialogOpen = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) {
              _reauthenticationDialogOpen = false;
              return;
            }
            viewModel.consumeLogoutRequest();
            try {
              await _showGoogleReauthenticationDialog(context, viewModel);
            } finally {
              _reauthenticationDialogOpen = false;
            }
          });
        }

        return PopScope(
          canPop: !state.isSaving,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Scaffold(
              backgroundColor: appTheme.gray_50_02,
              appBar: CustomAppBar(
                title: state.title,
                backEnabled: !state.isSaving,
              ),
              body: SafeArea(
                top: false,
                child: state.mode == PasswordPageMode.loading
                    ? Center(
                  child: CircularProgressIndicator(color: appTheme.teal_A700),
                )
                    : ListView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.manual,
                  padding: const EdgeInsets.fromLTRB(20, 34, 20, 32),
                  children: [
                    if (state.isOffline) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: appTheme.wholeAlertBudgetBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'You’re offline. Password settings are view-only.',
                          style: TextStyle(color: appTheme.wholeAlertBudgetText),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (state.isSetMode) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: appTheme.teal_50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: appTheme.teal_A700),
                        ),
                        child: Text(
                          state.requiresRecentGoogleAuthentication
                              ? 'You currently use Google sign-in. Log out and sign in with Google again before setting your first password.'
                              : 'You currently use Google sign-in. Set a password to also sign in with your account email and password. Google will remain linked.',
                          style: TextStyle(color: appTheme.teal_800, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ] else ...[
                      _PasswordField(
                        label: 'CURRENT PASSWORD',
                        hint: 'Enter your current password',
                        obscure: state.obscureCurrentPassword,
                        enabled: !state.isSaving && !state.isOffline,
                        errorText: state.currentPasswordError,
                        onChanged: viewModel.onCurrentPasswordChanged,
                        onFocusLost: viewModel.onCurrentPasswordFocusLost,
                        onToggleVisibility:
                        viewModel.toggleCurrentPasswordVisibility,
                      ),
                      const SizedBox(height: 22),
                    ],
                    _PasswordField(
                      label: 'NEW PASSWORD',
                      hint: state.isSetMode
                          ? 'Create a password'
                          : 'Enter your new password',
                      obscure: state.obscureNewPassword,
                      enabled: !state.isSaving && !state.isOffline,
                      errorText: state.newPasswordError,
                      onChanged: viewModel.onNewPasswordChanged,
                      onFocusLost: viewModel.onNewPasswordFocusLost,
                      onFocusChanged: (hasFocus) {
                        if (_isNewPasswordFocused != hasFocus) {
                          setState(() => _isNewPasswordFocused = hasFocus);
                        }
                      },
                      onToggleVisibility: viewModel.toggleNewPasswordVisibility,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => viewModel.savePassword(),
                      bottomWidget: PasswordPolicyChecklist(
                        password: state.newPassword,
                        isVisible: _isNewPasswordFocused,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed:
                      state.isSaving || state.isOffline
                          ? null
                          : viewModel.savePassword,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: appTheme.teal_A700,
                        foregroundColor: appTheme.white_A700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: state.isSaving
                          ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: appTheme.white_A700,
                        ),
                      )
                          : Text(state.title),
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

  Future<void> _showGoogleReauthenticationDialog(
      BuildContext context,
      ChangePasswordViewModel viewModel,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.security_outlined, color: appTheme.teal_A700),
        title: const Text('Sign in with Google again'),
        content: const Text(
          'For security, log out and sign in with Google again before setting your password.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: Row(
              children: [
                Expanded(
                  child: _LogoutDialogButton(
                    text: 'Cancel',
                    backgroundColor: appTheme.white_A700,
                    foregroundColor: appTheme.blue_gray_300,
                    borderColor: appTheme.gray_200,
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LogoutDialogButton(
                    text: 'Confirm',
                    backgroundColor: appTheme.teal_A700,
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.logoutForGoogleReauthentication();
  }
}

class _LogoutDialogButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  /// Optional overrides so a non-destructive button can use the same neutral
  /// treatment as the Discard button in the expense form.
  final Color? foregroundColor;
  final Color? borderColor;
  final VoidCallback onPressed;

  const _LogoutDialogButton({
    required this.text,
    required this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor ?? appTheme.white_A700,
          side: borderColor == null ? null : BorderSide(color: borderColor!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscure;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onFocusLost;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback onToggleVisibility;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? bottomWidget;

  const _PasswordField({
    required this.label,
    required this.hint,
    required this.obscure,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
    required this.onFocusLost,
    this.onFocusChanged,
    required this.onToggleVisibility,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        onFocusChanged?.call(hasFocus);
        if (!hasFocus) onFocusLost();
      },
      child: CustomTextField(
        sectionTitle: label,
        hintText: hint,
        prefixIcon: Icons.lock_outline,
        margin: EdgeInsets.zero,
        enabled: enabled,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: textInputAction,
        autofillHints: [
          label.startsWith('CURRENT')
              ? AutofillHints.password
              : AutofillHints.newPassword,
        ],
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        errorText: errorText,
        bottomWidget: bottomWidget,
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          onPressed: enabled ? onToggleVisibility : null,
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}
