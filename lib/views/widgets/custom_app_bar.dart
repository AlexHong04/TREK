import 'package:flutter/material.dart';


import '../theme/app_theme.dart';
// removed size_utils.dart per user request

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.title,
    this.leadingImagePath,
    this.onLeadingTap,
    this.titleColor,
    this.titleFontSize,
    this.backgroundColor,
    this.bottomBorderColor,
    this.paddingHorizontal,
    this.paddingVertical,
    this.leadingIconSize,
    this.actions,
  });

  final String? title;
  final String? leadingImagePath;
  final VoidCallback? onLeadingTap;
  final Color? titleColor;
  final double? titleFontSize;
  final Color? backgroundColor;
  final Color? bottomBorderColor;
  final double? paddingHorizontal;
  final double? paddingVertical;
  final double? leadingIconSize;
  final List<Widget>? actions;

  @override
  Size get preferredSize =>
      Size.fromHeight((((paddingVertical ?? 26.0) * 2) + 28.0) * 1.0);

  @override
  Widget build(BuildContext context) {
    final double resolvedPaddingH = paddingHorizontal ?? 32.0;
    final double resolvedPaddingV = paddingVertical ?? 26.0;
    final Color resolvedBgColor = backgroundColor ?? appTheme.transparentCustom;
    final Color resolvedBorderColor = bottomBorderColor ?? appTheme.gray_50;
    final double resolvedIconSize = leadingIconSize ?? 24.0;

    return AppBar(
      backgroundColor: resolvedBgColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: preferredSize.height,
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: resolvedBorderColor),
      ),
      title: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: resolvedPaddingH,
          vertical: resolvedPaddingV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (leadingImagePath != null)
              GestureDetector(
                onTap: onLeadingTap,
                child: Image.asset(
                  leadingImagePath!,
                  height: resolvedIconSize,
                  width: resolvedIconSize,
                  fit: BoxFit.contain,
                ),
              ),
            if (title != null)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: leadingImagePath != null ? 16 : 0,
                  ),
                  child: Text(
                    title!,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Inter').copyWith(height: 1.2),
                  ),
                ),
              ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}
