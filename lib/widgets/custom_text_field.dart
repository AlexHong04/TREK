import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final String sectionTitle;
  final String hintText;
  final IconData prefixIcon;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final Function(String)? onFieldSubmitted;
  final Function(String)? onChanged;
  final bool readOnly;
  final TextInputType? keyboardType;
  final Widget? bottomWidget;
  final Widget? suffixIcon;

  const CustomTextField({
    super.key,
    required this.sectionTitle,
    required this.hintText,
    required this.prefixIcon,
    this.controller,
    this.validator,
    this.onTap,
    this.onFieldSubmitted,
    this.onChanged,
    this.readOnly = false,
    this.keyboardType,
    this.bottomWidget,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
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
            sectionTitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: appTheme.blue_gray_300,
            ).copyWith(letterSpacing: 1, height: 1.2),
          ),
          TextFormField(
            controller: controller,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            readOnly: readOnly,
            onTap: onTap,
            onFieldSubmitted: onFieldSubmitted,
            onChanged: onChanged,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              color: appTheme.gray_800,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                color: appTheme.gray_800,
              ).copyWith(color: appTheme.blue_gray_300),
              prefixIcon: Icon(prefixIcon),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44.0,
                minHeight: 34.0,
              ),
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 6.0,
                horizontal: 12.0,
              ),
              filled: true,
              fillColor: appTheme.white_A700,
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: appTheme.colorFFEF44, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: appTheme.colorFFEF44, width: 1.0),
              ),
            ),
            validator: validator,
          ),
          if (bottomWidget != null) ...[
            const SizedBox(height: 12.0),
            bottomWidget!,
          ],
        ],
      ),
    );
  }
}
