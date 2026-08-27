import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/services/financial_dashboard_service.dart';
import '../ui_state/trip_summary_ui_state.dart';

export '../ui_state/trip_summary_ui_state.dart';

class TripSummaryViewModel extends ChangeNotifier {
  final String tripId;
  final IFinancialDashboardService _service;

  TripSummaryUiState _uiState = const TripSummaryUiState();

  TripSummaryViewModel({
    required this.tripId,
    IFinancialDashboardService? service,
  }) : _service = service ?? FinancialDashboardService();

  TripSummaryUiState get uiState => _uiState;

  Future<void> loadTripSummary() async {
    _uiState = _uiState.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final summary = await _service.getTripSummary(tripId);
      if (summary == null) {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasTrip: false,
          errorMessage: 'This trip could not be found.',
        );
      } else {
        final budget = summary.trip.totalBudget;
        final expense = summary.totalExpense;
        final rawPercentage = budget <= 0 ? 0.0 : expense / budget * 100;

        _uiState = _uiState.copyWith(
          isLoading: false,
          hasTrip: true,
          tripId: summary.trip.tripId ?? tripId,
          destination: summary.trip.destination,
          startDate: summary.trip.startDate,
          endDate: summary.trip.endDate,
          allocatedBudget: budget,
          allocatedBudgetText: _formatMoney(budget),
          totalExpense: expense,
          totalExpenseText: _formatMoney(expense),
          remainingBudget: budget - expense,
          remainingBudgetText: _formatMoney(budget - expense),
          spentPercentage: rawPercentage,
          financialHealth: _healthLabel(rawPercentage),
          categories: summary.categories
              .map(
                (category) => TripSummaryCategoryUiState(
                  name: category.category,
                  expense: category.expense,
                  expenseText: _formatMoney(category.expense),
                  percentage: expense <= 0
                      ? 0
                      : category.expense / expense * 100,
                ),
              )
              .toList(),
        );
        notifyListeners();
        await loadCostSavingTips();
        return;
      }
    } on TimeoutException {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Connection timed out. Please try again.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load the trip summary. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> loadCostSavingTips() async {
    if (!_uiState.hasTrip) return;

    _uiState = _uiState.copyWith(
      isLoadingCostSavingTips: true,
      clearCostSavingTipsError: true,
      costSavingTips: const [],
    );
    notifyListeners();

    try {
      final tips = await _service.getCostSavingTips(
        destination: _uiState.destination,
        allocatedBudget: _uiState.allocatedBudget,
        totalExpense: _uiState.totalExpense,
        remainingBudget: _uiState.remainingBudget,
        categoryExpenses: {
          for (final category in _uiState.categories)
            category.name: category.expense,
        },
      );
      _uiState = _uiState.copyWith(
        isLoadingCostSavingTips: false,
        costSavingTips: tips
            .map(
              (tip) => CostSavingTipUiState(
                category: tip.category,
                title: tip.title,
                description: tip.description,
              ),
            )
            .toList(),
      );
    } on TimeoutException {
      _uiState = _uiState.copyWith(
        isLoadingCostSavingTips: false,
        costSavingTipsErrorMessage: 'Connection timed out. Please try again.',
      );
    } on CostSavingTipsRateLimitException {
      _uiState = _uiState.copyWith(
        isLoadingCostSavingTips: false,
        costSavingTipsErrorMessage:
            'Gemini request limit reached. Please try again later.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoadingCostSavingTips: false,
        costSavingTipsErrorMessage:
            'Unable to load cost-saving tips. Please try again.',
      );
    }
    notifyListeners();
  }

  String _healthLabel(double spentPercentage) {
    if (spentPercentage > 100) return 'Overspent';
    if (spentPercentage > 80) return 'Warning';
    return 'Healthy';
  }

  String _formatMoney(double amount) {
    final absolute = NumberFormat('#,##0.00').format(amount.abs());
    return amount < 0 ? 'RM -$absolute' : 'RM $absolute';
  }
}

class HealthDonutPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color remainderColor;

  const HealthDonutPainter({
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
      ..strokeWidth = 24;

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
  bool shouldRepaint(covariant HealthDonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.remainderColor != remainderColor;
  }
}
