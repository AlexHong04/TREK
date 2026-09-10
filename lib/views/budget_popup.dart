import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/dual_currency_amount.dart';

// Base
class BaseBudgetDialog extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final Widget? summaryCard;
  final String? warningText;
  final Color? warningTextColor;
  final Widget? contentCard;
  final Widget actions;

  const BaseBudgetDialog({
    super.key,
    required this.title,
    this.titleColor,
    this.summaryCard,
    this.warningText,
    this.warningTextColor,
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: appTheme.black,
                ),
              ),

              if (summaryCard != null) ...[
                const SizedBox(height: 16),
                summaryCard!,
              ],

              if (warningText != null && warningText!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildWarningRow(warningText!),
              ],

              if (warningTextColor != null &&
                  warningTextColor != appTheme.popupWarningMsg) ...[
                const SizedBox(height: 16),
                _buildWarningRow(warningText!, color: warningTextColor),
              ],

              if (contentCard != null) ...[
                const SizedBox(height: 16),
                contentCard!,
              ],

              const SizedBox(height: 24),

              actions,
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildWarningRow(String text, {Color? color}) {
    final effectiveColor = color ?? appTheme.popupWarningMsg;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: effectiveColor, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: effectiveColor,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

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

Widget _buildSummaryRow(String label, double value, {Color? valueColor}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appTheme.popupBrownBudget,
          ),
        ),
      ),
      const SizedBox(width: 12),
      DualCurrencyAmount(
        amount: value,
        baseCurrency: 'MYR',
        baseLabel: 'RM',
        primaryStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
          color: valueColor ?? appTheme.black,
        ),
        secondaryStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: appTheme.blue_gray_700,
        ),
        crossAxisAlignment: CrossAxisAlignment.start,
        textAlign: TextAlign.start,
      ),
    ],
  );
}

Widget _buildIntSummaryRow(String label, String value, {Color? valueColor}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appTheme.popupBrownBudget,
          ),
        ),
      ),
      const SizedBox(width: 12),
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

Widget _buildSummaryCard({
  required String primaryLabel,
  required double primaryValue,
  String? secondaryLabel,
  double? secondaryValue,
  String? thirdLabel,
  double? thirdValue,
  String? fourthLabel,
  double? fourthValue,
  String? fifthLabel,
  String? fifthValue,
  Color? primaryValueColor,
}) {
  return Container(
    width: double.infinity,
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
          primaryLabel,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appTheme.popupBrownBudget,
          ),
        ),
        const SizedBox(height: 8),
        DualCurrencyAmount(
          amount: primaryValue,
          baseCurrency: 'MYR',
          baseLabel: 'RM',
          primaryStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            color: primaryValueColor ?? appTheme.errorRed,
          ),
          secondaryStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            color: appTheme.blue_gray_700,
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
          textAlign: TextAlign.start,
        ),

        if (secondaryLabel != null && secondaryValue != null) ...[
          const SizedBox(height: 12),
          Divider(color: appTheme.popupCreamStroke, height: 1),
          const SizedBox(height: 12),
          _buildSummaryRow(secondaryLabel, secondaryValue),
        ],

        if (thirdLabel != null && thirdValue != null) ...[
          const SizedBox(height: 12),
          _buildSummaryRow(thirdLabel, thirdValue),
        ],

        if (fourthLabel != null && fourthValue != null) ...[
          const SizedBox(height: 12),
          _buildSummaryRow(fourthLabel, fourthValue),
        ],

        if (fifthLabel != null && fifthValue != null) ...[
          const SizedBox(height: 12),
          _buildIntSummaryRow(fifthLabel, fifthValue),
        ],
      ],
    ),
  );
}

Widget _buildWishlistSummaryCard({
  required String primaryLabel,
  required double primaryValue,
  String? secondaryLabel,
  double? secondaryValue,
  String? thirdLabel,
  String? thirdValue,
  Color? primaryValueColor,
}) {
  return Container(
    width: double.infinity,
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
          primaryLabel,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appTheme.popupBrownBudget,
          ),
        ),
        const SizedBox(height: 8),
        // Text(
        //   primaryValue,
        //   style: TextStyle(
        //     fontFamily: 'Inter',
        //     fontSize: 24,
        //     fontWeight: FontWeight.bold,
        //     color: primaryValueColor ?? appTheme.errorRed,
        //   ),
        // ),
        DualCurrencyAmount(
          amount: primaryValue,
          baseCurrency: 'MYR',
          baseLabel: 'RM',
          primaryStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            color: primaryValueColor ?? appTheme.errorRed,
          ),
          secondaryStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            color: appTheme.blue_gray_700,
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
          textAlign: TextAlign.start,
        ),

        if (secondaryLabel != null && secondaryValue != null) ...[
          const SizedBox(height: 12),
          Divider(color: appTheme.popupCreamStroke, height: 1),
          const SizedBox(height: 12),
          _buildSummaryRow(secondaryLabel, secondaryValue),
        ],

        if (thirdLabel != null && thirdValue != null) ...[
          const SizedBox(height: 12),
          _buildIntSummaryRow(thirdLabel, thirdValue),
        ],
      ],
    ),
  );
}

Widget _buildActionButton({
  required String text,
  required VoidCallback? onPressed,
  Color? backgroundColor,
}) {
  return SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? appTheme.teal_A700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: appTheme.white_A700,
        ),
      ),
    ),
  );
}

Widget _buildTopUpCard(
    TextEditingController controller,
    ) {
  return ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, child) {
      final enteredAmount = double.tryParse(
        value.text.trim(),
      );

      return CustomTextField(
        sectionTitle: 'TOP-UP AMOUNT (MYR)',
        hintText: 'Enter Top-Up Amount (MYR)',
        prefixIcon: Icons.account_balance_wallet_outlined,
        prefixIconColor: appTheme.teal_A700,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
        ),
        margin: EdgeInsets.zero,
        bottomWidget:
        (enteredAmount != null && enteredAmount > 0)
            ? Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14.0,
            vertical: 10.0,
          ),
          decoration: BoxDecoration(
            color: appTheme.teal_50.withValues(
              alpha: 0.45,
            ),
            borderRadius: BorderRadius.circular(
              12.0,
            ),
            border: Border.all(
              color: appTheme.teal_A700.withValues(
                alpha: 0.2,
              ),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.currency_exchange_rounded,
                    size: 16,
                    color: appTheme.teal_700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Equivalent Value:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color:
                      appTheme.blue_gray_700,
                    ),
                  ),
                ],
              ),

              DualCurrencyAmount(
                amount: enteredAmount,
                baseCurrency: 'MYR',
                baseLabel: 'RM',
                primaryStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.teal_800,
                ),
                secondaryStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color:
                  appTheme.blue_gray_700,
                ),
                crossAxisAlignment:
                CrossAxisAlignment.end,
                textAlign: TextAlign.end,
              ),
            ],
          ),
        )
            : null,
      );
    },
  );
}

// Budget Exceeded - within threshold
Future<void> showBudgetExceededDialog({
  required BuildContext context,
  required double allocatedBudget,
  required double remainingBudget,
  required double exceededAmount,
  required double totalOverspent,
  required String warningText1,
  VoidCallback? onContinue,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BaseBudgetDialog(
        title: 'Budget Exceeded',
        summaryCard: _buildSummaryCard(
          primaryLabel: 'Exceeded Amount',
          primaryValue: exceededAmount,
          primaryValueColor: appTheme.errorRed,
          secondaryLabel: 'Remaining Budget:',
          secondaryValue: remainingBudget,
          thirdLabel: 'Allocated Budget:',
          thirdValue: allocatedBudget,
          fourthLabel: 'Total Overspent So Far:',
          fourthValue: totalOverspent,
        ),

        warningText: warningText1,

        actions: _buildActionButton(
          text: 'Continue',
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onContinue?.call();
          },
        ),
      );
    },
  );
}

// Budget Exceeded - above threshold
Future<void> showBudgetExceededThresholdDialog({
  required BuildContext context,
  required double allocatedBudget,
  required double remainingBudget,
  required double exceededAmount,
  required double totalOverspent,
  required String estimatedDays,
  required String warningText1,
  VoidCallback? onContinue,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BaseBudgetDialog(
        title: 'Budget Exceeded',

        summaryCard: _buildSummaryCard(
          primaryLabel: 'Exceeded Amount',
          primaryValue: exceededAmount,
          primaryValueColor: appTheme.errorRed,
          secondaryLabel: 'Remaining Budget:',
          secondaryValue: remainingBudget,
          thirdLabel: 'Allocated Budget:',
          thirdValue: allocatedBudget,
          fourthLabel: 'Total Overspent So Far:',
          fourthValue: totalOverspent,
          fifthLabel: 'Estimated Sufficient:',
          fifthValue: estimatedDays,
        ),

        warningText: warningText1,

        actions: _buildActionButton(
          text: 'Continue',
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onContinue?.call();
          },
        ),
      );
    },
  );
}

// Budget Recovery
Future<void> showBudgetRecoveryDialog({
  required BuildContext context,
  required double shortageAmount,
  required double minTopUp,
  required double remainingBudget,
  required String warningText,
  VoidCallback? onEndTrip,
  required Future<bool> Function(double amount) onTopUpBudget,
}) {
  final controller = TextEditingController();

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: BaseBudgetDialog(
          title: 'Budget Recovery',

          summaryCard: _buildSummaryCard(
            primaryLabel: 'Budget Shortage Amount:',
            primaryValue: shortageAmount,
            secondaryLabel: 'Remaining Budget:',
            secondaryValue: remainingBudget,
            thirdLabel: 'Minimum Top-up Amount:',
            thirdValue: minTopUp,
          ),

          warningText: warningText,

          contentCard: _buildTopUpCard(controller),

          actions: Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  text: 'End Trip',
                  backgroundColor: appTheme.redButton,
                  onPressed: () {
                    // First close Budget Recovery.
                    Navigator.of(dialogContext).pop();

                    // Then show End Trip confirmation.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      onEndTrip?.call();
                    });
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final amount = double.tryParse(value.text.trim());

                    final isValid = amount != null && amount >= minTopUp;

                    return _buildActionButton(
                      text: 'Top-up Budget',
                      onPressed: isValid
                          ? () async {
                              final amount = double.parse(value.text.trim());

                              final success = await onTopUpBudget(amount);

                              if (success && dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            }
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Budget Recovery Top-up Insufficient
Future<void> showInsufficientTopUpBudgetRecoveryDialog({
  required BuildContext context,
  required VoidCallback onContinue,
}) {
  return _showSimpleBudgetDialog(
    context: context,
    title: 'Insufficient Top-up',
    messages: const [
      'You did not top-up a sufficient amount.',
      'Failed to reallocate the budget to cover the '
          'overspent amount. The plan will be modified automatically.',
    ],
    onContinue: onContinue,
  );
}

// Show Budget Recovery End Trip Confirmation
Future<void> showEndTripConfirmationDialog({
  required BuildContext context,
  String? warningText,
  VoidCallback? onCancel,
  required Future<bool> Function() onEndTrip,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BaseBudgetDialog(
        title: 'End Trip',

        warningText: warningText ?? 'Are you sure you want to end this trip?',

        actions: Row(
          children: [
            Expanded(
              child: _buildActionButton(
                text: 'Cancel',
                backgroundColor: appTheme.redButton,
                onPressed: () {
                  // Close confirmation.
                  Navigator.of(dialogContext).pop();

                  // Reopen Budget Recovery after it closes.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onCancel?.call();
                  });
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildActionButton(
                text: 'End Trip',
                onPressed: () async {
                  await onEndTrip();
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Budget Reallocation Failure
Future<void> showBudgetReallocationFailureDialog({
  required BuildContext context,
  VoidCallback? onContinue,
}) {
  return _showSimpleBudgetDialog(
    context: context,
    title: 'Budget Reallocation Failure',
    messages: const [
      'Failed to reallocate the budget to cover the '
          'overspent amount. The plan will be modified automatically.',
    ],
    onContinue: onContinue,
  );
}

Future<void> showInitialBudgetInsufficientDialog({
  required BuildContext context,
  required double shortageAmount,
  required double minTopUp,
  int? wishlistCovered,
  required String warningText,
  VoidCallback? onCancel,
  required Future<bool> Function(double amount) onTopUpBudget,
}) {
  final controller = TextEditingController();

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BaseBudgetDialog(
        title: 'Budget Insufficient',

        summaryCard: wishlistCovered != null
            ? _buildWishlistSummaryCard(
                primaryLabel: 'Estimated Budget Shortage Amount',
                primaryValue: shortageAmount,
                secondaryLabel: 'Minimum Top Up Amount',
                secondaryValue: minTopUp,
                thirdLabel: 'Wishlist Covered',
                thirdValue: '${wishlistCovered.toString()} item(s)',
              )
            : _buildSummaryCard(
                primaryLabel: 'Estimated Budget Shortage Amount',
                primaryValue: shortageAmount,
                secondaryLabel: 'Minimum Top Up Amount',
                secondaryValue: minTopUp,
              ),

        warningText: warningText,

        contentCard: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopUpCard(controller),
          ],
        ),

        actions: Row(
          children: [
            Expanded(
              child: _buildActionButton(
                text: 'Cancel',
                backgroundColor: appTheme.redButton,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onCancel?.call();
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final amount = double.tryParse(value.text.trim());

                  final isValid = amount != null && amount >= minTopUp;

                  return _buildActionButton(
                    text: 'Top-up Budget',
                    onPressed: isValid
                        ? () async {
                            final amount = double.parse(value.text.trim());

                            final success = await onTopUpBudget(amount);

                            if (success && dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Cancel Top-up Initial Total Budget (Wishlist Covered > 0)
Future<void> showCancelTopUpDialog({
  required BuildContext context,
  VoidCallback? onCancel,
  VoidCallback? onConfirm,
}) {
  return _showTwoButtonsBudgetDialog(
    context: context,
    title: 'Cancel Top-up',
    messages: const [
      'Your wishlist item could not be fully covered based on '
          'the limited budget. The system will proceed with '
          'removing those wishlist items.',
    ],
    onCancel: onCancel,
    onConfirm: onConfirm,
  );
}

// Cancel Top-up Initial Total Budget (Wishlist Covered == 0)
Future<void> showCancelTripDialog({
  required BuildContext context,
  VoidCallback? onCancel,
  VoidCallback? onConfirm,
}) {
  return _showTwoButtonsBudgetDialog(
    context: context,
    title: 'Cancel Top-up',
    messages: const [
      'Your budget is insufficient to fully cover at least one wishlist item. The system will proceed with cancelling this trip.',
    ],
    onCancel: onCancel,
    onConfirm: onConfirm
  );
}

// Cancel Top-up Initial Total Budget (Wishlist is Empty)
Future<void> showCancelTripWithoutWishlistDialog({
  required BuildContext context,
  VoidCallback? onCancel,
  VoidCallback? onConfirm,
}) {
  return _showTwoButtonsBudgetDialog(
    context: context,
    title: 'Cancel Top-up',
    messages: const [
      'Your budget is insufficient. The system will proceed with cancelling this trip.',
    ],
      onCancel: onCancel,
      onConfirm: onConfirm
  );
}

// Initial Total Budget Top-up Insufficient
Future<void> showInsufficientTopUpTotalBudgetDialog({
  required BuildContext context,
  VoidCallback? onContinue,
}) {
  return _showSimpleBudgetDialog(
    context: context,
    title: 'Insufficient Top-up',
    messages: const [
      'Your top-up amount is still not sufficient,'
          'the system will adjust the plan based on'
          'the latest amount.',
    ],
    onContinue: onContinue,
  );
}

Future<void> _showSimpleBudgetDialog({
  required BuildContext context,
  required String title,
  required List<String> messages,
  Color? color,
  VoidCallback? onContinue,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BaseBudgetDialog(
        title: title,
        contentCard: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < messages.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              BaseBudgetDialog._buildWarningRow(messages[i], color: color),
            ],
          ],
        ),

        actions: _buildActionButton(
          text: 'Continue',
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onContinue?.call();
          },
        ),
      );
    },
  );
}

Future<void> _showTwoButtonsBudgetDialog({
  required BuildContext context,
  required String title,
  required List<String> messages,
  Color? color,
  VoidCallback? onCancel,
  VoidCallback? onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BaseBudgetDialog(
        title: title,

        contentCard: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < messages.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                BaseBudgetDialog._buildWarningRow(messages[i], color: color),
              ],
            ],
          ),
        ),

        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: _buildActionButton(
                text: 'Cancel',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onCancel?.call();
                },
                backgroundColor: appTheme.errorRed,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildActionButton(
                text: 'Confirm',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onConfirm?.call();
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showTopUpConfirmation({
  required BuildContext context,
  required double topUpAmount,
  required String symbol,
  required double convertedAmt,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
}) {
  return _showTwoButtonsBudgetDialog(
    context: context,
    title: 'Top-up Budget',
    messages: [
      'Are you sure you want to top-up MYR ${topUpAmount.toStringAsFixed(2)} ($symbol ${convertedAmt.toStringAsFixed(2)})?',
    ],
    color: appTheme.black,
    onCancel: onCancel,
    onConfirm: onConfirm
  );
}