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
    _uiState = _uiState.copyWith(
      isLoading: true,
      clearError: true,
      isFutureRecommendationsExpanded: false,
      isLoadingFutureRecommendations: false,
      isSavingFutureRecommendations: false,
      hasAdjustedFutureRecommendations: false,
      areFutureRecommendationsSaved: false,
      clearFutureRecommendationsError: true,
      futureRecommendations: const [],
    );
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
        final actualBudget = summary.trip.totalBudget;
        final topUpBudget = summary.totalTopUpBudget;
        final allocatedBudget = math
            .max(0.0, actualBudget - topUpBudget)
            .toDouble();
        final expense = summary.totalExpense;
        final rawPercentage = actualBudget <= 0
            ? 0.0
            : expense / actualBudget * 100;

        _uiState = _uiState.copyWith(
          isLoading: false,
          hasTrip: true,
          tripId: summary.trip.tripId ?? tripId,
          destination: summary.trip.destination,
          startDate: summary.trip.startDate,
          endDate: summary.trip.endDate,
          allocatedBudget: allocatedBudget,
          allocatedBudgetText: _formatMoney(allocatedBudget),
          topUpBudget: topUpBudget,
          topUpBudgetText: _formatMoney(topUpBudget),
          actualBudget: actualBudget,
          actualBudgetText: _formatMoney(actualBudget),
          totalExpense: expense,
          totalExpenseText: _formatMoney(expense),
          remainingBudget: actualBudget - expense,
          remainingBudgetText: _formatMoney(actualBudget - expense),
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
        unawaited(loadCostSavingTips());
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
        allocatedBudget: _uiState.actualBudget,
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

  Future<void> toggleFutureRecommendations() async {
    final shouldExpand = !_uiState.isFutureRecommendationsExpanded;
    _uiState = _uiState.copyWith(isFutureRecommendationsExpanded: shouldExpand);
    notifyListeners();

    if (shouldExpand &&
        _uiState.futureRecommendations.isEmpty &&
        !_uiState.isLoadingFutureRecommendations) {
      await loadFutureBudgetRecommendations();
    }
  }

  Future<void> loadFutureBudgetRecommendations() async {
    if (!_uiState.hasTrip || _uiState.isLoadingFutureRecommendations) return;

    _uiState = _uiState.copyWith(
      isFutureRecommendationsExpanded: true,
      isLoadingFutureRecommendations: true,
      hasAdjustedFutureRecommendations: false,
      areFutureRecommendationsSaved: false,
      clearFutureRecommendationsError: true,
      futureRecommendations: const [],
    );
    notifyListeners();

    try {
      final savedRecommendations = await _service
          .getSavedFutureBudgetRecommendations(_uiState.tripId);
      if (savedRecommendations.isNotEmpty) {
        _uiState = _uiState.copyWith(
          isLoadingFutureRecommendations: false,
          areFutureRecommendationsSaved: true,
          futureRecommendations: savedRecommendations
              .map(_toFutureRecommendationUiState)
              .toList(),
        );
        notifyListeners();
        return;
      }

      final recommendations = await _service.getFutureBudgetRecommendations(
        destination: _uiState.destination,
        allocatedBudget: _uiState.actualBudget,
        totalExpense: _uiState.totalExpense,
        categoryExpenses: {
          for (final category in _uiState.categories)
            category.name: category.expense,
        },
      );
      _uiState = _uiState.copyWith(
        isLoadingFutureRecommendations: false,
        futureRecommendations: recommendations
            .map(_toFutureRecommendationUiState)
            .toList(),
      );
    } on TimeoutException {
      _uiState = _uiState.copyWith(
        isLoadingFutureRecommendations: false,
        futureRecommendationsErrorMessage:
            'Connection timed out. Please try again.',
      );
    } on FutureBudgetRecommendationsRateLimitException {
      _uiState = _uiState.copyWith(
        isLoadingFutureRecommendations: false,
        futureRecommendationsErrorMessage:
            'Gemini request limit reached. Please try again later.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoadingFutureRecommendations: false,
        futureRecommendationsErrorMessage:
            'Unable to load future budget recommendations. Please try again.',
      );
    }
    notifyListeners();
  }

  void updateFutureRecommendationPercentage(
    String category,
    double percentage,
  ) {
    if (_uiState.areFutureRecommendationsSaved) return;

    final recommendations = _uiState.futureRecommendations
        .map(
          (recommendation) => recommendation.category == category
              ? recommendation.copyWith(
                  selectedPercentage: percentage.roundToDouble().clamp(
                    recommendation.minimumPercentage,
                    recommendation.maximumPercentage,
                  ),
                )
              : recommendation,
        )
        .toList();
    final hasAdjusted = recommendations.any(
      (recommendation) =>
          (recommendation.selectedPercentage - recommendation.aiPercentage)
              .abs() >
          0.001,
    );

    _uiState = _uiState.copyWith(
      futureRecommendations: recommendations,
      hasAdjustedFutureRecommendations: hasAdjusted,
      areFutureRecommendationsSaved: false,
      clearFutureRecommendationsError: true,
    );
    notifyListeners();
  }

  double get futureRecommendationTotal => _uiState.futureRecommendations.fold(
    0,
    (total, recommendation) => total + recommendation.selectedPercentage,
  );

  Future<FutureRecommendationAcceptResult>
  acceptFutureBudgetRecommendations() async {
    if (_uiState.futureRecommendations.isEmpty ||
        _uiState.isSavingFutureRecommendations ||
        _uiState.areFutureRecommendationsSaved) {
      return FutureRecommendationAcceptResult.failed;
    }

    final percentages = {
      for (final recommendation in _uiState.futureRecommendations)
        recommendation.category: recommendation.selectedPercentage,
    };
    final isValid = _service.hasValidFutureRecommendationTotal(percentages);
    if (_uiState.hasAdjustedFutureRecommendations && !isValid) {
      return FutureRecommendationAcceptResult.invalidTotal;
    }
    if (!isValid) return FutureRecommendationAcceptResult.failed;

    _uiState = _uiState.copyWith(
      isSavingFutureRecommendations: true,
      clearFutureRecommendationsError: true,
    );
    notifyListeners();

    try {
      await _service.saveFutureBudgetRecommendations(
        tripId: _uiState.tripId,
        percentages: percentages,
      );
      _uiState = _uiState.copyWith(
        isSavingFutureRecommendations: false,
        areFutureRecommendationsSaved: true,
      );
      notifyListeners();
      return FutureRecommendationAcceptResult.saved;
    } on TimeoutException {
      _uiState = _uiState.copyWith(
        isSavingFutureRecommendations: false,
        futureRecommendationsErrorMessage:
            'Saving timed out. Please try again.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isSavingFutureRecommendations: false,
        futureRecommendationsErrorMessage:
            'Unable to save future budget recommendations. Please try again.',
      );
    }
    notifyListeners();
    return FutureRecommendationAcceptResult.failed;
  }

  FutureBudgetRecommendationUiState _toFutureRecommendationUiState(
    FutureBudgetRecommendation recommendation,
  ) {
    return FutureBudgetRecommendationUiState(
      category: recommendation.category,
      aiPercentage: recommendation.percentage,
      selectedPercentage: recommendation.percentage,
      minimumPercentage: (recommendation.percentage - 5).clamp(0, 100),
      maximumPercentage: (recommendation.percentage + 5).clamp(0, 100),
    );
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
