import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/services/financial_dashboard_service.dart';
import '../ui_state/trip_summary_ui_state.dart';

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
          totalExpense: expense,
          remainingBudget: budget - expense,
          spentPercentage: rawPercentage,
          financialHealth: _healthLabel(rawPercentage),
          categories: summary.categories
              .map(
                (category) => TripSummaryCategoryUiState(
                  name: category.category,
                  expense: category.expense,
                  percentage: expense <= 0
                      ? 0
                      : category.expense / expense * 100,
                ),
              )
              .toList(),
        );
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

  String _healthLabel(double spentPercentage) {
    if (spentPercentage > 100) return 'Overspent';
    if (spentPercentage > 80) return 'Warning';
    return 'Healthy';
  }
}
