import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FinancialDashboardScreen extends StatelessWidget {
  final VoidCallback? onHomeSelected;

  const FinancialDashboardScreen({super.key, this.onHomeSelected});

  static final _categories = [
    _CategoryBudget(
      name: 'Food',
      budget: 300,
      expense: 150,
      color: appTheme.teal_50,
    ),
    _CategoryBudget(
      name: 'Attraction',
      budget: 500,
      expense: 250,
      color: appTheme.teal_A700,
    ),
    _CategoryBudget(
      name: 'Transport',
      budget: 200,
      expense: 300,
      color: appTheme.teal_800,
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
                    _buildSummaryCard(),
                    const SizedBox(height: 18),
                    _buildDateFilter(context),
                    const SizedBox(height: 34),
                    _buildCategoryChart(),
                    const SizedBox(height: 26),
                    _buildExpenseChart(),
                    const SizedBox(height: 24),
                    _buildBreakdownCard(),
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
            child: Icon(
              Icons.person,
              color: appTheme.blue_gray_300,
              size: 24,
            ),
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

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: appTheme.teal_A700,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const _SummaryRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total Allocated Budget',
            amount: 'RM1000',
          ),
          Divider(
            color: appTheme.white_A700.withValues(alpha: 0.33),
            height: 1,
          ),
          const _SummaryRow(
            icon: Icons.south_west,
            label: 'Total Expense',
            amount: 'RM600',
          ),
          Divider(
            color: appTheme.white_A700.withValues(alpha: 0.33),
            height: 1,
          ),
          const _SummaryRow(
            icon: Icons.shield_outlined,
            label: 'Total Remain Budget',
            amount: 'RM400',
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'From 14 Dec, 2026',
          style: TextStyle(color: appTheme.gray_400, fontSize: 18),
        ),
        PopupMenuButton<_DashboardFilter>(
          onSelected: (filter) {
            if (filter == _DashboardFilter.byDate) {
              _showAvailableDateDialog(context);
            } else {
              _showCompletedTripDialog(context);
            }
          },
          color: appTheme.white_A700,
          elevation: 3,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _DashboardFilter.byDate,
              child: Text('By Date'),
            ),
            PopupMenuItem(
              value: _DashboardFilter.byTrip,
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
                Text(
                  'Filter',
                  style: TextStyle(color: appTheme.teal_A700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAvailableDateDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: appTheme.gray_900.withValues(alpha: 0.25),
      builder: (context) => const _AvailableDateDialog(),
    );
  }

  Future<void> _showCompletedTripDialog(BuildContext context) async {
    final selectedTrip = await showDialog<_CompletedTripPreview>(
      context: context,
      barrierColor: appTheme.gray_900.withValues(alpha: 0.25),
      builder: (context) => const _CompletedTripDialog(),
    );

    if (selectedTrip != null && context.mounted) {
      Navigator.pushNamed(context, '/tripSummaryScreen');
    }
  }

  Widget _buildCategoryChart() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: CustomPaint(
            size: const Size(double.infinity, 160),
            painter: _DonutChartPainter(_categories),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: _categories
              .map(
                (item) => _LegendChip(
                  label: item.name,
                  color: item.color,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildExpenseChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Expense', style: TextStyle(fontSize: 15)),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _categories
                .map((item) => _ExpenseBars(category: item))
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
            _DotLegend(label: 'Overspending', color: appTheme.expenseOverspendBg),
          ],
        ),
      ],
    );
  }

  Widget _buildBreakdownCard() {
    final orderedCategories = _categories.reversed.toList();
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ColumnHeading(color: AppThemeData.expenseBg, label: 'Budget'),
              _ColumnHeading(color: appTheme.warningPopupHeader, label: 'Expense'),
              _ColumnHeading(color: appTheme.teal_A700, label: 'Remaining'),
              _ColumnHeading(color: appTheme.errorRed, label: 'Overspend'),
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
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;

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
          Text(
            amount,
            style: TextStyle(
              color: appTheme.white_A700,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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
  final _CategoryBudget category;

  const _ExpenseBars({required this.category});

  @override
  Widget build(BuildContext context) {
    final expenseColor = category.isOverspent
        ? appTheme.expenseOverspendBg
        : appTheme.gray_200;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 8,
              height: 90 * category.budget / 500,
              color: appTheme.teal_800,
            ),
            const SizedBox(width: 7),
            Container(
              width: 8,
              height: 90 * category.expense / 500,
              color: expenseColor,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          category.name,
          style: TextStyle(color: appTheme.gray_400, fontSize: 12),
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
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: appTheme.gray_400, fontSize: 10)),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final _CategoryBudget category;

  const _BreakdownRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final remaining = category.budget - category.expense;
    final percentage = category.expense / category.budget * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: category.color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 9),
            Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (category.isOverspent) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: appTheme.wholeAlertBudgetBg,
                  border: Border.all(color: appTheme.wholeAlertBudgetStroke),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Overspend', style: TextStyle(color: appTheme.errorRed, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MoneyCell(amount: category.budget, percentage: 100, color: appTheme.gray_400),
            _MoneyCell(amount: category.expense, percentage: percentage, color: appTheme.warningPopupHeader),
            _MoneyCell(amount: remaining, percentage: 100 - percentage, color: remaining < 0 ? appTheme.errorRed : appTheme.teal_A700),
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

  const _MoneyCell({required this.amount, required this.percentage, required this.color});

  @override
  Widget build(BuildContext context) {
    final sign = amount < 0 ? '-' : '';
    return Expanded(
      child: Column(
        children: [
          Text('$sign RM ${amount.abs().toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<_CategoryBudget> categories;

  const _DonutChartPainter(this.categories);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 62.0;
    const strokeWidth = 24.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = categories.fold<double>(0, (sum, item) => sum + item.budget);
    var startAngle = -math.pi / 2;

    for (final category in categories) {
      final sweep = math.pi * 2 * category.budget / total;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = category.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );

      final middleAngle = startAngle + sweep / 2;
      final labelPosition = center + Offset(math.cos(middleAngle), math.sin(middleAngle)) * 94;
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'RM${category.budget.toStringAsFixed(0)}',
          style: TextStyle(color: appTheme.gray_900, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, labelPosition - Offset(textPainter.width / 2, textPainter.height / 2));
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => false;
}

enum _DashboardFilter { byDate, byTrip }

class _CompletedTripDialog extends StatelessWidget {
  const _CompletedTripDialog();

  static const _completedTrips = [
    _CompletedTripPreview(
      title: 'Kyoto Autumn Retreat',
      budget: 'RM2,450',
      dateRange: 'Oct 12 - Oct 19, 2023',
      travelers: '2 Travelers',
      description:
          'A serene 7-day journey exploring historic temples, traditional tea houses, and the bamboo forest.',
      imageUrl:
          'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=900&q=80',
    ),
    _CompletedTripPreview(
      title: 'Icelandic Ring Road',
      budget: 'RM3,120',
      dateRange: 'Mar 5 - Mar 15, 2023',
      travelers: 'Road Trip',
      description:
          'An unforgettable road trip through waterfalls, glaciers, hot springs, and northern lights.',
      imageUrl:
          'https://images.unsplash.com/photo-1504893524553-b855bce32c67?auto=format&fit=crop&w=900&q=80',
    ),
    _CompletedTripPreview(
      title: 'Bali Island Escape',
      budget: 'RM1,980',
      dateRange: 'Jun 8 - Jun 13, 2022',
      travelers: '3 Travelers',
      description:
          'A relaxing tropical break filled with beaches, local food, rice terraces, and cultural sights.',
      imageUrl:
          'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=900&q=80',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 48),
      backgroundColor: appTheme.white_A700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 380, maxHeight: screenHeight * 0.82),
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
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  itemCount: _completedTrips.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 24),
                  itemBuilder: (context, index) => _CompletedTripCard(
                    trip: _completedTrips[index],
                    onSelected: () =>
                        Navigator.pop(context, _completedTrips[index]),
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
  final _CompletedTripPreview trip;
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
              Image.network(
                trip.imageUrl,
                width: double.infinity,
                height: 190,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildImagePlaceholder();
                },
                errorBuilder: (context, error, stackTrace) =>
                    _buildImagePlaceholder(),
              ),
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
                        trip.title,
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
                      trip.budget,
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
                      label: trip.dateRange,
                    ),
                    _TripInformationChip(
                      icon: Icons.group_outlined,
                      label: trip.travelers,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  trip.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
              child: _AvailableDateCalendar(today: DateTime.now()),
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
  final DateTime today;

  const _AvailableDateCalendar({required this.today});

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(today.year, today.month);
    final daysInMonth = DateUtils.getDaysInMonth(today.year, today.month);
    final leadingEmptyCells = firstDay.weekday % 7;
    final totalCells = leadingEmptyCells + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

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
          Text(
            '${_monthNames[today.month - 1]} ${today.year}',
            style: TextStyle(
              color: appTheme.gray_900,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _weekdays
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
                      : _buildDay(day),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildDay(int day) {
    final isToday = day == today.day;
    final hasRecord = day <= today.day && !{5, 6, 7}.contains(day);
    final backgroundColor = isToday
        ? appTheme.wholeGoodBudgetProgress
        : hasRecord
        ? appTheme.transparentCustom
        : appTheme.gray_200;
    final textColor = isToday
        ? appTheme.white_A700
        : hasRecord
        ? appTheme.gray_900
        : appTheme.gray_400;

    return Center(
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$day',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _CategoryBudget {
  final String name;
  final double budget;
  final double expense;
  final Color color;

  const _CategoryBudget({required this.name, required this.budget, required this.expense, required this.color});

  bool get isOverspent => expense > budget;
}

class _CompletedTripPreview {
  final String title;
  final String budget;
  final String dateRange;
  final String travelers;
  final String description;
  final String imageUrl;

  const _CompletedTripPreview({
    required this.title,
    required this.budget,
    required this.dateRange,
    required this.travelers,
    required this.description,
    required this.imageUrl,
  });
}
