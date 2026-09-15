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
        final emailChanged = state.newEmail.trim().toLowerCase() !=
            state.accountEmail.trim().toLowerCase();
        final needsPasswordForEmailChange = !state.isEmailVerified &&
            state.hasPasswordSignIn &&
            emailChanged &&
            !isGoogleManaged;
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
                        textInputAction: needsPasswordForEmailChange
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
                        needsPasswordForEmailChange || isGoogleManaged
                            ? null
                            : (_) => viewModel.saveEmail(),
                        errorText: state.newEmailError,
                      ),
                    ),
                    if (needsPasswordForEmailChange) ...[
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
                    FilledButton(
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
                      child: Text(
                        state.isSavingEmail
                            ? 'Changing Email…'
                            : state.emailChangeCooldownSeconds > 0
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
                                    : () => _showGoogleLinkDialog(
                                  context,
                                  viewModel,
                                ),
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
                                    state.hasGoogleIdentity
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
                    OutlinedButton(
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
                      child: Text(
                        state.isRequestingDeletion
                            ? 'Requesting…'
                            : state.isEmailVerified &&
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

  Future<void> _showGoogleLinkDialog(
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
      final password = await _showActionDialog(
        context: context,
        icon: Icons.add_link_rounded,
        iconColor: appTheme.teal_A700,
        title: 'Link Google?',
        message:
        'Confirm your identity before adding Google as another TREK sign-in method.',
        actionText: 'Link',
        requiresPassword: state.hasPasswordSignIn,
      );
      if (password != null) {
        await viewModel.linkGoogle(currentPassword: password);
      }
    } finally {
      _googleDialogOpen = false;
    }
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
      final password = await _showActionDialog(
        context: context,
        icon: Icons.link_off_rounded,
        iconColor: appTheme.errorRed,
        title: 'Unlink Google?',
        message:
        '${state.googleEmail ?? 'Your Google account'} will no longer be available for TREK sign-in. Your Google account will not be deleted.',
        actionText: 'Unlink',
        actionColor: appTheme.errorRed,
        requiresPassword: state.hasPasswordSignIn,
        onSubmit: (password) async {
          await viewModel.unlinkGoogle(currentPassword: password);
          final freshState = viewModel.uiState;
          return freshState.hasGoogleIdentity
              ? freshState.errorMessage ??
              'Unable to unlink Google. Please try again.'
              : null;
        },
      );
      // Unlinking runs while the dialog remains mounted. This prevents auth
      // notifications from rebuilding the overlay while Flutter removes it.
      if (password == null) return;
    } finally {
      _googleDialogOpen = false;
    }
  }

  Future<void> _confirmDeletionRequest(
      BuildContext context,
      EditAccountViewModel viewModel,
      ) async {
    final state = viewModel.uiState;
    final password = await _showActionDialog(
      context: context,
      icon: Icons.warning_amber_rounded,
      iconColor: appTheme.errorRed,
      title: 'Request account deletion?',
      message:
      'This starts the deletion process. After final confirmation, your account will be disabled and retained for 30 days before permanent deletion.',
      actionText: 'Continue',
      actionColor: appTheme.errorRed,
      requiresPassword:
      !state.isEmailVerified && state.hasPasswordSignIn,
    );
    if (password != null) {
      await viewModel.requestDeletion(currentPassword: password);
    }
  }

  Future<String?> _showActionDialog({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String actionText,
    required bool requiresPassword,
    Color? actionColor,
    Future<String?> Function(String password)? onSubmit,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AccountActionDialog(
        icon: icon,
        iconColor: iconColor,
        title: title,
        message: message,
        actionText: actionText,
        requiresPassword: requiresPassword,
        actionColor: actionColor,
        onSubmit: onSubmit,
      ),
    );
  }
}

class _AccountActionDialog extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String actionText;
  final bool requiresPassword;
  final Color? actionColor;
  final Future<String?> Function(String password)? onSubmit;

  const _AccountActionDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actionText,
    required this.requiresPassword,
    this.actionColor,
    this.onSubmit,
  });

  @override
  State<_AccountActionDialog> createState() => _AccountActionDialogState();
}

class _AccountActionDialogState extends State<_AccountActionDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _passwordError;
  String? _actionError;

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final password =
    widget.requiresPassword ? _passwordController.text : '';
    if (widget.requiresPassword && password.isEmpty) {
      setState(() {
        _passwordError = 'Current password is required.';
        _actionError = null;
      });
      _passwordFocusNode.requestFocus();
      return;
    }

    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      _passwordFocusNode.unfocus();
      Navigator.pop(context, password);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _passwordError = null;
      _actionError = null;
    });
    final error = await onSubmit(password);
    if (!mounted) return;
    if (error == null) {
      _passwordFocusNode.unfocus();
      Navigator.pop(context, password);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _actionError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(widget.icon, color: widget.iconColor),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            if (widget.requiresPassword) ...[
              const SizedBox(height: 18),
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                enabled: !_isSubmitting,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                autofocus: true,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) {
                  if (_passwordError != null || _actionError != null) {
                    setState(() {
                      _passwordError = null;
                      _actionError = null;
                    });
                  }
                },
                onSubmitted: _isSubmitting ? null : (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Current password',
                  errorText: _passwordError,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: _isSubmitting
                        ? null
                        : () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
            ],
            if (_actionError != null) ...[
              const SizedBox(height: 12),
              Text(
                _actionError!,
                style: TextStyle(color: appTheme.errorRed),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        SizedBox(
          width: double.maxFinite,
          child: Row(
            children: [
              Expanded(
                child: _AccountDialogButton(
                  text: 'Cancel',
                  outlined: true,
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AccountDialogButton(
                  text: _isSubmitting
                      ? '${widget.actionText}ing…'
                      : widget.actionText,
                  backgroundColor: widget.actionColor,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountDialogButton extends StatelessWidget {
  final String text;
  final bool outlined;
  final Color? backgroundColor;
  final VoidCallback? onPressed;

  const _AccountDialogButton({
    required this.text,
    this.outlined = false,
    this.backgroundColor,
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
          backgroundColor: backgroundColor ?? appTheme.teal_A700,
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
