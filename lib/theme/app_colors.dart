import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color tealA700 = Color(0xFF14BBA6);
  static const Color teal800 = Color(0xFF006B5E);
  static const Color teal800_01 = Color(0xFF006A63);
  static const Color teal700 = Color(0xFF007164);
  static const Color tealA200 = Color(0xFF6EF9E2);
  static const Color teal50 = Color(0xFFCCFBF1);

  // Gray Scale
  static const Color gray900 = Color(0xFF191C1E);
  static const Color gray800 = Color(0xFF3C4946);
  static const Color gray400 = Color(0xFFBBCAC5);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray50_01 = Color(0xFFF0FDFA);
  static const Color gray50_02 = Color(0xFFF8FAFC);
  static const Color gray50_03 = Color(0xFFF7F9FB);

  // Blue Gray
  static const Color blueGray900 = Color(0xFF1F2937);
  static const Color blueGray800 = Color(0xFF374151);
  static const Color blueGray700 = Color(0xFF4B5563);
  static const Color blueGray300 = Color(0xFF9CA3AF);
  static const Color blueGray50 = Color(0xFFECEEF0);

  // Accent Colors
  // Overspend Tag
  static const Color overspendTag = Color(0xFFFF0000);

  // Activity Budget Usage
  static const Color amber200 = Color(
    0xFFFFF0BE,
  ); // Budget Tag Background in Activity
  static const Color lime900 = Color(0xFFD58000); // Budget Tag Text in Activity

  // Itinerary Day Header Budget Tag - Alert
  static const Color budgetAlertBg = Color(0xFFFEE2E2);
  static const Color budgetAlertStroke = Color(0xFFFECACA);
  static const Color budgetAlertText = Color(0xFF991B1B);
  static const Color errorRed = Color(0xFFEF4444); // Usage Progress Bar Alert

  // Itinerary Day Header Budget Tag - Good
  static const Color greenProgress = Color(
    0xFF35C460,
  ); // Usage Progress Bar Good
  static const Color goodPercentageBg = Color(0xFFECFDF5);
  static const Color goodPercentageStroke = Color(0xFFA7F3D0);
  static const Color goodPercentageText = Color(0xFF047857);

  // Itinerary Day Header Budget Tag - Medium
  static const Color orangeProgress = Color(
    0xFFFDE68A,
  ); // Usage Progress Bar Normal
  static const Color normalPercentageBg = Color(0xFFFFEFD4);
  static const Color normalPercentageStroke = Color(0xFFFFE0AB);
  static const Color normalPercentageText = Color(0xFFDC8C03);

  // Activity Expense Usage
  static const Color expenseOverspendBg = Color(0xFFFFC6BD);
  static const Color expenseOverspendText = Color(0xFFD50000);
  static const Color expenseBg = Color(0xFFBEE2FF);
  static const Color expenseText = Color(0xFF0074D3);

  // Budget Popup Usage
  static const Color redButton = Color(0xFFE23C3C);
  static const Color warningPopupHeader = Color(0xFFF59E0B);
  static const Color popupBrownBudget = Color(0xFF92400E);
  static const Color popupCreamStroke = Color(0xFFFED7AA);
  static const Color popupCreamBg = Color(0xFFFFF7ED);
  static const Color popupWarningMsg = Color(0xFFFF645C);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color black900_0c = Color(0x0C000000);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;
}
