import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/services/financial_dashboard_service.dart';
import '../ui_state/financial_dashboard_ui_state.dart';

class FinancialDashboardViewModel extends ChangeNotifier {
  final IFinancialDashboardService _service;

  FinancialDashboardUiState _uiState = FinancialDashboardUiState(
    selectedDate: DateTime.now(),
  );

  FinancialDashboardViewModel({IFinancialDashboardService? service})
    : _service = service ?? FinancialDashboardService();

  FinancialDashboardUiState get uiState => _uiState;

  Future<void> loadCurrentDay() => loadDate(DateTime.now());

  Future<void> loadDate(DateTime date) async {
    _uiState = _uiState.copyWith(
      isLoading: true,
      selectedDate: date,
      clearError: true,
    );
    notifyListeners();

    try {
      final summary = await _service.getCurrentDaySummary(date);
      if (summary == null) {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasCurrentTrip: false,
          destination: '',
          categories: const [],
        );
      } else {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasCurrentTrip: true,
          destination: summary.trip.destination,
          categories: summary.categories
              .map(
                (category) => DashboardCategoryUiState(
                  name: category.category,
                  budget: category.allocatedBudget,
                  expense: category.expense,
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
        errorMessage: 'Unable to load expenses. Please try again.',
      );
    }
    notifyListeners();
  }
}
