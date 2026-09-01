import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: appTheme.gray_50_02,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      toolbarHeight: 68,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: appTheme.teal_A700),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          fontSize: 20,
          color: appTheme.teal_A700,
          height: 1.2,
        ),
      ),
      // Balances the 48px width of the leading IconButton to keep title centered
      actions: const [
        SizedBox(width: 48),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: appTheme.gray_50),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(69); // 68 toolbar + 1 border
}

void showThreeSecondMessage(
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