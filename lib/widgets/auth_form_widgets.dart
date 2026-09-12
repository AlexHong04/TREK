import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/input_validator.dart';

void showAuthToast(
    BuildContext context,
    String message, {
      bool isError = false,
    }) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? appTheme.errorRed : appTheme.teal_700,
      ),
    );
}

class AuthPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const AuthPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/logo.png', height: 100),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: appTheme.teal_A700,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 9),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appTheme.blue_gray_700,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 34),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  final String text;

  const AuthFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          color: appTheme.teal_A700,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

InputDecoration authFieldDecoration({
  required String hint,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    errorText: errorText,
    errorMaxLines: 3,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: appTheme.white_A700,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: appTheme.blue_gray_300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: appTheme.teal_A700, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: appTheme.errorRed),
    ),
  );
}

class PasswordPolicyChecklist extends StatelessWidget {
  final String password;
  final bool isVisible;

  const PasswordPolicyChecklist({
    super.key,
    required this.password,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    final checks = InputValidator.checkNewPassword(password);
    final requirements = <({String label, bool isMet})>[
      (
      label:
      '${InputValidator.minPasswordLength}–${InputValidator.maxPasswordLength} characters',
      isMet: checks.hasMinimumLength,
      ),
      (
      label: 'At least one uppercase letter',
      isMet: checks.hasUppercase,
      ),
      (
      label: 'At least one lowercase letter',
      isMet: checks.hasLowercase,
      ),
      (
      label: 'At least one number',
      isMet: checks.hasDigit,
      ),
      (
      label:
      'At least one allowed special character: ${InputValidator.allowedPasswordSpecialCharacters}',
      isMet: checks.hasSpecialCharacter,
      ),
    ];

    final checklist = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appTheme.gray_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must include:',
            style: TextStyle(
              color: appTheme.blue_gray_700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          for (final requirement in requirements)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      requirement.isMet
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      key: ValueKey(requirement.isMet),
                      size: 17,
                      color: requirement.isMet
                          ? appTheme.teal_700
                          : appTheme.blue_gray_300,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      requirement.label,
                      style: TextStyle(
                        color: requirement.isMet
                            ? appTheme.teal_700
                            : appTheme.blue_gray_700,
                        fontSize: 12,
                        height: 1.25,
                        decoration: requirement.isMet
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return ClipRect(
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: isVisible
          ? Padding(
        key: const ValueKey('password-policy-visible'),
        padding: const EdgeInsets.only(top: 10),
        child: checklist,
      )
          : const SizedBox(
        key: ValueKey('password-policy-hidden'),
        width: double.infinity,
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: appTheme.teal_A700,
        foregroundColor: appTheme.white_A700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: isLoading
            ? SizedBox.square(
          key: const ValueKey('loader'),
          dimension: 22,
          child: CircularProgressIndicator(
            color: appTheme.white_A700,
            strokeWidth: 2.5,
          ),
        )
            : Text(label, key: ValueKey(label)),
      ),
    );
  }
}

class AuthLinkLine extends StatelessWidget {
  final String text;
  final String linkText;
  final VoidCallback? onTap;

  const AuthLinkLine({
    super.key,
    required this.text,
    required this.linkText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: TextStyle(color: appTheme.blue_gray_300)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            minimumSize: const Size(0, 36),
          ),
          child: Text(
            linkText,
            style: TextStyle(
              color: appTheme.teal_A700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: appTheme.gray_200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('OR', style: TextStyle(color: appTheme.blue_gray_700)),
        ),
        Expanded(child: Divider(color: appTheme.gray_200)),
      ],
    );
  }
}

class AuthMessage extends StatelessWidget {
  final String? message;
  final bool isError;

  const AuthMessage({
    super.key,
    required this.message,
    this.isError = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      child: message == null
          ? const SizedBox.shrink()
          : Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          message!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? appTheme.errorRed : appTheme.teal_700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
