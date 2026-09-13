import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../models/services/i_auth_service.dart';
import '../models/services/i_profile_service.dart';
import '../view_models/presentation_logic/financial_dashboard_view_model.dart';
import 'profile_screen.dart';
import 'trip_summary_screen.dart';

class FinancialDashboardScreen extends StatelessWidget {
  final VoidCallback? onHomeSelected;

  const FinancialDashboardScreen({super.key, this.onHomeSelected});

  static Widget builder(BuildContext context, {VoidCallback? onHomeSelected}) {
    return ChangeNotifierProvider<FinancialDashboardViewModel>(
      create: (providerContext) => FinancialDashboardViewModel(
        authService: providerContext.read<IAuthService>(),
        profileService: providerContext.read<IProfileService>(),
      )..loadCurrentDay(),
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
            _buildTopBar(context, viewModel),
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
                    else ...[
                      _buildSummaryCard(uiState),
                      if (uiState.isConvertingCurrency ||
                          uiState.currencyConversionErrorMessage != null) ...[
                        const SizedBox(height: 8),
                        _FinancialCurrencyConversionStatus(
                          isLoading: uiState.isConvertingCurrency,
                          preferredCurrency: uiState.preferredCurrency,
                          errorMessage: uiState.currencyConversionErrorMessage,
                          onRetry: viewModel.retryCurrencyConversion,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _buildDateFilter(context, uiState),
                      const SizedBox(height: 34),
                      _buildCategoryChart(viewModel, uiState),
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

  Widget _buildTopBar(
    BuildContext context,
    FinancialDashboardViewModel viewModel,
  ) {
    final profilePictureUrl = viewModel.uiState.profilePictureUrl;
    final trimmedName = viewModel.uiState.profileName.trim();
    final initial = trimmedName.isEmpty ? 'T' : trimmedName[0].toUpperCase();

    Widget initialAvatar() {
      return Center(
        child: Text(
          initial,
          style: TextStyle(
            color: appTheme.teal_800,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

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
          Semantics(
            button: true,
            label: 'Open profile',
            child: Material(
              color: appTheme.teal_50,
              shape: CircleBorder(
                side: BorderSide(color: appTheme.gray_100, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openProfile(context, viewModel),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: profilePictureUrl?.isNotEmpty == true
                      ? Image.network(
                          profilePictureUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, loadingProgress) =>
                              loadingProgress == null ? child : initialAvatar(),
                          errorBuilder: (_, _, _) => initialAvatar(),
                        )
                      : initialAvatar(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProfile(
    BuildContext context,
    FinancialDashboardViewModel viewModel,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => ProfileScreen.builder(routeContext),
      ),
    );
    if (context.mounted) {
      await viewModel.refreshProfile();
    }
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
          if (uiState.topUpBudget > 0) ...[
            _SummaryRow(
              icon: Icons.add_card_outlined,
              label: 'Top-up Budget',
              amount: uiState.topUpBudget,
            ),
            Divider(
              color: appTheme.white_A700.withValues(alpha: 0.33),
              height: 1,
            ),
            _SummaryRow(
              icon: Icons.calculate_outlined,
              label: 'Actual Budget',
              amount: uiState.totalAvailableBudget,
            ),
            Divider(
              color: appTheme.white_A700.withValues(alpha: 0.33),
              height: 1,
            ),
          ],
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
            label: 'Total Remaining Budget',
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
          style: TextStyle(
            color: appTheme.blue_gray_700,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        PopupMenuButton<DashboardFilter>(
          tooltip: 'Filter dashboard',
          onSelected: (filter) async {
            if (filter == DashboardFilter.byDate) {
              await _showAvailableDateDialog(context);
            } else {
              await _showCompletedTripDialog(context);
            }
          },
          color: appTheme.white_A700,
          surfaceTintColor: appTheme.white_A700,
          shadowColor: appTheme.gray_900.withValues(alpha: 0.16),
          elevation: 8,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          constraints: const BoxConstraints(minWidth: 132, maxWidth: 140),
          menuPadding: const EdgeInsets.symmetric(vertical: 6),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: appTheme.gray_200),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: DashboardFilter.byDate,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _DashboardFilterMenuItem(
                icon: Icons.calendar_month_outlined,
                label: 'By Date',
              ),
            ),
            PopupMenuDivider(height: 1, color: appTheme.gray_200),
            PopupMenuItem(
              value: DashboardFilter.byTrip,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _DashboardFilterMenuItem(
                icon: Icons.luggage_outlined,
                label: 'By Trip',
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: appTheme.white_A700,
              border: Border.all(color: appTheme.gray_200),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: appTheme.black_900_0c,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
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

  Widget _buildCategoryChart(
    FinancialDashboardViewModel viewModel,
    FinancialDashboardUiState uiState,
  ) {
    final categories = uiState.categories;
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartSize = Size(constraints.maxWidth, 260);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleDonutTap(
                  context,
                  details.localPosition,
                  chartSize,
                  categories,
                  uiState,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      size: chartSize,
                      painter: DashboardDonutChartPainter(
                        categories,
                        amountLabelBuilder: (amount) => _displayMyrCode(
                          viewModel.formatMoneyPair(amount, compact: true),
                        ),
                      ),
                    ),
                    if (uiState.totalExpense <= 0)
                      Center(
                        child: Text(
                          'No expense\nrecords yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: appTheme.gray_800,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
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
        Text(
          'Expense',
          style: TextStyle(
            color: appTheme.gray_800,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
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
            _DotLegend(
              label: 'Allocated Budget',
              color: appTheme.blue_gray_700,
            ),
            _DotLegend(label: 'Expenses', color: appTheme.teal_800),
            _DotLegend(
              label: 'Overspending',
              color: appTheme.expenseOverspendText,
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
                  color: appTheme.blue_gray_700,
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
              Expanded(
                child: _ColumnHeading(
                  color: appTheme.expenseOverspendText,
                  label: 'Over Budget',
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
        final viewModel = context.read<FinancialDashboardViewModel>();
        viewModel.clearExpenseSearch();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: viewModel,
              child: _FinancialExpenseDetailView(
                category: chartCategory,
                date: uiState.selectedDate,
              ),
            ),
          ),
        );
        return;
      }
      accumulatedAngle += sweep;
    }
  }
}

String _displayMyrCode(String value) {
  return value.replaceAll(RegExp(r'\bRM\b'), 'MYR');
}

class _CurrencyAmountPairText extends StatelessWidget {
  final String primaryText;
  final String? secondaryText;
  final TextStyle primaryStyle;
  final TextStyle secondaryStyle;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  const _CurrencyAmountPairText({
    required this.primaryText,
    required this.secondaryText,
    required this.primaryStyle,
    required this.secondaryStyle,
    this.crossAxisAlignment = CrossAxisAlignment.end,
    this.textAlign = TextAlign.end,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _displayMyrCode(primaryText),
            maxLines: 1,
            textAlign: textAlign,
            style: primaryStyle,
          ),
        ),
        if (secondaryText != null) ...[
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '≈ ${_displayMyrCode(secondaryText!)}',
              maxLines: 1,
              textAlign: textAlign,
              style: secondaryStyle,
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardFilterMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DashboardFilterMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: appTheme.teal_50,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: appTheme.teal_800, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: appTheme.gray_900,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FinancialCurrencyConversionStatus extends StatelessWidget {
  final bool isLoading;
  final String preferredCurrency;
  final String? errorMessage;
  final VoidCallback onRetry;

  const _FinancialCurrencyConversionStatus({
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
                ? 'Converting MYR to $preferredCurrency...'
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

class _FinancialExpenseDetailView extends StatelessWidget {
  final DashboardCategoryUiState category;
  final DateTime date;

  const _FinancialExpenseDetailView({
    required this.category,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final searchQuery = viewModel.uiState.expenseSearchQuery;
    final allExpenseDetails = category.expenseDetails;
    final expenseDetails = viewModel.sortedExpenseDetails(allExpenseDetails);
    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      appBar: AppBar(
        backgroundColor: appTheme.white_A700,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: appTheme.teal_A700),
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
              const SizedBox(height: 18),
              _DashboardExpenseSearchField(
                query: searchQuery,
                onChanged: viewModel.setExpenseSearchQuery,
                onClear: viewModel.clearExpenseSearch,
              ),
              const SizedBox(height: 12),
              _DashboardExpenseSortBar(
                visibleExpenseCount: expenseDetails.length,
                totalExpenseCount: allExpenseDetails.length,
                isSearching: searchQuery.trim().isNotEmpty,
              ),
              const SizedBox(height: 12),
              if (expenseDetails.isEmpty)
                _DashboardExpenseEmptyState(
                  categoryName: category.name,
                  searchQuery: searchQuery,
                  onClearSearch: viewModel.clearExpenseSearch,
                )
              else
                ...expenseDetails.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _DashboardExpenseCard(
                      item: item,
                      onTap: () => _showExpenseItems(context, item),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExpenseItems(
    BuildContext context,
    DashboardExpenseDetailUiState expense,
  ) async {
    final viewModel = context.read<FinancialDashboardViewModel>();
    final loadFuture = viewModel.loadExpenseItems(expense.expenseId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: appTheme.transparentCustom,
      barrierColor: appTheme.black.withValues(alpha: 0.25),
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: _DashboardExpenseItemsSheet(expense: expense),
      ),
    );

    await loadFuture;
    viewModel.clearExpenseItems();
  }
}

class _DashboardExpenseSearchField extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _DashboardExpenseSearchField({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_DashboardExpenseSearchField> createState() =>
      _DashboardExpenseSearchFieldState();
}

class _DashboardExpenseSearchFieldState
    extends State<_DashboardExpenseSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _DashboardExpenseSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query == _controller.text) return;
    _controller.value = TextEditingValue(
      text: widget.query,
      selection: TextSelection.collapsed(offset: widget.query.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    setState(() {});
    widget.onChanged(value);
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;
    return TextField(
      controller: _controller,
      onChanged: _handleChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: appTheme.gray_900,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Search activity, payment, date or amount',
        hintStyle: TextStyle(color: appTheme.gray_400, fontSize: 12),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: hasQuery ? appTheme.teal_A700 : appTheme.blue_gray_300,
          size: 20,
        ),
        suffixIcon: hasQuery
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: _clear,
                icon: Icon(
                  Icons.close_rounded,
                  color: appTheme.blue_gray_300,
                  size: 18,
                ),
              )
            : null,
        filled: true,
        fillColor: appTheme.white_A700,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appTheme.gray_200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appTheme.teal_A700, width: 1.4),
        ),
      ),
    );
  }
}

class _DashboardExpenseSortBar extends StatelessWidget {
  final int visibleExpenseCount;
  final int totalExpenseCount;
  final bool isSearching;

  const _DashboardExpenseSortBar({
    required this.visibleExpenseCount,
    required this.totalExpenseCount,
    required this.isSearching,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final selectedSort = viewModel.uiState.expenseSort;
    return Row(
      children: [
        Expanded(
          child: Text(
            isSearching
                ? '$visibleExpenseCount of $totalExpenseCount records'
                : '$totalExpenseCount expense '
                      '${totalExpenseCount == 1 ? 'record' : 'records'}',
            style: TextStyle(
              color: appTheme.blue_gray_700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        PopupMenuButton<DashboardExpenseSort>(
          tooltip: 'Sort expense records',
          initialValue: selectedSort,
          onSelected: viewModel.setExpenseSort,
          color: appTheme.white_A700,
          surfaceTintColor: appTheme.white_A700,
          elevation: 8,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          constraints: const BoxConstraints(minWidth: 210, maxWidth: 230),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: appTheme.gray_200),
          ),
          itemBuilder: (context) => DashboardExpenseSort.values
              .map(
                (sort) => PopupMenuItem<DashboardExpenseSort>(
                  value: sort,
                  height: 44,
                  child: Row(
                    children: [
                      Icon(
                        sort == DashboardExpenseSort.timeEarliest ||
                                sort == DashboardExpenseSort.timeLatest
                            ? Icons.schedule_outlined
                            : Icons.payments_outlined,
                        size: 17,
                        color: sort == selectedSort
                            ? appTheme.teal_A700
                            : appTheme.blue_gray_300,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          viewModel.expenseSortLabel(sort),
                          style: TextStyle(
                            color: appTheme.gray_900,
                            fontSize: 12,
                            fontWeight: sort == selectedSort
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (sort == selectedSort)
                        Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: appTheme.teal_A700,
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: appTheme.white_A700,
              border: Border.all(color: appTheme.gray_200),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: appTheme.black_900_0c,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort_rounded, size: 17, color: appTheme.teal_A700),
                const SizedBox(width: 6),
                Text(
                  viewModel.expenseSortLabel(selectedSort),
                  style: TextStyle(
                    color: appTheme.teal_800,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: appTheme.teal_A700,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardExpenseEmptyState extends StatelessWidget {
  final String categoryName;
  final String searchQuery;
  final VoidCallback onClearSearch;

  const _DashboardExpenseEmptyState({
    required this.categoryName,
    required this.searchQuery,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim();
    final hasSearchQuery = query.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: appTheme.gray_100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSearchQuery
                  ? Icons.search_off_rounded
                  : Icons.receipt_long_outlined,
              color: appTheme.blue_gray_300,
              size: 23,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasSearchQuery
                ? 'No expenses match "$query".'
                : 'No expense records for $categoryName.',
            textAlign: TextAlign.center,
            style: TextStyle(color: appTheme.blue_gray_700, fontSize: 13),
          ),
          if (hasSearchQuery) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Clear search'),
              style: TextButton.styleFrom(foregroundColor: appTheme.teal_A700),
            ),
          ],
        ],
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
            label: 'Total Remaining Budget',
            amount: category.remaining,
          ),
        ],
      ),
    );
  }
}

class _DashboardExpenseCard extends StatelessWidget {
  final DashboardExpenseDetailUiState item;
  final VoidCallback onTap;

  const _DashboardExpenseCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final primaryAmountText = viewModel.formatPrimaryMoney(
      item.amount,
      originalCurrency: item.currency,
    );
    final secondaryAmountText = viewModel.formatSecondaryMoney(
      item.amount,
      originalCurrency: item.currency,
    );
    return Material(
      color: appTheme.white_A700,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: appTheme.black_900_0c,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    _DashboardDetailLine(
                      icon: Icons.schedule,
                      text: item.timeText,
                    ),
                    const SizedBox(height: 6),
                    _DashboardDetailLine(
                      icon: Icons.account_balance_wallet_outlined,
                      text: primaryAmountText,
                      secondaryText: secondaryAmountText,
                      textColor: item.amount < 0 ? appTheme.errorRed : null,
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
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: appTheme.gray_400),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardExpenseItemsSheet extends StatelessWidget {
  final DashboardExpenseDetailUiState expense;

  const _DashboardExpenseItemsSheet({required this.expense});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final uiState = viewModel.uiState;
    final isSelectedExpense = uiState.selectedExpenseId == expense.expenseId;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Material(
        color: appTheme.white_A700,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: appTheme.gray_200,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Expense Details',
                      style: TextStyle(
                        color: appTheme.gray_900,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: appTheme.blue_gray_700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: appTheme.gray_50_02,
                  border: Border.all(color: appTheme.gray_200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.activityName,
                      style: TextStyle(
                        color: appTheme.gray_900,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ExpenseSheetInfoLine(
                      icon: Icons.payments_outlined,
                      label: 'Total Expense',
                      value: viewModel.formatPrimaryMoney(
                        expense.amount,
                        originalCurrency: expense.currency,
                      ),
                      secondaryValue: viewModel.formatSecondaryMoney(
                        expense.amount,
                        originalCurrency: expense.currency,
                      ),
                      valueColor: expense.amount < 0 ? appTheme.errorRed : null,
                    ),
                    _ExpenseSheetInfoLine(
                      icon: Icons.credit_card_outlined,
                      label: 'Payment Method',
                      value: expense.paymentMethod,
                    ),
                    _ExpenseSheetInfoLine(
                      icon: Icons.event_outlined,
                      label: 'Recorded On',
                      value: expense.recordedAtText,
                    ),
                    _ExpenseSheetInfoLine(
                      icon: Icons.receipt_long_outlined,
                      label: 'Receipt',
                      value: expense.receiptImageUrl?.trim().isNotEmpty == true
                          ? 'Attached'
                          : 'Not attached',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'EXPENSE ITEMS',
                style: TextStyle(
                  color: appTheme.blue_gray_700,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              if (!isSelectedExpense || uiState.isLoadingExpenseItems)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (uiState.expenseItemsErrorMessage != null)
                _ExpenseItemsError(
                  message: uiState.expenseItemsErrorMessage!,
                  onRetry: () => viewModel.loadExpenseItems(expense.expenseId),
                )
              else if (uiState.selectedExpenseItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: appTheme.gray_50_02,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'No expense items were recorded.',
                    style: TextStyle(color: appTheme.blue_gray_300),
                  ),
                )
              else
                for (
                  var index = 0;
                  index < uiState.selectedExpenseItems.length;
                  index++
                ) ...[
                  _DashboardExpenseItemCard(
                    item: uiState.selectedExpenseItems[index],
                    itemNumber: index + 1,
                    currency: expense.currency,
                  ),
                  if (index != uiState.selectedExpenseItems.length - 1)
                    const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseSheetInfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? secondaryValue;
  final Color? valueColor;
  final bool isLast;

  const _ExpenseSheetInfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.secondaryValue,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: appTheme.teal_A700),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: appTheme.blue_gray_700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: secondaryValue == null
                ? Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: valueColor ?? appTheme.gray_900,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : _CurrencyAmountPairText(
                    primaryText: value,
                    secondaryText: secondaryValue,
                    textAlign: TextAlign.right,
                    primaryStyle: TextStyle(
                      color: valueColor ?? appTheme.gray_900,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    secondaryStyle: TextStyle(
                      color: valueColor ?? appTheme.blue_gray_700,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DashboardExpenseItemCard extends StatelessWidget {
  final DashboardExpenseItemUiState item;
  final int itemNumber;
  final String currency;

  const _DashboardExpenseItemCard({
    required this.item,
    required this.itemNumber,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final description = item.itemDescription?.trim() ?? '';
    final merchant = item.merchantName?.trim() ?? '';
    final subtotalPrimary = viewModel.formatPrimaryMoney(
      item.subtotal,
      originalCurrency: currency,
    );
    final subtotalSecondary = viewModel.formatSecondaryMoney(
      item.subtotal,
      originalCurrency: currency,
    );
    final unitPricePrimary = viewModel.formatPrimaryMoney(
      item.unitPrice,
      originalCurrency: currency,
    );
    final unitPriceSecondary = viewModel.formatSecondaryMoney(
      item.unitPrice,
      originalCurrency: currency,
    );
    final subtotalColor = item.subtotal < 0
        ? appTheme.errorRed
        : appTheme.teal_800;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: appTheme.teal_50,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$itemNumber',
                  style: TextStyle(
                    color: appTheme.teal_800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  item.itemName,
                  style: TextStyle(
                    color: appTheme.gray_900,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CurrencyAmountPairText(
                primaryText: subtotalPrimary,
                secondaryText: subtotalSecondary,
                textAlign: TextAlign.right,
                primaryStyle: TextStyle(
                  color: subtotalColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                secondaryStyle: TextStyle(
                  color: subtotalColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              description,
              style: TextStyle(color: appTheme.blue_gray_700, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: appTheme.gray_200, height: 1),
          const SizedBox(height: 12),
          if (merchant.isNotEmpty)
            _ExpenseItemMetadata(
              icon: Icons.storefront_outlined,
              text: merchant,
            ),
          _ExpenseItemMetadata(
            icon: Icons.schedule_outlined,
            text: item.expenseDateTimeText,
          ),
          _ExpenseItemMetadata(
            icon: Icons.calculate_outlined,
            text: '${item.quantity} × $unitPricePrimary',
            secondaryText: unitPriceSecondary == null
                ? null
                : '${item.quantity} × $unitPriceSecondary',
            textColor: item.unitPrice < 0 ? appTheme.errorRed : null,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ExpenseItemMetadata extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? secondaryText;
  final Color? textColor;
  final bool isLast;

  const _ExpenseItemMetadata({
    required this.icon,
    required this.text,
    this.secondaryText,
    this.textColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor ?? appTheme.blue_gray_700),
          const SizedBox(width: 8),
          Expanded(
            child: secondaryText == null
                ? Text(
                    text,
                    style: TextStyle(
                      color: textColor ?? appTheme.blue_gray_700,
                      fontSize: 13,
                    ),
                  )
                : _CurrencyAmountPairText(
                    primaryText: text,
                    secondaryText: secondaryText,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textAlign: TextAlign.left,
                    primaryStyle: TextStyle(
                      color: textColor ?? appTheme.blue_gray_700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    secondaryStyle: TextStyle(
                      color: textColor ?? appTheme.blue_gray_700,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseItemsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ExpenseItemsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appTheme.gray_50_02,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: appTheme.errorRed),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _DashboardDetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? secondaryText;
  final Color? textColor;

  const _DashboardDetailLine({
    required this.icon,
    required this.text,
    this.secondaryText,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: textColor ?? appTheme.blue_gray_700),
        const SizedBox(width: 8),
        Expanded(
          child: secondaryText == null
              ? Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor ?? appTheme.blue_gray_700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : _CurrencyAmountPairText(
                  primaryText: text,
                  secondaryText: secondaryText,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textAlign: TextAlign.left,
                  primaryStyle: TextStyle(
                    color: textColor ?? appTheme.gray_900,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  secondaryStyle: TextStyle(
                    color: textColor ?? appTheme.blue_gray_700,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
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
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final primaryAmountText = viewModel.formatPrimaryMoney(amount);
    final secondaryAmountText = viewModel.formatSecondaryMoney(amount);
    final amountColor = amount < 0 ? appTheme.errorRed : appTheme.white_A700;
    return SizedBox(
      height: secondaryAmountText == null ? 42 : 56,
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
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: appTheme.white_A700,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 126,
            child: _CurrencyAmountPairText(
              primaryText: primaryAmountText,
              secondaryText: secondaryAmountText,
              primaryStyle: _amountStyle.copyWith(color: amountColor),
              secondaryStyle: TextStyle(
                color: amount < 0
                    ? appTheme.errorRed
                    : appTheme.white_A700.withValues(alpha: 0.88),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
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
        ? appTheme.expenseOverspendText
        : appTheme.teal_800;
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
              color: appTheme.blue_gray_700,
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
          style: TextStyle(
            color: appTheme.gray_800,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
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
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final primaryAmountText = viewModel.formatPrimaryMoney(
      amount,
      compact: true,
    );
    final secondaryAmountText = viewModel.formatSecondaryMoney(
      amount,
      compact: true,
    );
    final textColor = amount < 0
        ? appTheme.errorRed
        : amount == 0
        ? appTheme.blue_gray_700
        : color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CurrencyAmountPairText(
          primaryText: primaryAmountText,
          secondaryText: secondaryAmountText,
          textAlign: TextAlign.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          primaryStyle: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          secondaryStyle: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 12,
          height: height,
          decoration: BoxDecoration(
            color: amount < 0 ? appTheme.errorRed : color,
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
        Text(
          label,
          style: TextStyle(
            color: appTheme.blue_gray_700,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
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
          Text(
            label,
            style: TextStyle(
              color: appTheme.blue_gray_700,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
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
              percentage: category.budget == 0 ? 0 : 100,
              color: appTheme.blue_gray_700,
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
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final primaryAmountText = viewModel.formatPrimaryMoney(
      amount,
      compact: true,
    );
    final secondaryAmountText = viewModel.formatSecondaryMoney(
      amount,
      compact: true,
    );
    final effectiveColor = amount < 0 ? appTheme.errorRed : color;
    return Expanded(
      child: Column(
        children: [
          _CurrencyAmountPairText(
            primaryText: primaryAmountText,
            secondaryText: secondaryAmountText,
            textAlign: TextAlign.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            primaryStyle: TextStyle(
              color: effectiveColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            secondaryStyle: TextStyle(
              color: effectiveColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PastTripFilter { all, completed, terminated }

class _CompletedTripDialog extends StatefulWidget {
  const _CompletedTripDialog();

  @override
  State<_CompletedTripDialog> createState() => _CompletedTripDialogState();
}

class _CompletedTripDialogState extends State<_CompletedTripDialog> {
  final TextEditingController _searchController = TextEditingController();
  _PastTripFilter _statusFilter = _PastTripFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DashboardTripUiState> _filteredTrips(List<DashboardTripUiState> trips) {
    final query = _searchController.text.trim().toLowerCase();
    return trips.where((trip) {
      final status = trip.status.toLowerCase();
      final matchesStatus = switch (_statusFilter) {
        _PastTripFilter.all => true,
        _PastTripFilter.completed => status == 'completed',
        _PastTripFilter.terminated => status == 'terminated',
      };
      final matchesSearch =
          query.isEmpty ||
          trip.destination.toLowerCase().contains(query) ||
          trip.tripId.toLowerCase().contains(query) ||
          trip.travelPreference.toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  String get _filterTooltip => switch (_statusFilter) {
    _PastTripFilter.all => 'Filter trips',
    _PastTripFilter.completed => 'Showing completed trips',
    _PastTripFilter.terminated => 'Showing terminated trips',
  };

  String get _filterLabel => switch (_statusFilter) {
    _PastTripFilter.all => 'All trips',
    _PastTripFilter.completed => 'Completed',
    _PastTripFilter.terminated => 'Terminated',
  };

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final uiState = viewModel.uiState;
    final filteredTrips = _filteredTrips(uiState.completedTrips);
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
              padding: const EdgeInsets.fromLTRB(24, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Trip',
                      style: TextStyle(
                        color: appTheme.warningPopupHeader,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: appTheme.gray_900),
                  ),
                ],
              ),
            ),
            Divider(color: appTheme.gray_200, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        color: appTheme.gray_900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search trips',
                        hintStyle: TextStyle(
                          color: appTheme.gray_400,
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _searchController.text.trim().isEmpty
                              ? appTheme.blue_gray_300
                              : appTheme.teal_A700,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: appTheme.blue_gray_300,
                                  size: 18,
                                ),
                              ),
                        filled: true,
                        fillColor: appTheme.white_A700,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: appTheme.gray_200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: appTheme.teal_A700,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<_PastTripFilter>(
                    tooltip: _filterTooltip,
                    initialValue: _statusFilter,
                    onSelected: (filter) {
                      setState(() => _statusFilter = filter);
                    },
                    color: appTheme.white_A700,
                    surfaceTintColor: appTheme.white_A700,
                    elevation: 8,
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 6),
                    constraints: const BoxConstraints(
                      minWidth: 150,
                      maxWidth: 170,
                    ),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: appTheme.gray_200),
                    ),
                    itemBuilder: (context) => _PastTripFilter.values
                        .map(
                          (filter) => PopupMenuItem<_PastTripFilter>(
                            value: filter,
                            height: 44,
                            padding: EdgeInsets.zero,
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              color: filter == _statusFilter
                                  ? appTheme.gray_200
                                  : appTheme.white_A700,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      switch (filter) {
                                        _PastTripFilter.all => 'All trips',
                                        _PastTripFilter.completed =>
                                          'Completed',
                                        _PastTripFilter.terminated =>
                                          'Terminated',
                                      },
                                      style: TextStyle(
                                        color: appTheme.gray_900,
                                        fontSize: 12,
                                        fontWeight: filter == _statusFilter
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (filter == _statusFilter)
                                    Icon(
                                      Icons.check_rounded,
                                      size: 17,
                                      color: appTheme.teal_A700,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: appTheme.white_A700,
                        border: Border.all(color: appTheme.gray_200),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: appTheme.black_900_0c,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _filterLabel,
                            style: TextStyle(
                              color: appTheme.teal_800,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: appTheme.teal_A700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                  ? const Center(
                      child: Text('No completed or terminated trips found.'),
                    )
                  : filteredTrips.isEmpty
                  ? const Center(
                      child: Text('No trips match your search or filter.'),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        itemCount: filteredTrips.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 24),
                        itemBuilder: (context, index) => _CompletedTripCard(
                          trip: filteredTrips[index],
                          onSelected: () =>
                              Navigator.pop(context, filteredTrips[index]),
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
    final isTerminated = trip.status.toLowerCase() == 'terminated';
    final viewModel = context.watch<FinancialDashboardViewModel>();
    final primaryBudgetText = viewModel.formatPrimaryMoney(trip.totalBudget);
    final secondaryBudgetText = viewModel.formatSecondaryMoney(
      trip.totalBudget,
    );
    final budgetColor = trip.totalBudget < 0
        ? appTheme.errorRed
        : appTheme.blueGray900;
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
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isTerminated
                        ? appTheme.wholeAlertBudgetBg
                        : appTheme.white_A700.withValues(alpha: 0.90),
                    border: Border.all(
                      color: isTerminated
                          ? appTheme.wholeAlertBudgetStroke
                          : appTheme.gray_200,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTerminated
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline,
                        color: isTerminated
                            ? appTheme.errorRed
                            : appTheme.blue_gray_700,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isTerminated ? 'Terminated' : 'Completed',
                        style: TextStyle(
                          color: isTerminated
                              ? appTheme.errorRed
                              : appTheme.blue_gray_700,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
                    SizedBox(
                      width: 112,
                      child: _CurrencyAmountPairText(
                        primaryText: primaryBudgetText,
                        secondaryText: secondaryBudgetText,
                        primaryStyle: TextStyle(
                          color: budgetColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        secondaryStyle: TextStyle(
                          color: trip.totalBudget < 0
                              ? appTheme.errorRed
                              : appTheme.blue_gray_700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
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
    final availableDates = [...uiState.availableDates]..sort();
    final selectedDateIsAvailable = availableDates.any(
      (date) => DateUtils.isSameDay(date, uiState.selectedDate),
    );
    final initialDate = selectedDateIsAvailable || availableDates.isEmpty
        ? uiState.selectedDate
        : availableDates.first;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: appTheme.white_A700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select date',
                    style: TextStyle(
                      color: appTheme.gray_900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    intl.DateFormat('EEE, MMM d').format(initialDate),
                    style: TextStyle(
                      color: appTheme.gray_900,
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: appTheme.gray_200, height: 1),
            if (uiState.isLoadingAvailableDates)
              const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (uiState.availableDatesErrorMessage != null)
              SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          uiState.availableDatesErrorMessage!,
                          textAlign: TextAlign.center,
                        ),
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
            else if (availableDates.isEmpty)
              const SizedBox(
                height: 300,
                child: Center(child: Text('No available dates for this trip.')),
              )
            else
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: appTheme.teal_A700,
                    onPrimary: appTheme.white_A700,
                    surface: appTheme.white_A700,
                    onSurface: appTheme.gray_900,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: initialDate,
                  firstDate: availableDates.first,
                  lastDate: availableDates.last,
                  selectableDayPredicate: (date) => availableDates.any(
                    (availableDate) => DateUtils.isSameDay(availableDate, date),
                  ),
                  onDateChanged: (date) => Navigator.pop(context, date),
                ),
              ),
            Divider(color: appTheme.gray_200, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: appTheme.teal_A700,
                    foregroundColor: appTheme.white_A700,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
