import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      visualDensity: VisualDensity.standard,

      colorScheme: const ColorScheme.light(
        primary: AppColors.tealA700,
        onPrimary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.blueGray900,
      ),
    );
  }
}

class AppThemeData {
  final Color transparentCustom = AppColors.transparent;

  final Color gray_50_01 = AppColors.gray50_01;
  final Color gray_50_02 = AppColors.gray50_02;
  final Color gray_50_03 = AppColors.gray50_03;

  final Color teal_A700 = AppColors.tealA700;
  final Color teal_800 = AppColors.teal800;
  final Color teal_50 = AppColors.teal50;
  final Color teal_A200 = AppColors.tealA200;
  final Color teal_700 = AppColors.teal700;

  final Color white_A700 = AppColors.white;

  final Color blue_gray_50 = AppColors.blueGray50;
  final Color blue_gray_300 = AppColors.blueGray300;
  final Color blue_gray_700 = AppColors.blueGray700;

  final Color gray_50 = AppColors.gray50;
  final Color gray_100 = AppColors.gray100;
  final Color gray_200 = AppColors.gray200;
  final Color gray_400 = AppColors.gray400;
  final Color gray_800 = AppColors.gray800;
  final Color gray_900 = AppColors.gray900;

  final Color blueGray900 = AppColors.blueGray900;
  final Color errorRed = AppColors.errorRed;

  final Color colorFFEF44 = AppColors.errorRed;

  final Color black_900_0c = AppColors.black900_0c;
  final Color black = AppColors.black;

  final Color grey200 = AppColors.gray200;
  final Color grey100 = AppColors.gray100;

  // Activity Budget Usage
  final Color amber_200 = AppColors.amber200;
  final Color lime_900 = AppColors.lime900;

  // Itinerary Day Header Budget Tag - Alert
  final Color wholeAlertBudgetBg = AppColors.budgetAlertBg;
  final Color wholeAlertBudgetStroke = AppColors.budgetAlertStroke;
  final Color wholeAlertBudgetText = AppColors.budgetAlertText;
  final Color wholeRedBudgetProgress = AppColors.errorRed;

  // Itinerary Day Header Budget Tag - Good
  final Color wholeGoodBudgetProgress = AppColors.greenProgress;
  final Color wholeGoodBudgetStroke = AppColors.goodPercentageStroke;
  final Color wholeGoodBudgetText = AppColors.goodPercentageText;
  final Color wholeGoodBudgetBg = AppColors.goodPercentageBg;

  // Itinerary Day Header Budget Tag - Medium
  final Color wholeBudgetProgress = AppColors.orangeProgress;
  final Color wholeBudgetStroke = AppColors.normalPercentageStroke;
  final Color wholeBudgetText = AppColors.normalPercentageText;
  final Color wholeBudgetBg = AppColors.normalPercentageBg;

  // Overspend Tag
  final Color overspendTag = AppColors.overspendTag;

  // Activity Expense Usage
  final Color expenseOverspendBg = AppColors.expenseOverspendBg;
  final Color expenseOverspendText = AppColors.expenseOverspendText;
  static Color expenseBg = AppColors.expenseBg;
  static Color expenseText = AppColors.expenseText;

  // Budget Popup Usage
  final Color redButton = AppColors.redButton;
  final Color warningPopupHeader = AppColors.warningPopupHeader;
  final Color popupBrownBudget = AppColors.popupBrownBudget;
  final Color popupCreamStroke = AppColors.popupCreamStroke;
  final Color popupCreamBg = AppColors.popupCreamBg;
  final Color popupWarningMsg = AppColors.popupWarningMsg;
}

final appTheme = AppThemeData();

final theme = AppTheme.lightTheme;
