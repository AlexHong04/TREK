import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/change_password_view_model.dart';
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ChangePasswordViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        if (state.passwordChanged) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            showThreeSecondMessage(
              context,
              'Password changed. Please log in again.',
            );
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
                  (route) => false,
            );
          });
        }
        if (state.errorMessage != null) {
          final message = state.errorMessage!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeErrorMessage();
            showThreeSecondMessage(context, message, isError: true);
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Scaffold(
            backgroundColor: appTheme.gray_50_02,
            appBar: const CustomAppBar(title: 'Change Password'),
            body: SafeArea(
              top: false,
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 34, 20, 32),
                children: [
                  _PasswordField(
                    label: 'CURRENT PASSWORD',
                    hint: 'Enter your current password',
                    obscure: state.obscureCurrentPassword,
                    enabled: !state.isSaving,
                    errorText: state.currentPasswordError,
                    onChanged: viewModel.onCurrentPasswordChanged,
                    onFocusLost: viewModel.onCurrentPasswordFocusLost,
                    onToggleVisibility:
                    viewModel.toggleCurrentPasswordVisibility,
                  ),
                  const SizedBox(height: 22),
                  _PasswordField(
                    label: 'NEW PASSWORD',
                    hint: 'Enter your new password',
                    obscure: state.obscureNewPassword,
                    enabled: !state.isSaving,
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
                    onSubmitted: (_) => viewModel.changePassword(),
                    bottomWidget: PasswordPolicyChecklist(
                      password: state.newPassword,
                      isVisible: _isNewPasswordFocused,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed:
                    state.isSaving ? null : viewModel.changePassword,
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
                        : const Text('Change Password'),
                  ),
                  TextButton(
                    onPressed:
                    state.isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
