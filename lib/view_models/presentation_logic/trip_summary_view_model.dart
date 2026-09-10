import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/services/financial_dashboard_service.dart';
import '../../models/services/i_auth_service.dart';
import '../../models/services/i_itinerary_service.dart';
import '../ui_state/trip_summary_ui_state.dart';

export '../ui_state/trip_summary_ui_state.dart';

class TripSummaryViewModel extends ChangeNotifier {
  static const double _unhealthyAllocatedOverrunRatio = 0.05;

  final String tripId;
  final IFinancialDashboardService _service;
  final IAuthService _authService;
  int _currencyConversionRequest = 0;
  bool _isDisposed = false;

  TripSummaryUiState _uiState = const TripSummaryUiState();

  TripSummaryViewModel({
    required this.tripId,
    required IAuthService authService,
    IFinancialDashboardService? service,
  }) : _service = service ?? FinancialDashboardService(),
       _authService = authService {
    _authService.addListener(_handleAuthUserChanged);
    _uiState = _uiState.copyWith(
      preferredCurrency: _normalizeCurrency(_authService.preferredCurrency),
    );
  }

  TripSummaryUiState get uiState => _uiState;

  void _handleAuthUserChanged() {
    unawaited(_refreshCurrencyConversion());
  }

  @override
  void dispose() {
    _isDisposed = true;
    _currencyConversionRequest++;
    _authService.removeListener(_handleAuthUserChanged);
    super.dispose();
  }

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
          financialHealth: _healthLabel(
            allocatedBudget: allocatedBudget,
            totalExpense: expense,
          ),
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
        unawaited(_refreshCurrencyConversion());
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

  String _healthLabel({
    required double allocatedBudget,
    required double totalExpense,
  }) {
    if (allocatedBudget <= 0) {
      return totalExpense > 0 ? 'Unhealthy' : 'Healthy';
    }
    final allocatedOverrunRatio =
        (totalExpense - allocatedBudget) / allocatedBudget;
    return allocatedOverrunRatio > _unhealthyAllocatedOverrunRatio
        ? 'Unhealthy'
        : 'Healthy';
  }

  String _formatMoney(double amount) {
    final absolute = NumberFormat('#,##0.00').format(amount.abs());
    return amount < 0 ? 'RM -$absolute' : 'RM $absolute';
  }

  String formatMoney(double amount, {bool compact = false}) {
    return _formatCurrencyAmount(amount, 'MYR', compact: compact);
  }

  String? formatPreferredMoney(double amount, {bool compact = false}) {
    final preferredCurrency = _uiState.preferredCurrency;
    if (preferredCurrency == 'MYR') return null;
    final rate = _uiState.preferredCurrencyRates['MYR'];
    if (rate == null && amount != 0) return null;
    return _formatCurrencyAmount(
      amount == 0 ? 0 : amount * rate!,
      preferredCurrency,
      compact: compact,
    );
  }

  String formatMoneyPair(double amount, {bool compact = false}) {
    final primary = formatPrimaryMoney(amount, compact: compact);
    final secondary = formatSecondaryMoney(amount, compact: compact);
    return secondary == null ? primary : '$primary\n≈ $secondary';
  }

  String formatPrimaryMoney(double amount, {bool compact = false}) {
    final preferred = formatPreferredMoney(amount, compact: compact);
    return preferred ?? formatMoney(amount, compact: compact);
  }

  String? formatSecondaryMoney(double amount, {bool compact = false}) {
    final preferred = formatPreferredMoney(amount, compact: compact);
    if (preferred == null) return null;
    return formatMoney(amount, compact: compact);
  }

  String formatDisplayMoney(double amount, {bool compact = false}) {
    return formatPrimaryMoney(amount, compact: compact);
  }

  Future<void> retryCurrencyConversion() => _refreshCurrencyConversion();

  Future<void> _refreshCurrencyConversion() async {
    final request = ++_currencyConversionRequest;
    final preferredCurrency = _normalizeCurrency(
      _authService.preferredCurrency,
    );
    if (preferredCurrency == 'MYR') {
      _uiState = _uiState.copyWith(
        isConvertingCurrency: false,
        preferredCurrency: preferredCurrency,
        preferredCurrencyRates: const {},
        clearCurrencyConversionError: true,
      );
      if (!_isDisposed) notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isConvertingCurrency: true,
      preferredCurrency: preferredCurrency,
      preferredCurrencyRates: const {},
      clearCurrencyConversionError: true,
    );
    if (!_isDisposed) notifyListeners();

    try {
      final rate = await _authService.convertToPreferredCurrency(
        amount: 1,
        fromCurrency: 'MYR',
      );
      if (_isDisposed || request != _currencyConversionRequest) return;
      _uiState = _uiState.copyWith(
        isConvertingCurrency: false,
        preferredCurrencyRates: rate == null
            ? const {}
            : Map.unmodifiable({'MYR': rate}),
        currencyConversionErrorMessage: rate == null
            ? 'The exchange rate for $preferredCurrency is unavailable.'
            : null,
        clearCurrencyConversionError: rate != null,
      );
    } catch (_) {
      if (_isDisposed || request != _currencyConversionRequest) return;
      _uiState = _uiState.copyWith(
        isConvertingCurrency: false,
        preferredCurrencyRates: const {},
        currencyConversionErrorMessage:
            'Unable to convert amounts to $preferredCurrency.',
      );
    }
    notifyListeners();
  }

  String _formatCurrencyAmount(
    double amount,
    String currency, {
    required bool compact,
  }) {
    final pattern = compact ? '#,##0' : '#,##0.00';
    final absolute = NumberFormat(pattern).format(amount.abs());
    final currencyLabel = currency == 'MYR' ? 'RM' : currency;
    return amount < 0
        ? '$currencyLabel -$absolute'
        : '$currencyLabel $absolute';
  }

  String _normalizeCurrency(String currency) {
    final normalized = currency.trim().toUpperCase();
    return normalized.isEmpty || normalized == 'RM' ? 'MYR' : normalized;
  }
}

class HealthDonutPainter extends CustomPainter {
  final bool showActualBudget;
  final double actualBudgetProgress;
  final double allocatedBudgetProgress;
  final double expenseProgress;
  final Color actualBudgetColor;
  final Color allocatedBudgetColor;
  final Color expenseColor;
  final Color backgroundColor;

  const HealthDonutPainter({
    required this.showActualBudget,
    required this.actualBudgetProgress,
    required this.allocatedBudgetProgress,
    required this.expenseProgress,
    required this.actualBudgetColor,
    required this.allocatedBudgetColor,
    required this.expenseColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 7;

    if (showActualBudget) {
      _drawRing(
        canvas: canvas,
        center: center,
        radius: outerRadius,
        progress: actualBudgetProgress,
        color: actualBudgetColor,
      );
    }
    _drawRing(
      canvas: canvas,
      center: center,
      radius: showActualBudget ? outerRadius - 15 : outerRadius - 8,
      progress: allocatedBudgetProgress,
      color: allocatedBudgetColor,
    );
    _drawRing(
      canvas: canvas,
      center: center,
      radius: showActualBudget ? outerRadius - 30 : outerRadius - 27,
      progress: expenseProgress,
      color: expenseColor,
    );
  }

  void _drawRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double progress,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      paint..color = backgroundColor,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant HealthDonutPainter oldDelegate) {
    return oldDelegate.showActualBudget != showActualBudget ||
        oldDelegate.actualBudgetProgress != actualBudgetProgress ||
        oldDelegate.allocatedBudgetProgress != allocatedBudgetProgress ||
        oldDelegate.expenseProgress != expenseProgress ||
        oldDelegate.actualBudgetColor != actualBudgetColor ||
        oldDelegate.allocatedBudgetColor != allocatedBudgetColor ||
        oldDelegate.expenseColor != expenseColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
