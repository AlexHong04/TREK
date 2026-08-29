import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/change_password_view_model.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/custom_app_bar.dart';

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
                  ),
                  PasswordPolicyChecklist(
                    password: state.newPassword,
                    isVisible: _isNewPasswordFocused,
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: appTheme.teal_A700,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Focus(
          onFocusChange: (hasFocus) {
            onFocusChanged?.call(hasFocus);
            if (!hasFocus) onFocusLost();
          },
          child: TextFormField(
            enabled: enabled,
            obscureText: obscure,
            textInputAction: textInputAction,
            autofillHints: [
              label.startsWith('CURRENT')
                  ? AutofillHints.password
                  : AutofillHints.newPassword,
            ],
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hint,
              errorText: errorText,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: enabled ? onToggleVisibility : null,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              filled: true,
              fillColor: appTheme.white_A700,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(color: appTheme.blue_gray_300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(color: appTheme.teal_A700, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
