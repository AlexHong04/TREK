import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TripSummaryScreen extends StatefulWidget {
  const TripSummaryScreen({super.key});

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  bool _showRecommendations = false;
  double _attractionPercentage = 30;
  double _transportPercentage = 15;
  double _foodPercentage = 55;

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
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'From 14-20 Dec, 2026',
                style: TextStyle(color: appTheme.gray_400, fontSize: 14),
              ),
              const SizedBox(height: 34),
              _buildBudgetOverview(),
              const SizedBox(height: 28),
              _buildFinancialHealth(),
              const SizedBox(height: 12),
              _buildSpendingBreakdown(),
              const SizedBox(height: 28),
              _buildCostSavingTips(),
              const SizedBox(height: 22),
              _buildRecommendations(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetOverview() {
    return Row(
      children: [
        SizedBox(
          width: 148,
          height: 148,
          child: CustomPaint(
            painter: _HealthDonutPainter(
              progress: 0.8,
              progressColor: appTheme.teal_800,
              remainderColor: appTheme.teal_A700,
            ),
            child: Center(
              child: Text(
                '80%',
                style: TextStyle(
                  color: appTheme.gray_900,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: appTheme.white_A700,
              border: Border.all(color: appTheme.gray_200),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: _BudgetMetric(
                        amount: 'RM3500',
                        label: 'Allocated Budget',
                      ),
                    ),
                    Expanded(
                      child: _BudgetMetric(
                        amount: 'RM2800',
                        label: 'Expense',
                      ),
                    ),
                  ],
                ),
                Divider(color: appTheme.gray_200, height: 1),
                const _BudgetMetric(amount: 'RM700', label: 'Remain'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialHealth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Financial Health',
          style: TextStyle(color: appTheme.gray_900, fontSize: 15),
        ),
        const SizedBox(width: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: appTheme.wholeGoodBudgetBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: appTheme.wholeGoodBudgetProgress,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'Healthy',
                style: TextStyle(
                  color: appTheme.wholeGoodBudgetProgress,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingBreakdown() {
    const spending = [
      _SpendingBar('Attraction', 1225, 35),
      _SpendingBar('Food', 1750, 50),
      _SpendingBar('Transport', 525, 15),
    ];
    final colors = [
      appTheme.teal_A200,
      appTheme.teal_A700,
      appTheme.gray_400,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Spending Breakdown by Category',
            style: TextStyle(
              color: appTheme.gray_900,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 194,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              spending.length,
              (index) => _SpendingBarWidget(
                spending: spending[index],
                color: colors[index],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Highest Expenditure: Food (RM1750)',
            style: TextStyle(color: appTheme.gray_900, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCostSavingTips() {
    return _SectionCard(
      title: 'Cost-Saving Tips',
      child: Column(
        children: [
          _TipRow(
            icon: Icons.directions_bus_outlined,
            iconBackground: appTheme.teal_A200,
            title: 'Use Local Subway Pass',
            subtitle: 'Save 15% on Transport',
          ),
          const SizedBox(height: 10),
          _TipRow(
            icon: Icons.confirmation_number_outlined,
            iconBackground: appTheme.amber_200,
            title: 'Book Temple Tickets Online',
            subtitle: 'Pre-booking discounts available',
          ),
          const SizedBox(height: 10),
          _TipRow(
            icon: Icons.water_drop_outlined,
            iconBackground: AppThemeData.expenseBg,
            title: 'Drink More Water',
            subtitle: 'Since you very like eat spicy',
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return _SectionCard(
      title: 'Recommendations',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _showRecommendations
            ? Column(
                key: const ValueKey('recommendation-controls'),
                children: [
                  _RecommendationSlider(
                    label: 'Attraction',
                    value: _attractionPercentage,
                    minimum: 25,
                    maximum: 35,
                    onChanged: (value) =>
                        setState(() => _attractionPercentage = value),
                  ),
                  _RecommendationSlider(
                    label: 'Transport',
                    value: _transportPercentage,
                    minimum: 10,
                    maximum: 20,
                    onChanged: (value) =>
                        setState(() => _transportPercentage = value),
                  ),
                  _RecommendationSlider(
                    label: 'Food',
                    value: _foodPercentage,
                    minimum: 50,
                    maximum: 60,
                    onChanged: (value) =>
                        setState(() => _foodPercentage = value),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 248,
                    height: 42,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: appTheme.teal_A700,
                        foregroundColor: appTheme.white_A700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                key: const ValueKey('recommendation-button'),
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  onPressed: () => setState(() => _showRecommendations = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: appTheme.teal_A700,
                    foregroundColor: appTheme.white_A700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Get Future Budget Recommendations',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _BudgetMetric extends StatelessWidget {
  final String amount;
  final String label;

  const _BudgetMetric({required this.amount, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      child: Column(
        children: [
          Text(
            amount,
            style: TextStyle(color: appTheme.gray_900, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: appTheme.gray_900, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SpendingBarWidget extends StatelessWidget {
  final _SpendingBar spending;
  final Color color;

  const _SpendingBarWidget({required this.spending, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'RM${spending.amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: appTheme.gray_800,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          width: 60,
          height: 2.8 * spending.percentage,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '${spending.percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: appTheme.white_A700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          spending.label,
          style: TextStyle(color: appTheme.gray_400, fontSize: 12),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(5),
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
          Text(
            title,
            style: TextStyle(
              color: appTheme.gray_900,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final String title;
  final String subtitle;

  const _TipRow({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, color: appTheme.teal_800, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: appTheme.gray_900,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: appTheme.blue_gray_700, fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationSlider extends StatelessWidget {
  final String label;
  final double value;
  final double minimum;
  final double maximum;
  final ValueChanged<double> onChanged;

  const _RecommendationSlider({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Column(
            children: [
              Icon(Icons.account_balance_outlined, color: appTheme.gray_900),
              Text(label, style: TextStyle(color: appTheme.gray_900, fontSize: 11)),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: appTheme.teal_A700,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${value.round()}%',
            style: TextStyle(color: appTheme.white_A700, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${minimum.round()}%', style: const TextStyle(fontSize: 10)),
                  Text('${maximum.round()}%', style: const TextStyle(fontSize: 10)),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: appTheme.teal_800,
                  inactiveTrackColor: appTheme.gray_200,
                  thumbColor: appTheme.teal_A700,
                  trackHeight: 3,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: value,
                  min: minimum,
                  max: maximum,
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

class _HealthDonutPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color remainderColor;

  const _HealthDonutPainter({
    required this.progress,
    required this.progressColor,
    required this.remainderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 13;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      paint..color = remainderColor,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint..color = progressColor,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthDonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.remainderColor != remainderColor;
  }
}

class _SpendingBar {
  final String label;
  final double amount;
  final double percentage;

  const _SpendingBar(this.label, this.amount, this.percentage);
}
