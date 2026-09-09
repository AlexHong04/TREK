import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final String sectionTitle;
  final String hintText;
  final IconData prefixIcon;
  final TextEditingController? controller;
  final String? initialValue;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final String? errorText;
  final int errorMaxLines;
  final Widget? bottomWidget;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry margin;
  final Color? prefixIconColor;

  const CustomTextField({
    super.key,
    required this.sectionTitle,
    required this.hintText,
    required this.prefixIcon,
    this.controller,
    this.initialValue,
    this.validator,
    this.onTap,
    this.onFieldSubmitted,
    this.onChanged,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.focusNode,
    this.errorText,
    this.errorMaxLines = 3,
    this.bottomWidget,
    this.suffixIcon,
    this.margin = const EdgeInsets.symmetric(horizontal: 24.0),
    this.prefixIconColor,
  }) : assert(
         controller == null || initialValue == null,
         'controller and initialValue cannot both be provided.',
       );

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _hasLostFocus = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: appTheme.gray_100, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.sectionTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: appTheme.blue_gray_300,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6.0),
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus && !_hasLostFocus) {
                // Field lost focus for the first time
                setState(() {
                  _hasLostFocus = true;
                });
              }
            },
            child: TextFormField(
              controller: widget.controller,
              initialValue: widget.initialValue,
              focusNode: widget.focusNode,
              enabled: widget.enabled,
              autovalidateMode: _hasLostFocus
                  ? AutovalidateMode.always
                  : AutovalidateMode.onUserInteraction,
              readOnly: widget.readOnly,
              obscureText: widget.obscureText,
              autocorrect: widget.autocorrect,
              enableSuggestions: widget.enableSuggestions,
              onTap: widget.onTap,
              onFieldSubmitted: widget.onFieldSubmitted,
              onChanged: widget.onChanged,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              autofillHints: widget.autofillHints,
              inputFormatters: widget.inputFormatters,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                color: appTheme.gray_800,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                  color: appTheme.blue_gray_300,
                ),
                errorText: widget.errorText,
                errorMaxLines: widget.errorMaxLines,
                prefixIcon: Icon(
                  widget.prefixIcon,
                  color: widget.prefixIconColor ?? appTheme.teal_A700,
                  size: 20.0,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44.0,
                  minHeight: 34.0,
                ),
                suffixIcon: widget.suffixIcon,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 6.0,
                  horizontal: 12.0,
                ),
                filled: true,
                fillColor: widget.enabled
                    ? appTheme.white_A700
                    : appTheme.gray_200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: appTheme.gray_200, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: appTheme.gray_200, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: appTheme.teal_A700, width: 1.0),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: appTheme.gray_200, width: 1.0),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                    color: appTheme.colorFFEF44,
                    width: 1.0,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                    color: appTheme.colorFFEF44,
                    width: 1.0,
                  ),
                ),
              ),
              validator: widget.validator,
            ),
          ),
          if (widget.bottomWidget != null) ...[
            const SizedBox(height: 12.0),
            widget.bottomWidget!,
          ],
        ],
      ),
    );
  }
}
