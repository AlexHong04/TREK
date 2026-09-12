import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_button/sign_in_button.dart';

import '../view_models/presentation_logic/login_view_model.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onRegister;
  final VoidCallback? onForgotPassword;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.onRegister,
    this.onForgotPassword,
  });

  static Widget builder(
      BuildContext context, {
        VoidCallback? onLoginSuccess,
        VoidCallback? onRegister,
        VoidCallback? onForgotPassword,
      }) {
    final argument = ModalRoute.of(context)?.settings.arguments;
    return LoginViewModelScope(
      initialEmail: argument is String ? argument : '',
      child: LoginScreen(
        onLoginSuccess: onLoginSuccess,
        onRegister: onRegister,
        onForgotPassword: onForgotPassword,
      ),
    );
  }

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with WidgetsBindingObserver {
  static const Duration _exitConfirmationWindow = Duration(seconds: 2);
  DateTime? _lastBackPressedAt;
  LoginViewModel? _viewModel;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      unawaited(_viewModel?.onAppResumedAfterGoogleSignIn());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<LoginViewModel>();
    if (identical(next, _viewModel)) return;
    _viewModel?.removeListener(_handleViewModelEvent);
    _viewModel = next;
    next.addListener(_handleViewModelEvent);
    _handleViewModelEvent();
  }

  void _handleViewModelEvent() {
    final viewModel = _viewModel;
    if (viewModel == null) return;
    final state = viewModel.uiState;
    final message = state.errorMessage ?? state.infoMessage;
    final isError = state.errorMessage != null;
    if (message != null) {
      viewModel.consumeMessages();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAuthToast(context, message, isError: isError);
      });
    }
    if (state.loginSucceeded) {
      viewModel.consumeLoginSuccess();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onLoginSuccess?.call();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel?.removeListener(_handleViewModelEvent);
    super.dispose();
  }

  void _handleSystemBack() {
    final now = DateTime.now();
    final lastBackPressedAt = _lastBackPressedAt;
    if (lastBackPressedAt != null &&
        now.difference(lastBackPressedAt) <= _exitConfirmationWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    FocusManager.instance.primaryFocus?.unfocus();
    showAuthToast(context, 'Press back again to exit TREK.');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;

        void openRegistration() {
          if (widget.onRegister != null) {
            widget.onRegister!();
          } else {
            Navigator.pushNamed(
              context,
              '/register',
              arguments: state.email,
            );
          }
        }

        void openForgotPassword() {
          if (widget.onForgotPassword != null) {
            widget.onForgotPassword!();
          } else {
            Navigator.pushNamed(
              context,
              '/forgotPassword',
              arguments: state.email,
            );
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleSystemBack();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: AuthPage(
              title: 'Sign in to your account',
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
                        initialValue: state.email,
                        enabled: !state.isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        onChanged: viewModel.onEmailChanged,
                        errorText: state.emailError,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) viewModel.onPasswordFocusLost();
                      },
                      child: CustomTextField(
                        sectionTitle: 'PASSWORD',
                        hintText: 'Enter your password',
                        prefixIcon: Icons.lock_outline,
                        margin: EdgeInsets.zero,
                        enabled: !state.isLoading,
                        obscureText: state.obscurePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onChanged: viewModel.onPasswordChanged,
                        onFieldSubmitted: (_) => viewModel.onLoginPressed(),
                        errorText: state.passwordError,
                        suffixIcon: IconButton(
                          tooltip: state.obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: state.isLoading
                              ? null
                              : viewModel.togglePasswordVisibility,
                          icon: Icon(
                            state.obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: state.isLoading ? null : openForgotPassword,
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    if (state.showMagicLinkOption)
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : viewModel.onSendMagicLinkPressed,
                        child: Text(
                          state.magicLinkSent
                              ? 'Secure login link sent'
                              : 'Continue with email (magic link)',
                        ),
                      ),
                    const SizedBox(height: 22),
                    AuthPrimaryButton(
                      label: 'Log in',
                      isLoading: state.isLoading,
                      onPressed: viewModel.onLoginPressed,
                    ),
                    const SizedBox(height: 7),
                    AuthLinkLine(
                      text: "Don't have an account? ",
                      linkText: 'Register with an email.',
                      onTap: state.isLoading ? null : openRegistration,
                    ),
                    const SizedBox(height: 20),
                    const AuthOrDivider(),
                    const SizedBox(height: 20),
                    IgnorePointer(
                      ignoring: state.isLoading,
                      child: Opacity(
                        opacity: state.isLoading ? 0.55 : 1,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: SignInButton(
                            Buttons.google,
                            text: 'Continue with Google',
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onPressed: viewModel.onGoogleSignInPressed,
                          ),
                        ),
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
}
