import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Base
class BaseBudgetDialog extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final Widget? summaryCard;
  final String? warningText;
  final Widget? contentCard;
  final Widget actions;

  const BaseBudgetDialog({
    super.key,
    required this.title,
    this.titleColor,
    this.summaryCard,
    this.warningText,
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
                  color: titleColor ?? appTheme.warningPopupHeader,
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

Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
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
  required String primaryValue,
  String? secondaryLabel,
  String? secondaryValue,
  String? thirdLabel,
  String? thirdValue,
  Color? primaryValueColor,
  Color? thirdValueColor,
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
        Text(
          primaryValue,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryValueColor ?? appTheme.errorRed,
          ),
        ),

        if (secondaryLabel != null && secondaryValue != null) ...[
          const SizedBox(height: 12),
          Divider(color: appTheme.popupCreamStroke, height: 1),
          const SizedBox(height: 12),
          _buildSummaryRow(secondaryLabel, secondaryValue),
        ],

        if (thirdLabel != null && thirdValue != null) ...[
          const SizedBox(height: 12),
          _buildSummaryRow(thirdLabel, thirdValue, valueColor: thirdValueColor),
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

Widget _buildTwoActionButtons({
  required String primaryText,
  required VoidCallback? onPrimaryPressed,
  required String secondaryText,
  required VoidCallback? onSecondaryPressed,
}) {
  return Row(
    children: [
      Expanded(
        child: _buildActionButton(
          text: secondaryText,
          backgroundColor: appTheme.redButton,
          onPressed: onSecondaryPressed,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildActionButton(
          text: primaryText,
          onPressed: onPrimaryPressed,
        ),
      ),
    ],
  );
}

Widget _buildTopUpCard(TextEditingController controller) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: appTheme.grey200),
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
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              borderSide: BorderSide(color: appTheme.teal_A700, width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

// Budget Exceeded - within threshold
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
    builder: (dialogContext) {
      return BaseBudgetDialog(
        title: 'Budget Exceeded',

        summaryCard: _buildSummaryCard(
          primaryLabel: 'Allocated Budget:',
          primaryValue: allocatedBudget,
          secondaryLabel: 'Remaining Budget:',
          secondaryValue: remainingBudget,
          thirdLabel: 'Exceeded Amount',
          thirdValue: exceededAmount,
          thirdValueColor: appTheme.errorRed,
        ),

        warningText: warningText1,

        contentCard: BaseBudgetDialog._buildWarningRow(warningText2),

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
    builder: (dialogContext) {
      return BaseBudgetDialog(
        title: 'Budget Exceeded',

        summaryCard: _buildSummaryCard(
          primaryLabel: 'Allocated Budget:',
          primaryValue: allocatedBudget,
          secondaryLabel: 'Remaining Budget:',
          secondaryValue: remainingBudget,
          thirdLabel: 'Exceeded Amount',
          thirdValue: exceededAmount,
          thirdValueColor: appTheme.warningPopupHeader,
        ),

        warningText: warningText1,

        contentCard: Column(
          children: [
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
                              'Based on your current spending rate, '
                              'your remaining budget is estimated to last ',
                        ),
                        TextSpan(
                          text: '$estimatedDays more day(s)',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            BaseBudgetDialog._buildWarningRow(warningText3),
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

// Budget Recovery
Future<void> showBudgetRecoveryDialog({
  required BuildContext context,
  required String shortageAmount,
  required String minTopUp,
  required String remainingBudget,
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
                    Navigator.of(dialogContext).pop();
                    onEndTrip?.call();
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final amount = double.tryParse(value.text.trim());
                    final min = double.tryParse(minTopUp.trim()) ?? 0.00;

                    final isValid = amount != null && amount > min;

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

// Cancel Top-up Initial Total Budget (Wishlist Covered > 0)
Future<void> showCancelTopUpDialog({
  required BuildContext context,
  VoidCallback? onContinue,
}) {
  return _showSimpleBudgetDialog(
    context: context,
    title: 'Cancel Top-up',
    messages: const [
      'Your wishlist item could not be fully covered based on '
          'the limited budget. The system will proceed with '
          'removing those wishlist items.',
    ],
    onContinue: onContinue,
  );
}

// Cancel Top-up Initial Total Budget (Wishlist Covered == 0)
Future<void> showCancelTripDialog({
  required BuildContext context,
  VoidCallback? onContinue,
}) {
  return _showSimpleBudgetDialog(
    context: context,
    title: 'Cancel Top-up',
    messages: const [
      'Your budget is insufficient to fully cover at least one wishlist item. The system will proceed with cancelling this trip.',
    ],
    onContinue: onContinue,
  );
}

// Cancel Top-up Initial Total Budget (Wishlist is Empty)
Future<void> showCancelTripWithoutWishlistDialog({
  required BuildContext context,
  VoidCallback? onContinue,
}) {
  return _showSimpleBudgetDialog(
    context: context,
    title: 'Cancel Top-up',
    messages: const [
      'Your budget is insufficient. The system will proceed with cancelling this trip.',
    ],
    onContinue: onContinue,
  );
}

// Initial Total Budget Insufficient (Limited Wishlist Coverage)
Future<void> showInitialTotalBudgetInsufficientDialog({
  required BuildContext context,
  required String shortageAmount,
  required double minTopUp,
  required int wishlistCovered,
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

        summaryCard: _buildSummaryCard(
          primaryLabel: 'Estimated Budget Shortage Amount',
          primaryValue: shortageAmount,
          secondaryLabel: 'Wishlist Covered',
          secondaryValue: wishlistCovered.toString(),
        ),

        // First warning
        warningText:
            'Your budget is not sufficient to cover all wishlist items. '
            'Do you want to add more budget?',

        // Top-up field + second warning
        contentCard: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopUpCard(controller),

            const SizedBox(height: 16),

            BaseBudgetDialog._buildWarningRow(
              'Top-up amount should at least ${minTopUp.toStringAsFixed(2)}, insufficient top-up amount will trigger alternative '
              'recommendation directly.',
            ),
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

// Initial Total Budget Insufficient (Zero Wishlist Coverage)
Future<void> showInitialTotalBudgetTotallyInsufficientDialog({
  required BuildContext context,
  required String shortageAmount,
  required double minTopUp,
  required int wishlistCovered,
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

        summaryCard: _buildSummaryCard(
          primaryLabel: 'Estimated Budget Shortage Amount',
          primaryValue: shortageAmount,
          secondaryLabel: 'Wishlist Covered',
          secondaryValue: wishlistCovered.toString(),
        ),

        // First warning
        warningText:
            'Your budget is not sufficient to cover any wishlist items. '
            'Do you want to add more budget?',

        // Top-up field + second warning
        contentCard: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopUpCard(controller),

            const SizedBox(height: 16),

            BaseBudgetDialog._buildWarningRow(
              'Top-up amount should be at least ${minTopUp.toStringAsFixed(2)}, insufficient top-up amount will trigger alternative '
              'recommendation directly.',
            ),
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

// Initial Total Budget Insufficient (Wishlist is Empty)
Future<void> showEmptyWishlistInsufficientTotalBudgetDialog({
  required BuildContext context,
  required String shortageAmount,
  required double minTopUp,
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

        summaryCard: _buildSummaryCard(
          primaryLabel: 'Estimated Budget Shortage Amount',
          primaryValue: shortageAmount,
        ),

        // First warning
        warningText:
        'Your budget is not sufficient for the trip. '
            'Do you want to add more budget?',

        // Top-up field + second warning
        contentCard: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopUpCard(controller),

            const SizedBox(height: 16),

            BaseBudgetDialog._buildWarningRow(
              'Top-up amount should be at least ${minTopUp.toStringAsFixed(2)}, insufficient top-up amount will trigger alternative '
                  'recommendation directly.',
            ),
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
// Initial Total Budget Top-up Insufficient
Future<void> showInsufficientTopUpTotalBudgetDialog({
  required BuildContext context,
  VoidCallback? onContinue,
}) {
  return _showSimpleBudgetDialog(
    context: context,
    title: 'Insufficient Top-up',
    messages: const [
      'Your top-up amount is still not sufficient to cover '
          'all wishlist items. The system will adjust the plan '
          'based on the latest amount.',
    ],
    onContinue: onContinue,
  );
}

// Initial Total Budget Top-up Insufficient
Future<void> showInsufficientTopUpTotalBudgetWithoutWishlistDialog({
  required BuildContext context,
  VoidCallback? onContinue,
}) {
  return _showSimpleBudgetDialog(
    context: context,
    title: 'Insufficient Top-up',
    messages: const [
      'Your top-up amount is still not sufficient to cover '
          'all the planned activities. The system will adjust the plan '
          'based on the latest amount.',
    ],
    onContinue: onContinue,
  );
}

Future<void> _showSimpleBudgetDialog({
  required BuildContext context,
  required String title,
  required List<String> messages,
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
              BaseBudgetDialog._buildWarningRow(messages[i]),
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
