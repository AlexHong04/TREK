import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/financial_dashboard_view_model.dart';
import 'trip_summary_screen.dart';

class FinancialDashboardScreen extends StatelessWidget {
  final VoidCallback? onHomeSelected;

  const FinancialDashboardScreen({super.key, this.onHomeSelected});

  static Widget builder(BuildContext context, {VoidCallback? onHomeSelected}) {
    return ChangeNotifierProvider<FinancialDashboardViewModel>(
      create: (_) => FinancialDashboardViewModel()..loadCurrentDay(),
      child: FinancialDashboardScreen(onHomeSelected: onHomeSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final uiState = viewModel.uiState;

    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPageIndicator(context),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Dashboard',
                        style: TextStyle(
                          color: appTheme.teal_A700,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (uiState.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (uiState.errorMessage != null)
                      _buildErrorState(
                        context,
                        viewModel,
                        uiState.errorMessage!,
                      )
                    else if (!uiState.hasCurrentTrip)
                      _buildEmptyState()
                    else ...[
                      _buildSummaryCard(uiState),
                      const SizedBox(height: 18),
                      _buildDateFilter(context, uiState),
                      const SizedBox(height: 34),
                      _buildCategoryChart(uiState),
                      const SizedBox(height: 26),
                      _buildExpenseChart(uiState),
                      const SizedBox(height: 24),
                      _buildBreakdownCard(uiState),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: appTheme.teal_A700, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Trek',
                style: TextStyle(
                  color: appTheme.teal_A700,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appTheme.gray_200,
              border: Border.all(color: appTheme.gray_100),
            ),
            child: Icon(Icons.person, color: appTheme.blue_gray_300, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onHomeSelected ?? () => Navigator.maybePop(context),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appTheme.gray_200,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appTheme.teal_A700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(FinancialDashboardUiState uiState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: appTheme.teal_A700,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _SummaryRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total Allocated Budget',
            amount: uiState.totalAllocatedBudget,
          ),
          Divider(
            color: appTheme.white_A700.withValues(alpha: 0.33),
            height: 1,
          ),
          _SummaryRow(
            icon: Icons.south_west,
            label: 'Total Expense',
            amount: uiState.totalExpense,
          ),
          Divider(
            color: appTheme.white_A700.withValues(alpha: 0.33),
            height: 1,
          ),
          _SummaryRow(
            icon: Icons.shield_outlined,
            label: 'Total Remain Budget',
            amount: uiState.remainingBudget,
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(
    BuildContext context,
    FinancialDashboardUiState uiState,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'For ${intl.DateFormat('d MMM, yyyy').format(uiState.selectedDate)}',
          style: TextStyle(color: appTheme.gray_400, fontSize: 18),
        ),
        PopupMenuButton<DashboardFilter>(
          onSelected: (filter) async {
            if (filter == DashboardFilter.byDate) {
              await _showAvailableDateDialog(context);
            } else {
              await _showCompletedTripDialog(context);
            }
          },
          color: appTheme.white_A700,
          elevation: 3,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: DashboardFilter.byDate,
              child: Text('By Date'),
            ),
            PopupMenuItem(
              value: DashboardFilter.byTrip,
              child: Text('By Trip'),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: appTheme.white_A700,
              border: Border.all(color: appTheme.gray_200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  color: appTheme.teal_A700,
                  size: 21,
                ),
                const SizedBox(width: 7),
                Text('Filter', style: TextStyle(color: appTheme.teal_A700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAvailableDateDialog(BuildContext context) async {
    final viewModel = context.read<FinancialDashboardViewModel>();
    viewModel.loadAvailableDates();

    final selectedDate = await showDialog<DateTime>(
      context: context,
      barrierColor: appTheme.gray_900.withValues(alpha: 0.25),
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: const _AvailableDateDialog(),
      ),
    );

    if (selectedDate != null && context.mounted) {
      await viewModel.loadDate(selectedDate);
    }
  }

  Future<void> _showCompletedTripDialog(BuildContext context) async {
    final viewModel = context.read<FinancialDashboardViewModel>();
    viewModel.loadCompletedTrips();

    final selectedTrip = await showDialog<DashboardTripUiState>(
      context: context,
      barrierColor: appTheme.gray_900.withValues(alpha: 0.25),
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: const _CompletedTripDialog(),
      ),
    );

    if (selectedTrip != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TripSummaryScreen.builder(context, tripId: selectedTrip.tripId),
        ),
      );
    }
  }

  Widget _buildCategoryChart(FinancialDashboardUiState uiState) {
    final categories = uiState.categories;
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartSize = Size(constraints.maxWidth, 220);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleDonutTap(
                  context,
                  details.localPosition,
                  chartSize,
                  categories,
                  uiState,
                ),
                child: CustomPaint(
                  size: chartSize,
                  painter: DashboardDonutChartPainter(categories),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: categories
              .map(
                (item) => _LegendChip(
                  label: item.name,
                  color: dashboardCategoryColor(item.name),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildExpenseChart(FinancialDashboardUiState uiState) {
    final categories = uiState.categories;
    final maximumAmount = categories.fold<double>(
      0,
      (maximum, category) =>
          math.max(maximum, math.max(category.budget, category.expense)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Expense', style: TextStyle(fontSize: 15)),
        const SizedBox(height: 16),
        SizedBox(
          height: 155,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: categories
                .map(
                  (item) => Expanded(
                    child: _ExpenseBars(
                      category: item,
                      maximumAmount: maximumAmount,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _DotLegend(label: 'Allocated Budget', color: appTheme.teal_800),
            _DotLegend(label: 'Expenses', color: appTheme.gray_200),
            _DotLegend(
              label: 'Overspending',
              color: appTheme.expenseOverspendBg,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreakdownCard(FinancialDashboardUiState uiState) {
    final orderedCategories = uiState.categories;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ColumnHeading(
                  color: appTheme.expenseBg,
                  label: 'Budget',
                ),
              ),
              Expanded(
                child: _ColumnHeading(
                  color: appTheme.warningPopupHeader,
                  label: 'Expense',
                ),
              ),
              Expanded(
                child: _ColumnHeading(
                  color: appTheme.teal_A700,
                  label: 'Remaining',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < orderedCategories.length; index++) ...[
            _BreakdownRow(category: orderedCategories[index]),
            if (index != orderedCategories.length - 1)
              Divider(color: appTheme.gray_200, height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    FinancialDashboardViewModel viewModel,
    String message,
  ) {
    return Center(
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: viewModel.loadCurrentDay,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No trip or expenses found for today.'));
  }

  void _handleDonutTap(
    BuildContext context,
    Offset position,
    Size size,
    List<DashboardCategoryUiState> chartCategories,
    FinancialDashboardUiState uiState,
  ) {
    final center = Offset(size.width / 2, size.height / 2);
    final distance = (position - center).distance;
    if (distance < 42 || distance > 74) return;

    final totalExpense = chartCategories.fold<double>(
      0,
      (sum, category) => sum + category.expense,
    );
    if (totalExpense <= 0) return;

    var tapAngle = math.atan2(position.dy - center.dy, position.dx - center.dx);
    tapAngle += math.pi / 2;
    if (tapAngle < 0) tapAngle += math.pi * 2;

    var accumulatedAngle = 0.0;
    for (final chartCategory in chartCategories) {
      if (chartCategory.expense <= 0) continue;
      final sweep = math.pi * 2 * chartCategory.expense / totalExpense;
      if (tapAngle >= accumulatedAngle && tapAngle < accumulatedAngle + sweep) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FinancialExpenseDetailView(
              category: chartCategory,
              date: uiState.selectedDate,
            ),
          ),
        );
        return;
      }
      accumulatedAngle += sweep;
    }
  }
}

class _FinancialExpenseDetailView extends StatelessWidget {
  final DashboardCategoryUiState category;
  final DateTime date;

  const _FinancialExpenseDetailView({
    required this.category,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            children: [
              Text(
                category.name,
                style: TextStyle(color: appTheme.gray_900, fontSize: 18),
              ),
              const SizedBox(height: 2),
              Text(
                'From ${intl.DateFormat('d MMM, yyyy').format(date)}',
                style: TextStyle(color: appTheme.gray_400, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _DashboardDetailSummary(category: category),
              const SizedBox(height: 24),
              if (category.expenseDetails.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'No expense records for ${category.name}.',
                    style: TextStyle(color: appTheme.gray_400),
                  ),
                )
              else
                ...category.expenseDetails.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _DashboardExpenseCard(item: item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardDetailSummary extends StatelessWidget {
  final DashboardCategoryUiState category;

  const _DashboardDetailSummary({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: appTheme.teal_A700,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _SummaryRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total Allocated Budget',
            amount: category.budget,
          ),
          Divider(
            color: appTheme.white_A700.withValues(alpha: 0.33),
            height: 1,
          ),
          _SummaryRow(
            icon: Icons.south_west,
            label: 'Total Expense',
            amount: category.expense,
          ),
          Divider(
            color: appTheme.white_A700.withValues(alpha: 0.33),
            height: 1,
          ),
          _SummaryRow(
            icon: Icons.shield_outlined,
            label: 'Total Remain Budget',
            amount: category.remaining,
          ),
        ],
      ),
    );
  }
}

class _DashboardExpenseCard extends StatelessWidget {
  final DashboardExpenseDetailUiState item;

  const _DashboardExpenseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _DashboardActivityImage(imageUrl: item.activityImageUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.activityName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: appTheme.gray_900,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                _DashboardDetailLine(icon: Icons.schedule, text: item.timeText),
                const SizedBox(height: 6),
                _DashboardDetailLine(
                  icon: Icons.account_balance_wallet_outlined,
                  text: 'RM ${item.amount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: appTheme.gray_100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.credit_card,
                        size: 13,
                        color: appTheme.teal_A700,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          item.paymentMethod,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: appTheme.blue_gray_700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardDetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DashboardDetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: appTheme.blue_gray_300),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: appTheme.blue_gray_300, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _DashboardActivityImage extends StatelessWidget {
  final String imageUrl;

  const _DashboardActivityImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: 120,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    if (imageUrl.isNotEmpty) {
      return Image.asset(
        imageUrl,
        width: 120,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 120,
      height: 100,
      color: appTheme.gray_100,
      child: Icon(
        Icons.image_outlined,
        color: appTheme.blue_gray_300,
        size: 34,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: appTheme.white_A700.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: appTheme.white_A700, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: appTheme.white_A700,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 112,
            child: Row(
              children: [
                SizedBox(width: 28, child: Text('RM', style: _amountStyle)),
                Expanded(
                  child: Text(
                    amount.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: _amountStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _amountStyle => TextStyle(
    color: appTheme.white_A700,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _ExpenseBars extends StatelessWidget {
  final DashboardCategoryUiState category;
  final double maximumAmount;

  const _ExpenseBars({required this.category, required this.maximumAmount});

  @override
  Widget build(BuildContext context) {
    final expenseColor = category.isOverspent
        ? appTheme.expenseOverspendBg
        : appTheme.gray_200;
    double barHeight(double amount) {
      if (amount <= 0 || maximumAmount <= 0) return 2;
      return math.max(8, 88 * amount / maximumAmount);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _AmountBar(
              amount: category.budget,
              height: barHeight(category.budget),
              color: appTheme.teal_800,
            ),
            const SizedBox(width: 10),
            _AmountBar(
              amount: category.expense,
              height: barHeight(category.expense),
              color: expenseColor,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          category.name,
          textAlign: TextAlign.center,
          style: TextStyle(color: appTheme.gray_400, fontSize: 12),
        ),
      ],
    );
  }
}

class _AmountBar extends StatelessWidget {
  final double amount;
  final double height;
  final Color color;

  const _AmountBar({
    required this.amount,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'RM${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: amount == 0 ? appTheme.gray_400 : color,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 12,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ],
    );
  }
}

class _DotLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _DotLegend({required this.label, required this.color});

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
        Text(label, style: TextStyle(color: appTheme.gray_400, fontSize: 12)),
      ],
    );
  }
}

class _ColumnHeading extends StatelessWidget {
  final Color color;
  final String label;

  const _ColumnHeading({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: appTheme.gray_400, fontSize: 10)),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final DashboardCategoryUiState category;

  const _BreakdownRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final remaining = category.budget - category.expense;
    final percentage = category.budget == 0
        ? 0.0
        : category.expense / category.budget * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: category.isOverspent
                    ? appTheme.errorRed
                    : appTheme.teal_A700,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (category.isOverspent) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: appTheme.wholeAlertBudgetBg,
                  border: Border.all(color: appTheme.wholeAlertBudgetStroke),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Overspend',
                  style: TextStyle(
                    color: appTheme.errorRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MoneyCell(
              amount: category.budget,
              percentage: 100,
              color: appTheme.gray_400,
            ),
            _MoneyCell(
              amount: category.expense,
              percentage: percentage,
              color: appTheme.warningPopupHeader,
            ),
            _MoneyCell(
              amount: remaining,
              percentage: category.budget == 0
                  ? 0
                  : remaining / category.budget * 100,
              color: category.isOverspent
                  ? appTheme.errorRed
                  : appTheme.teal_A700,
            ),
          ],
        ),
      ],
    );
  }
}

class _MoneyCell extends StatelessWidget {
  final double amount;
  final double percentage;
  final Color color;

  const _MoneyCell({
    required this.amount,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sign = amount < 0 ? '-' : '';
    return Expanded(
      child: Column(
        children: [
          Text(
            'RM $sign${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _CompletedTripDialog extends StatelessWidget {
  const _CompletedTripDialog();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final uiState = viewModel.uiState;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
      backgroundColor: appTheme.white_A700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screenHeight * 0.88,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
              child: Text(
                'Completed Trip',
                style: TextStyle(
                  color: appTheme.warningPopupHeader,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Divider(color: appTheme.gray_200, height: 1),
            Expanded(
              child: uiState.isLoadingCompletedTrips
                  ? const Center(child: CircularProgressIndicator())
                  : uiState.completedTripsErrorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              uiState.completedTripsErrorMessage!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: viewModel.loadCompletedTrips,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : uiState.completedTrips.isEmpty
                  ? const Center(child: Text('No completed trips found.'))
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        itemCount: uiState.completedTrips.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 24),
                        itemBuilder: (context, index) => _CompletedTripCard(
                          trip: uiState.completedTrips[index],
                          onSelected: () => Navigator.pop(
                            context,
                            uiState.completedTrips[index],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedTripCard extends StatelessWidget {
  final DashboardTripUiState trip;
  final VoidCallback onSelected;

  const _CompletedTripCard({required this.trip, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _buildTripImage(),
              Positioned(
                top: 14,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: appTheme.teal_A700,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: appTheme.white_A700,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Completed',
                        style: TextStyle(
                          color: appTheme.white_A700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appTheme.blueGray900,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'RM ${trip.totalBudget.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: appTheme.blueGray900,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TripInformationChip(
                      icon: Icons.calendar_today_outlined,
                      label:
                          '${intl.DateFormat('MMM d').format(trip.startDate)} - ${intl.DateFormat('MMM d, yyyy').format(trip.endDate)}',
                    ),
                    _TripInformationChip(
                      icon: Icons.favorite_outline,
                      label: trip.travelPreference.isEmpty
                          ? 'General'
                          : trip.travelPreference,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Trip ID: ${trip.tripId}',
                  style: TextStyle(
                    color: appTheme.blue_gray_700,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: onSelected,
                    icon: const Icon(Icons.map_outlined, size: 19),
                    label: const Text(
                      'Select Trip',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: appTheme.teal_A700,
                      foregroundColor: appTheme.white_A700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripImage() {
    if (trip.imageUrl.startsWith('http')) {
      return Image.network(
        trip.imageUrl,
        width: double.infinity,
        height: 190,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildImagePlaceholder();
        },
        errorBuilder: (_, _, _) => _buildImagePlaceholder(),
      );
    }
    if (trip.imageUrl.isNotEmpty) {
      return Image.asset(
        trip.imageUrl,
        width: double.infinity,
        height: 190,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildImagePlaceholder(),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 190,
      color: appTheme.gray_200,
      child: Icon(
        Icons.landscape_outlined,
        color: appTheme.blue_gray_300,
        size: 48,
      ),
    );
  }
}

class _TripInformationChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TripInformationChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: appTheme.gray_100,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: appTheme.teal_A700, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: appTheme.blue_gray_700, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AvailableDateDialog extends StatelessWidget {
  const _AvailableDateDialog();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final uiState = viewModel.uiState;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      backgroundColor: appTheme.white_A700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
              child: Text(
                'Available Date',
                style: TextStyle(
                  color: appTheme.warningPopupHeader,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Divider(color: appTheme.gray_200, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              child: uiState.isLoadingAvailableDates
                  ? const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : uiState.availableDatesErrorMessage != null
                  ? SizedBox(
                      height: 220,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              uiState.availableDatesErrorMessage!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: viewModel.loadAvailableDates,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : uiState.availableDates.isEmpty
                  ? const SizedBox(
                      height: 220,
                      child: Center(
                        child: Text('No available dates for this trip.'),
                      ),
                    )
                  : _AvailableDateCalendar(
                      availableDates: uiState.availableDates,
                      selectedDate: uiState.selectedDate,
                      displayedMonth: uiState.displayedCalendarMonth,
                      onPreviousMonth: viewModel.showPreviousCalendarMonth,
                      onNextMonth: viewModel.showNextCalendarMonth,
                      onSelected: (date) => Navigator.pop(context, date),
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: appTheme.gray_50,
              child: Center(
                child: SizedBox(
                  width: 150,
                  height: 42,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: appTheme.teal_A700,
                      foregroundColor: appTheme.white_A700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailableDateCalendar extends StatelessWidget {
  final List<DateTime> availableDates;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelected;

  const _AvailableDateCalendar({
    required this.availableDates,
    required this.selectedDate,
    required this.displayedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = displayedMonth;
    final daysInMonth = DateUtils.getDaysInMonth(
      displayedMonth.year,
      displayedMonth.month,
    );
    final leadingEmptyCells = firstDay.weekday % 7;
    final totalCells = leadingEmptyCells + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final weekdays = List.generate(
      7,
      (index) => intl.DateFormat(
        'EEE',
      ).format(DateTime(2024, 1, 7 + index)).toUpperCase(),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  intl.DateFormat('MMMM yyyy').format(displayedMonth),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: appTheme.gray_900,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: weekdays
                .map(
                  (weekday) => Expanded(
                    child: Center(
                      child: Text(
                        weekday,
                        style: TextStyle(
                          color: appTheme.gray_400,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < rowCount; row++)
            Row(
              children: List.generate(7, (column) {
                final cellIndex = row * 7 + column;
                final day = cellIndex - leadingEmptyCells + 1;
                return Expanded(
                  child: day < 1 || day > daysInMonth
                      ? const SizedBox(height: 40)
                      : _buildDay(
                          DateTime(
                            displayedMonth.year,
                            displayedMonth.month,
                            day,
                          ),
                        ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildDay(DateTime date) {
    final isSelected = _isSameDate(date, selectedDate);
    final isAvailable = availableDates.any(
      (availableDate) => _isSameDate(date, availableDate),
    );
    final backgroundColor = isSelected
        ? appTheme.wholeGoodBudgetProgress
        : isAvailable
        ? appTheme.teal_50
        : appTheme.gray_200;
    final textColor = isSelected
        ? appTheme.white_A700
        : isAvailable
        ? appTheme.teal_800
        : appTheme.gray_400;

    return Center(
      child: GestureDetector(
        onTap: isAvailable ? () => onSelected(date) : null,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
