import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_button/sign_in_button.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/edit_account_view_model.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';

class EditAccountScreen extends StatefulWidget {
  const EditAccountScreen({super.key});

  static Widget builder(BuildContext context) {
    return const EditAccountViewModelScope(child: EditAccountScreen());
  }

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen>
    with WidgetsBindingObserver {
  EditAccountViewModel? _viewModel;
  bool _wasBackgrounded = false;
  bool _googleDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel = context.read<EditAccountViewModel>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      unawaited(_viewModel?.onAppResumedAfterGoogleLink());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditAccountViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        final isGoogleManaged = state.isGoogleManagedAccount;
        final isAccountOperationInProgress = state.isSavingEmail ||
            state.isLinkingGoogle ||
            state.isUnlinkingGoogle ||
            state.isRequestingDeletion;
        return PopScope(
          canPop: !isAccountOperationInProgress,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Scaffold(
              backgroundColor: appTheme.gray_50_02,
              appBar: CustomAppBar(
                title: 'Edit Account',
                backEnabled: !isAccountOperationInProgress,
              ),
              body: state.isLoading
                  ? Center(
                child: CircularProgressIndicator(color: appTheme.teal_A700),
              )
                  : SafeArea(
                top: false,
                child: ListView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    if (isGoogleManaged) ...[
                      const _StatusCard(
                        icon: Icons.info_outline,
                        message:
                        'This account is managed through Google. Its account email and Google sign-in cannot be changed or unlinked in TREK.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.isOffline) ...[
                      const _StatusCard(
                        icon: Icons.cloud_off_outlined,
                        message:
                        'You’re offline. Account settings are view-only.',
                        isError: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.successMessage != null) ...[
                      _StatusCard(
                        icon: Icons.check_circle_outline,
                        message: state.successMessage!,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.errorMessage != null) ...[
                      _StatusCard(
                        icon: Icons.error_outline,
                        message: state.errorMessage!,
                        isError: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Focus(
                      onFocusChange: (focused) {
                        if (!focused) viewModel.onEmailFocusLost();
                      },
                      child: CustomTextField(
                        key: ValueKey(state.accountEmail),
                        sectionTitle: 'ACCOUNT EMAIL',
                        hintText: 'Enter your account email',
                        prefixIcon: Icons.email_outlined,
                        margin: EdgeInsets.zero,
                        initialValue: state.newEmail,
                        enabled: !state.isBusy &&
                            !state.isOffline &&
                            !isGoogleManaged,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: state.hasPasswordSignIn
                            ? TextInputAction.next
                            : TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        onChanged: viewModel.onNewEmailChanged,
                        onFieldSubmitted:
                        state.hasPasswordSignIn || isGoogleManaged
                            ? null
                            : (_) => viewModel.saveEmail(),
                        errorText: state.newEmailError,
                      ),
                    ),
                    if (state.hasPasswordSignIn && !isGoogleManaged) ...[
                      const SizedBox(height: 12),
                      Focus(
                        onFocusChange: (focused) {
                          if (!focused) viewModel.onCurrentPasswordFocusLost();
                        },
                        child: CustomTextField(
                          sectionTitle: 'CURRENT PASSWORD',
                          hintText: 'Confirm your current password',
                          prefixIcon: Icons.lock_outline,
                          margin: EdgeInsets.zero,
                          enabled: !state.isBusy && !state.isOffline,
                          obscureText: state.obscureCurrentPassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onChanged: viewModel.onCurrentPasswordChanged,
                          errorText: state.currentPasswordError,
                          suffixIcon: IconButton(
                            tooltip: state.obscureCurrentPassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: state.isBusy || state.isOffline
                                ? null
                                : viewModel.togglePasswordVisibility,
                            icon: Icon(
                              state.obscureCurrentPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: state.isBusy ||
                          state.isOffline ||
                          state.emailChangeCooldownSeconds > 0 ||
                          isGoogleManaged
                          ? null
                          : viewModel.saveEmail,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: appTheme.teal_A700,
                        foregroundColor: appTheme.white_A700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: state.isSavingEmail
                          ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: appTheme.white_A700,
                        ),
                      )
                          : const Icon(Icons.mark_email_read_outlined),
                      label: Text(
                        state.emailChangeCooldownSeconds > 0
                            ? 'Send again in ${state.emailChangeCooldownSeconds}s'
                            : 'Change Email',
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: IgnorePointer(
                        ignoring: state.isBusy ||
                            state.isOffline ||
                            isGoogleManaged,
                        child: Opacity(
                          opacity: state.isBusy ||
                              state.isOffline ||
                              isGoogleManaged
                              ? 0.5
                              : 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              SignInButton(
                                Buttons.google,
                                text: state.isLinkingGoogle
                                    ? 'Opening Google...'
                                    : state.isUnlinkingGoogle
                                    ? 'Unlinking Google...'
                                    : state.hasGoogleIdentity
                                    ? 'Google account linked'
                                    : 'Link Google account',
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                onPressed: isGoogleManaged
                                    ? () {}
                                    : state.hasGoogleIdentity
                                    ? () => _showGoogleDialog(
                                  context,
                                  viewModel,
                                )
                                    : viewModel.linkGoogle,
                              ),
                              Positioned(
                                right: 14,
                                top: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: state.isLinkingGoogle ||
                                      state.isUnlinkingGoogle
                                      ? const Center(
                                    child: SizedBox.square(
                                      dimension: 18,
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF5F6368),
                                      ),
                                    ),
                                  )
                                      : Icon(
                                    isGoogleManaged
                                        ? Icons.lock_outline_rounded
                                        : state.hasGoogleIdentity
                                        ? Icons.link_rounded
                                        : Icons.add_link_rounded,
                                    size: 20,
                                    color: const Color(0xFF5F6368),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    OutlinedButton.icon(
                      onPressed: state.isBusy ||
                          state.isOffline ||
                          (state.isEmailVerified &&
                              state.deletionCooldownSeconds > 0)
                          ? null
                          : () => _confirmDeletionRequest(
                        context,
                        viewModel,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: appTheme.errorRed,
                        side: BorderSide(color: appTheme.errorRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: state.isRequestingDeletion
                          ? SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: appTheme.errorRed,
                        ),
                      )
                          : const Icon(Icons.delete_forever_outlined),
                      label: Text(
                        state.isEmailVerified &&
                            state.deletionCooldownSeconds > 0
                            ? 'Send again in ${state.deletionCooldownSeconds}s'
                            : 'Delete Account',
                      ),
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

  Future<void> _showGoogleDialog(
      BuildContext context,
      EditAccountViewModel viewModel,
      ) async {
    if (_googleDialogOpen ||
        viewModel.uiState.isBusy ||
        viewModel.uiState.isGoogleManagedAccount) {
      return;
    }
    _googleDialogOpen = true;
    try {
      final state = viewModel.uiState;
      if (!state.isEmailVerified) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              Icons.mark_email_unread_outlined,
              color: appTheme.teal_A700,
            ),
            title: const Text('Verify your email first'),
            content: Text(
              '${state.googleEmail ?? 'Your Google account'} is linked. Verify your TREK account email before unlinking Google.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.link_off_rounded, color: appTheme.errorRed),
          title: const Text('Unlink Google?'),
          content: Text(
            '${state.googleEmail ?? 'Your Google account'} will no longer be available for TREK sign-in. Your Google account will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style:
              FilledButton.styleFrom(backgroundColor: appTheme.errorRed),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Unlink'),
            ),
          ],
        ),
      );
      if (confirmed == true) await viewModel.unlinkGoogle();
    } finally {
      _googleDialogOpen = false;
    }
  }

  Future<void> _confirmDeletionRequest(
      BuildContext context,
      EditAccountViewModel viewModel,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: appTheme.errorRed),
        title: const Text('Request account deletion?'),
        content: const Text(
          'This starts the permanent deletion process. You will still receive one final confirmation before anything is deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: appTheme.errorRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.requestDeletion();
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;

  const _StatusCard({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? appTheme.wholeAlertBudgetBg : appTheme.wholeGoodBudgetBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: isError
                ? appTheme.wholeAlertBudgetText
                : appTheme.wholeGoodBudgetText,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError
                    ? appTheme.wholeAlertBudgetText
                    : appTheme.wholeGoodBudgetText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
