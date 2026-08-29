import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BaseBudgetDialog extends StatelessWidget {
  final String title;
  final Widget summaryCard;
  final String warningText;
  final Widget? contentCard;
  final Widget actions;

  const BaseBudgetDialog({
    super.key,
    required this.title,
    required this.summaryCard,
    required this.warningText,
    this.contentCard,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: appTheme.warningPopupHeader,
                ),
              ),
              const SizedBox(height: 16),

              // Summary Section
              summaryCard,
              const SizedBox(height: 16),

              // Warning Message
              _buildWarningRow(warningText),
              const SizedBox(height: 16),

              // Optional Content Widget (Item details card or Top-Up input)
              if (contentCard != null) ...[
                contentCard!,
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),

              // Action Buttons
              actions,
            ],
          ),
        ),
      ),
    );
  }

  // Shared Warning Row Builder
  static Widget _buildWarningRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: appTheme.popupWarningMsg,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: appTheme.popupWarningMsg,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // Shared Tag Chip Builder
  static Widget buildTagChip({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// Budget Exceeded Within 20% Popup
Future<void> showBudgetExceededDialog({
  required BuildContext context,
  required String allocatedBudget,
  required String remainingBudget,
  required String exceededAmount,
  required String warningText1,
  required String warningText2,
  VoidCallback? onContinue,
}) {
  return showDialog(
    context: context,
    builder: (context) {
      return BaseBudgetDialog(
        title: 'Budget Exceeded',
        summaryCard: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appTheme.popupCreamBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appTheme.popupCreamStroke),
          ),
          child: Column(
            children: [
              _buildSummaryRow('Allocated Budget:', allocatedBudget),
              const SizedBox(height: 12),
              _buildSummaryRow('Remaining Budget:', remainingBudget),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Exceeded Amount',
                exceededAmount,
                valueColor: appTheme.warningPopupHeader,
              ),
            ],
          ),
        ),
        warningText: warningText1,
        contentCard: Column(
          children: [
            // Center(
            //   child: Container(
            //     decoration: BoxDecoration(
            //       color: appTheme.white_A700,
            //       borderRadius: BorderRadius.circular(12),
            //       border: Border.all(color: appTheme.blue_gray_50),
            //       boxShadow: [
            //         BoxShadow(
            //           color: appTheme.black.withAlpha(10),
            //           offset: const Offset(0, 2),
            //           blurRadius: 10,
            //         ),
            //       ],
            //     ),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         ClipRRect(
            //           borderRadius: const BorderRadius.vertical(
            //             top: Radius.circular(12),
            //           ),
            //           child: Image.network(
            //             imageUrl,
            //             height: 160,
            //             width: double.infinity,
            //             fit: BoxFit.cover,
            //             errorBuilder: (_, __, ___) => Container(
            //               height: 160,
            //               color: Colors.grey.shade300,
            //               child: const Icon(Icons.restaurant, size: 48),
            //             ),
            //           ),
            //         ),
            //         Padding(
            //           padding: const EdgeInsets.all(12.0),
            //           child: Column(
            //             crossAxisAlignment: CrossAxisAlignment.start,
            //             children: [
            //               Text(
            //                 itemTitle,
            //                 style: TextStyle(
            //                   fontSize: 18,
            //                   fontWeight: FontWeight.bold,
            //                   color: appTheme.black,
            //                 ),
            //               ),
            //               const SizedBox(height: 10),
            //               BaseBudgetDialog.buildTagChip(
            //                 label: originalBudgetChipText,
            //                 bgColor: appTheme.lime_900,
            //                 textColor: appTheme.amber_200,
            //               ),
            //               const SizedBox(height: 6),
            //               BaseBudgetDialog.buildTagChip(
            //                 label: modifiedBudgetChipText,
            //                 bgColor: appTheme.expenseOverspendBg,
            //                 textColor: appTheme.expenseOverspendText,
            //               ),
            //             ],
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 16),
            BaseBudgetDialog._buildWarningRow(warningText2),
          ],
        ),
        actions: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.teal_A700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                color: appTheme.white_A700,
              ),
            ),
          ),
        ),
      );
    },
  );
}

// Budget Exceeded Above 20% Popup
Future<void> showBudgetExceeded20Dialog({
  required BuildContext context,
  required String allocatedBudget,
  required String remainingBudget,
  required String exceededAmount,
  required String warningText1,
  required String estimatedDays,
  required String warningText3,
  VoidCallback? onContinue,
}) {
  return showDialog(
    context: context,
    builder: (context) {
      return BaseBudgetDialog(
        title: 'Budget Exceeded',
        summaryCard: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appTheme.popupCreamBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appTheme.popupCreamStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Allocated Budget:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.warningPopupHeader,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                allocatedBudget,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appTheme.black,
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: appTheme.popupCreamStroke, height: 1),
              const SizedBox(height: 12),
              _buildSummaryRow('Remaining Budget:', remainingBudget),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Exceeded Amount',
                exceededAmount,
                valueColor: appTheme.warningPopupHeader,
              ),
            ],
          ),
        ),
        warningText: warningText1,
        contentCard: Column(
          children: [
            // Second Warning Message with bold days text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: appTheme.popupWarningMsg,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: appTheme.popupWarningMsg,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'Based on your current spending rate, your remaining budget is estimated to last ',
                        ),
                        TextSpan(
                          text: '$estimatedDays more day(s)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Third Warning Message
            BaseBudgetDialog._buildWarningRow(warningText3),
          ],
        ),
        actions: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.teal_700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (onContinue != null) {
                onContinue();
              }
            },
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                color: appTheme.white_A700,
              ),
            ),
          ),
        ),
      );
    },
  );
}

// Budget Recovery Popup
Future<void> showBudgetRecoveryDialog({
  required BuildContext context,
  required String shortageAmount,
  required String remainingBudget,
  required String warningText,
  VoidCallback? onEndTrip,
  required Future<bool> Function(double amount) onTopUpBudget,
}) {
  final TextEditingController topUpController = TextEditingController();

  return showDialog(
    context: context,
    builder: (context) {
      return BaseBudgetDialog(
        title: 'Budget Recovery',
        summaryCard: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appTheme.popupCreamBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appTheme.popupCreamStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget Shortage Amount:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.popupBrownBudget,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                shortageAmount,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appTheme.black,
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: appTheme.popupCreamStroke, height: 1),
              const SizedBox(height: 12),
              _buildSummaryRow('Remaining Budget:', remainingBudget),
            ],
          ),
        ),
        warningText: warningText,
        contentCard: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: appTheme.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOP-UP AMOUNT',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: appTheme.blue_gray_300,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: topUpController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: appTheme.black,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.grey,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: appTheme.white_A700,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: appTheme.blue_gray_300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: appTheme.teal_A700,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.redButton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onEndTrip != null) {
                      onEndTrip();
                    }
                  },
                  child: Text(
                    'End Trip',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: appTheme.white_A700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.teal_A700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final amountText = topUpController.text.trim();
                    final amount = double.tryParse(amountText);

                    if (amount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid top-up amount.'),
                        ),
                      );
                      return;
                    }

                    final success = await onTopUpBudget(amount);

                    if (success && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    'Top-up Budget',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: appTheme.white_A700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showInitialTotalBudgetInsufficient({
  required BuildContext context,
  required String shortageAmount,
  required String warningText,
  VoidCallback? onCancel,
  required Future<bool> Function(double amount) onTopUpBudget,
}) {
  final TextEditingController topUpController = TextEditingController();

  return showDialog(
    context: context,
    builder: (context) {
      return BaseBudgetDialog(
        title: 'Budget Recovery',
        summaryCard: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appTheme.popupCreamBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appTheme.popupCreamStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget Shortage Amount:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.popupBrownBudget,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                shortageAmount,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appTheme.black,
                ),
              ),
            ],
          ),
        ),
        warningText: warningText,
        contentCard: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: appTheme.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOP-UP AMOUNT',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: appTheme.blue_gray_300,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: topUpController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: appTheme.black,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.grey,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: appTheme.white_A700,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: appTheme.blue_gray_300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: appTheme.teal_A700,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.redButton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onCancel != null) {
                      onCancel();
                    }
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: appTheme.white_A700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.teal_A700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final amountText = topUpController.text.trim();
                    final amount = double.tryParse(amountText);

                    if (amount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid top-up amount.'),
                        ),
                      );
                      return;
                    }

                    final success = await onTopUpBudget(amount);

                    if (success && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    'Top-up Budget',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: appTheme.white_A700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: appTheme.popupBrownBudget,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: valueColor ?? appTheme.black,
        ),
      ),
    ],
  );
}
