import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/services/i_auth_service.dart';
import '../theme/app_theme.dart';
import '../view_models/presentation_logic/trip_summary_view_model.dart';
import 'budget_popup.dart';

class TripSummaryScreen extends StatelessWidget {
  final String tripId;

  const TripSummaryScreen({super.key, required this.tripId});

  static Widget builder(BuildContext context, {required String tripId}) {
    return ChangeNotifierProvider<TripSummaryViewModel>(
      create: (providerContext) => TripSummaryViewModel(
        tripId: tripId,
        authService: providerContext.read<IAuthService>(),
      )..loadTripSummary(),
      child: TripSummaryScreen(tripId: tripId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TripSummaryViewModel>();
    final uiState = viewModel.uiState;

    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      appBar: AppBar(
        backgroundColor: appTheme.white_A700,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: appTheme.teal_800),
        ),
        title: Text(
          'Dashboard',
          style: TextStyle(
            color: appTheme.teal_A700,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(context, viewModel, uiState),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TripSummaryViewModel viewModel,
    TripSummaryUiState uiState,
  ) {
    if (uiState.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: appTheme.teal_A700),
      );
    }

    if (uiState.errorMessage != null || !uiState.hasTrip) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: appTheme.gray_400,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                uiState.errorMessage ?? 'This trip could not be found.',
                textAlign: TextAlign.center,
                style: TextStyle(color: appTheme.gray_800, fontSize: 14),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: viewModel.loadTripSummary,
                style: FilledButton.styleFrom(
                  backgroundColor: appTheme.teal_A700,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: appTheme.teal_A700,
      onRefresh: viewModel.loadTripSummary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiState.destination,
              style: TextStyle(
                color: appTheme.gray_900,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateRange(uiState.startDate!, uiState.endDate!),
              style: TextStyle(color: appTheme.gray_400, fontSize: 14),
            ),
            if (uiState.preferredCurrency != 'MYR') ...[
              const SizedBox(height: 14),
              _TripCurrencyViewBadge(
                preferredCurrency: uiState.preferredCurrency,
              ),
            ],
            const SizedBox(height: 28),
            _buildBudgetOverview(uiState),
            if (uiState.isConvertingCurrency ||
                uiState.currencyConversionErrorMessage != null) ...[
              const SizedBox(height: 10),
              _CurrencyConversionStatus(
                isLoading: uiState.isConvertingCurrency,
                preferredCurrency: uiState.preferredCurrency,
                errorMessage: uiState.currencyConversionErrorMessage,
                onRetry: viewModel.retryCurrencyConversion,
              ),
            ],
            const SizedBox(height: 26),
            _buildFinancialHealth(uiState),
            const SizedBox(height: 18),
            _buildSpendingBreakdown(viewModel, uiState),
            const SizedBox(height: 22),
            _buildCostSavingTips(viewModel, uiState),
            const SizedBox(height: 18),
            _buildFutureBudgetRecommendations(context, viewModel, uiState),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetOverview(TripSummaryUiState uiState) {
    final isOverspent = uiState.remainingBudget < 0;
    final isUnhealthy = uiState.financialHealth == 'Unhealthy';
    final expenseColor = isOverspent
        ? appTheme.errorRed
        : isUnhealthy
        ? appTheme.warningPopupHeader
        : appTheme.teal_800;

    return LayoutBuilder(
      builder: (context, constraints) {
        final budgetRings = SizedBox(
          width: 168,
          child: Column(
            children: [
              SizedBox(
                width: 152,
                height: 152,
                child: CustomPaint(
                  painter: HealthDonutPainter(
                    showActualBudget: isUnhealthy,
                    actualBudgetProgress: uiState.actualBudgetRingProgress,
                    allocatedBudgetProgress:
                        uiState.allocatedBudgetRingProgress,
                    expenseProgress: uiState.expenseRingProgress,
                    actualBudgetColor: appTheme.teal_A700,
                    allocatedBudgetColor: appTheme.blue_gray_300,
                    expenseColor: expenseColor,
                    backgroundColor: appTheme.gray_200,
                  ),
                  child: Center(
                    child: Text(
                      '${uiState.spentPercentage.round()}%',
                      style: TextStyle(
                        color: expenseColor,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (isUnhealthy) ...[
                _BudgetRingLegend(color: appTheme.teal_A700, label: 'Actual'),
                const SizedBox(height: 6),
              ],
              _BudgetRingLegend(
                color: appTheme.blue_gray_300,
                label: 'Allocated',
              ),
              const SizedBox(height: 6),
              _BudgetRingLegend(color: expenseColor, label: 'Expense'),
            ],
          ),
        );
        final metrics = _BudgetMetricsCard(uiState: uiState);

        if (constraints.maxWidth < 430) {
          return Column(
            children: [budgetRings, const SizedBox(height: 20), metrics],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            budgetRings,
            const SizedBox(width: 18),
            Expanded(child: metrics),
          ],
        );
      },
    );
  }

  Widget _buildFinancialHealth(TripSummaryUiState uiState) {
    final isUnhealthy = uiState.financialHealth == 'Unhealthy';
    final color = isUnhealthy
        ? uiState.remainingBudget < 0
              ? appTheme.errorRed
              : appTheme.warningPopupHeader
        : appTheme.wholeGoodBudgetProgress;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Financial Health',
          style: TextStyle(color: appTheme.gray_900, fontSize: 15),
        ),
        const SizedBox(width: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                uiState.financialHealth,
                style: TextStyle(color: color, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingBreakdown(
    TripSummaryViewModel viewModel,
    TripSummaryUiState uiState,
  ) {
    final colors = [
      appTheme.teal_A200,
      appTheme.teal_A700,
      appTheme.blue_gray_300,
    ];
    final highest = uiState.categories.isEmpty
        ? null
        : uiState.categories.reduce(
            (current, next) => next.expense > current.expense ? next : current,
          );

    return _SectionCard(
      title: 'Spending Breakdown by Category',
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                uiState.categories.length,
                (index) => Expanded(
                  child: _SpendingBarWidget(
                    category: uiState.categories[index],
                    color: colors[index % colors.length],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            highest == null || highest.expense == 0
                ? 'No expenses recorded for this trip'
                : 'Highest Expenditure: ${highest.name} (${viewModel.formatDisplayMoney(highest.expense)})',
            textAlign: TextAlign.center,
            style: TextStyle(color: appTheme.gray_900, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCostSavingTips(
    TripSummaryViewModel viewModel,
    TripSummaryUiState uiState,
  ) {
    return _SectionCard(
      title: 'Cost-Saving Tips',
      centerTitle: false,
      child: uiState.isLoadingCostSavingTips
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: appTheme.teal_A700,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating tips with Gemini...',
                    style: TextStyle(color: appTheme.gray_800, fontSize: 13),
                  ),
                ],
              ),
            )
          : uiState.costSavingTipsErrorMessage != null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    uiState.costSavingTipsErrorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: appTheme.errorRed, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: viewModel.loadCostSavingTips,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Try Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: appTheme.teal_A700,
                    ),
                  ),
                ],
              ),
            )
          : uiState.costSavingTips.isEmpty
          ? Text(
              'No cost-saving tips are available.',
              style: TextStyle(color: appTheme.gray_400, fontSize: 13),
            )
          : Column(
              children: List.generate(
                uiState.costSavingTips.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == uiState.costSavingTips.length - 1 ? 0 : 12,
                  ),
                  child: _CostSavingTipRow(tip: uiState.costSavingTips[index]),
                ),
              ),
            ),
    );
  }

  Widget _buildFutureBudgetRecommendations(
    BuildContext context,
    TripSummaryViewModel viewModel,
    TripSummaryUiState uiState,
  ) {
    return _SectionCard(
      title: 'Recommendations',
      centerTitle: false,
      trailing: uiState.isFutureRecommendationsExpanded
          ? IconButton(
              onPressed: uiState.isSavingFutureRecommendations
                  ? null
                  : viewModel.toggleFutureRecommendations,
              tooltip: 'Collapse recommendations',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.keyboard_arrow_up, color: appTheme.teal_800),
            )
          : null,
      child: !uiState.isFutureRecommendationsExpanded
          ? SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: viewModel.toggleFutureRecommendations,
                style: FilledButton.styleFrom(
                  backgroundColor: appTheme.teal_A700,
                  foregroundColor: appTheme.white_A700,
                  minimumSize: const Size.fromHeight(46),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const SizedBox(
                  height: 46,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Get Future Budget Recommendations'),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 0,
                        bottom: 0,
                        child: Icon(Icons.keyboard_arrow_down, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              children: [
                if (uiState.isLoadingFutureRecommendations)
                  SizedBox(
                    width: double.infinity,
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: appTheme.teal_A700,
                            strokeWidth: 2.5,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Generating future budget recommendations...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: appTheme.gray_800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (uiState.futureRecommendations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Text(
                          uiState.futureRecommendationsErrorMessage ??
                              'No future budget recommendations are available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                uiState.futureRecommendationsErrorMessage ==
                                    null
                                ? appTheme.gray_400
                                : appTheme.errorRed,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: viewModel.loadFutureBudgetRecommendations,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Try Again'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: appTheme.teal_A700,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ...uiState.futureRecommendations.map(
                    (recommendation) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _FutureBudgetRecommendationRow(
                        recommendation: recommendation,
                        onChanged: uiState.areFutureRecommendationsSaved
                            ? null
                            : (percentage) => viewModel
                                  .updateFutureRecommendationPercentage(
                                    recommendation.category,
                                    percentage,
                                  ),
                      ),
                    ),
                  ),
                  if (uiState.futureRecommendationsErrorMessage != null) ...[
                    Text(
                      uiState.futureRecommendationsErrorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: appTheme.errorRed, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (uiState.areFutureRecommendationsSaved)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: appTheme.teal_50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: appTheme.teal_800,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Saved recommendation',
                            style: TextStyle(
                              color: appTheme.teal_800,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: uiState.isSavingFutureRecommendations
                            ? null
                            : () => _acceptFutureBudgetRecommendations(
                                context,
                                viewModel,
                              ),
                        style: FilledButton.styleFrom(
                          backgroundColor: appTheme.teal_A700,
                          foregroundColor: appTheme.white_A700,
                          disabledBackgroundColor: appTheme.gray_200,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: uiState.isSavingFutureRecommendations
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: appTheme.white_A700,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text(
                                'Accept',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Future<void> _acceptFutureBudgetRecommendations(
    BuildContext context,
    TripSummaryViewModel viewModel,
  ) async {
    final result = await viewModel.acceptFutureBudgetRecommendations();
    if (!context.mounted) return;

    if (result == FutureRecommendationAcceptResult.invalidTotal) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => BaseBudgetDialog(
          title: 'Invalid Percentage Total',
          warningText:
              'The three categories currently total '
              '${viewModel.futureRecommendationTotal.round()}%. '
              'Please adjust them so the total is exactly 100%.',
          actions: _buildRecommendationDialogButton(
            text: 'Adjust Again',
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ),
      );
      return;
    }

    if (result == FutureRecommendationAcceptResult.saved) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => BaseBudgetDialog(
          title: 'Saved Successfully',
          titleColor: appTheme.teal_800,
          contentCard: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: appTheme.teal_800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your future budget recommendations have been saved.',
                  style: TextStyle(
                    color: appTheme.teal_800,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          actions: _buildRecommendationDialogButton(
            text: 'Continue',
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ),
      );
    }
  }

  Widget _buildRecommendationDialogButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: appTheme.teal_A700,
          foregroundColor: appTheme.white_A700,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _formatDateRange(DateTime startDate, DateTime endDate) {
    if (startDate.year == endDate.year && startDate.month == endDate.month) {
      if (startDate.day == endDate.day) {
        return 'On ${DateFormat('d MMM, yyyy').format(startDate)}';
      }
      return 'From ${startDate.day}-${DateFormat('d MMM, yyyy').format(endDate)}';
    }
    return 'From ${DateFormat('d MMM, yyyy').format(startDate)} - ${DateFormat('d MMM, yyyy').format(endDate)}';
  }
}

class _BudgetRingLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _BudgetRingLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(color: appTheme.blue_gray_700, fontSize: 11),
        ),
      ],
    );
  }
}

class _BudgetMetricsCard extends StatelessWidget {
  final TripSummaryUiState uiState;

  const _BudgetMetricsCard({required this.uiState});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BudgetMetric(
                  amount: uiState.allocatedBudget,
                  label: 'Allocated Budget',
                ),
              ),
              Container(width: 1, height: 74, color: appTheme.gray_200),
              Expanded(
                child: _BudgetMetric(
                  amount: uiState.totalExpense,
                  label: 'Expense',
                ),
              ),
            ],
          ),
          Divider(color: appTheme.gray_200, height: 1),
          if (uiState.topUpBudget > 0) ...[
            _BudgetMetric(
              amount: uiState.topUpBudget,
              label: 'Total Top-up Budget',
              amountColor: appTheme.teal_A700,
            ),
            Divider(color: appTheme.gray_200, height: 1),
            _BudgetMetric(amount: uiState.actualBudget, label: 'Actual Budget'),
            Divider(color: appTheme.gray_200, height: 1),
          ],
          _BudgetMetric(
            amount: uiState.remainingBudget,
            label: 'Remain',
            amountColor: uiState.remainingBudget < 0 ? appTheme.errorRed : null,
          ),
        ],
      ),
    );
  }
}

class _BudgetMetric extends StatelessWidget {
  final double amount;
  final String label;
  final Color? amountColor;

  const _BudgetMetric({
    required this.amount,
    required this.label,
    this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TripSummaryViewModel>();
    final primaryAmountText = viewModel.formatPrimaryMoney(amount);
    final secondaryAmountText = viewModel.formatSecondaryMoney(amount);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
      child: Column(
        children: [
          Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  primaryAmountText,
                  maxLines: 1,
                  style: TextStyle(
                    color: amountColor ?? appTheme.gray_900,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (secondaryAmountText != null) ...[
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '≈ $secondaryAmountText',
                    maxLines: 1,
                    style: TextStyle(
                      color: amountColor ?? appTheme.blue_gray_700,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: appTheme.gray_900, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SpendingBarWidget extends StatelessWidget {
  final TripSummaryCategoryUiState category;
  final Color color;

  const _SpendingBarWidget({required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    final amountText = context.watch<TripSummaryViewModel>().formatDisplayMoney(
      category.expense,
      compact: true,
    );
    final barHeight = category.percentage == 0
        ? 4.0
        : (category.percentage * 2.45).clamp(18.0, 145.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amountText,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: appTheme.gray_800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 54,
          height: barHeight,
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: barHeight < 30 ? 0 : 7),
          decoration: BoxDecoration(
            color: category.percentage == 0 ? appTheme.gray_200 : color,
            borderRadius: BorderRadius.circular(7),
          ),
          child: barHeight < 30
              ? null
              : Text(
                  '${category.percentage.round()}%',
                  style: TextStyle(
                    color: appTheme.white_A700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            category.name,
            style: TextStyle(
              color: appTheme.gray_800,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrencyConversionStatus extends StatelessWidget {
  final bool isLoading;
  final String preferredCurrency;
  final String? errorMessage;
  final VoidCallback onRetry;

  const _CurrencyConversionStatus({
    required this.isLoading,
    required this.preferredCurrency,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: appTheme.teal_A700,
            ),
          ),
          const SizedBox(width: 8),
        ] else if (hasError) ...[
          Icon(Icons.currency_exchange, size: 16, color: appTheme.errorRed),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            isLoading
                ? 'Converting RM to $preferredCurrency...'
                : errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: hasError ? appTheme.errorRed : appTheme.blue_gray_700,
              fontSize: 11,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(width: 4),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ],
    );
  }
}

class _TripCurrencyViewBadge extends StatelessWidget {
  final String preferredCurrency;

  const _TripCurrencyViewBadge({required this.preferredCurrency});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TripSummaryViewModel>();
    final uiState = viewModel.uiState;
    final canSelectPreferred =
        !uiState.isConvertingCurrency &&
        uiState.preferredCurrencyRates.containsKey('MYR');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: appTheme.teal_50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.currency_exchange,
              color: appTheme.teal_800,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Display currency',
              style: TextStyle(
                color: appTheme.blue_gray_700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _TripCurrencyCodeChip(
            label: 'RM',
            isSelected: !uiState.isPreferredCurrencyPrimary,
            onTap: () =>
                viewModel.selectPrimaryCurrency(usePreferredCurrency: false),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.swap_horiz_rounded,
              color: appTheme.blue_gray_300,
              size: 15,
            ),
          ),
          _TripCurrencyCodeChip(
            label: preferredCurrency,
            isSelected: uiState.isPreferredCurrencyPrimary,
            isEnabled: canSelectPreferred,
            onTap: () =>
                viewModel.selectPrimaryCurrency(usePreferredCurrency: true),
          ),
        ],
      ),
    );
  }
}

class _TripCurrencyCodeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _TripCurrencyCodeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: isEnabled,
      label: 'Use $label as primary currency',
      child: Material(
        color: appTheme.transparentCustom,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: isEnabled && isSelected
                  ? appTheme.teal_A700
                  : appTheme.gray_100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: !isEnabled
                    ? appTheme.blue_gray_300
                    : isSelected
                    ? appTheme.white_A700
                    : appTheme.blue_gray_700,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CostSavingTipRow extends StatelessWidget {
  final CostSavingTipUiState tip;

  const _CostSavingTipRow({required this.tip});

  @override
  Widget build(BuildContext context) {
    final (icon, background) = switch (tip.category) {
      'Transport' => (Icons.directions_bus_outlined, appTheme.teal_A200),
      'Attraction' => (Icons.confirmation_number_outlined, appTheme.amber_200),
      'Food' => (Icons.restaurant_outlined, appTheme.expenseBg),
      _ => (Icons.savings_outlined, appTheme.blue_gray_50),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: appTheme.teal_800, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tip.title,
                style: TextStyle(
                  color: appTheme.gray_900,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tip.description,
                style: TextStyle(color: appTheme.blue_gray_700, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FutureBudgetRecommendationRow extends StatelessWidget {
  final FutureBudgetRecommendationUiState recommendation;
  final ValueChanged<double>? onChanged;

  const _FutureBudgetRecommendationRow({
    required this.recommendation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (recommendation.category) {
      'Transport' => Icons.directions_bus_outlined,
      'Food' => Icons.restaurant_outlined,
      _ => Icons.account_balance_outlined,
    };
    final divisions =
        (recommendation.maximumPercentage - recommendation.minimumPercentage)
            .round();

    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Column(
            children: [
              Icon(icon, color: appTheme.gray_900, size: 22),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  recommendation.category,
                  maxLines: 1,
                  style: TextStyle(color: appTheme.gray_900, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: appTheme.teal_A700,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '${recommendation.aiPercentage.round()}%',
            style: TextStyle(
              color: appTheme.white_A700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${recommendation.minimumPercentage.round()}%',
                    style: TextStyle(color: appTheme.gray_800, fontSize: 10),
                  ),
                  Text(
                    '${recommendation.selectedPercentage.round()}%',
                    style: TextStyle(
                      color: appTheme.teal_800,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${recommendation.maximumPercentage.round()}%',
                    style: TextStyle(color: appTheme.gray_800, fontSize: 10),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  disabledActiveTrackColor: appTheme.teal_800,
                  disabledInactiveTrackColor: appTheme.gray_200,
                  disabledThumbColor: appTheme.teal_800,
                ),
                child: Slider(
                  value: recommendation.selectedPercentage,
                  min: recommendation.minimumPercentage,
                  max: recommendation.maximumPercentage,
                  divisions: divisions == 0 ? null : divisions,
                  activeColor: appTheme.teal_800,
                  inactiveColor: appTheme.gray_200,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool centerTitle;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.centerTitle = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: centerTitle
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: Text(
                    title,
                    textAlign: centerTitle ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      color: appTheme.gray_900,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
