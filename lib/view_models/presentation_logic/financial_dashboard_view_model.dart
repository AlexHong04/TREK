import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
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
          tripId: '',
          userId: '',
          destination: '',
          categories: const [],
        );
      } else {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasCurrentTrip: true,
          tripId: summary.trip.tripId ?? '',
          userId: summary.trip.userId ?? '',
          destination: summary.trip.destination,
          categories: summary.categories
              .map(
                (category) => DashboardCategoryUiState(
                  name: category.category,
                  budget: category.allocatedBudget,
                  expense: category.expense,
                  expenseDetails: category.expenseDetails
                      .map(
                        (detail) => DashboardExpenseDetailUiState(
                          activityName: detail.activityName,
                          activityImageUrl: detail.activityImageUrl,
                          timeText: _formatTime(detail.activityStartTime, date),
                          amount: detail.amount,
                          paymentMethod:
                              detail.paymentMethod?.trim().isNotEmpty == true
                              ? detail.paymentMethod!.trim()
                              : 'Payment method unavailable',
                        ),
                      )
                      .toList(),
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

  Future<void> loadAvailableDates() async {
    if (_uiState.userId.isEmpty) {
      _uiState = _uiState.copyWith(
        availableDatesErrorMessage: 'No user trip data is available.',
      );
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isLoadingAvailableDates: true,
      clearAvailableDatesError: true,
    );
    notifyListeners();

    try {
      final dates = await _service.getAvailableDates(_uiState.userId);
      _uiState = _uiState.copyWith(
        isLoadingAvailableDates: false,
        availableDates: dates,
      );
    } on TimeoutException {
      _uiState = _uiState.copyWith(
        isLoadingAvailableDates: false,
        availableDatesErrorMessage: 'Connection timed out. Please try again.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoadingAvailableDates: false,
        availableDatesErrorMessage:
            'Unable to load available dates. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> loadCompletedTrips() async {
    if (_uiState.userId.isEmpty) {
      _uiState = _uiState.copyWith(
        completedTripsErrorMessage: 'No user trip data is available.',
      );
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isLoadingCompletedTrips: true,
      clearCompletedTripsError: true,
    );
    notifyListeners();

    try {
      final trips = await _service.getCompletedTrips(_uiState.userId);
      _uiState = _uiState.copyWith(
        isLoadingCompletedTrips: false,
        completedTrips: trips
            .map(
              (trip) => DashboardTripUiState(
                tripId: trip.tripId ?? '',
                destination: trip.destination,
                imageUrl: trip.imgUrl ?? '',
                startDate: trip.startDate,
                endDate: trip.endDate,
                totalBudget: trip.totalBudget,
                travelPreference: trip.travelPreference,
              ),
            )
            .toList(),
      );
    } on TimeoutException {
      _uiState = _uiState.copyWith(
        isLoadingCompletedTrips: false,
        completedTripsErrorMessage: 'Connection timed out. Please try again.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoadingCompletedTrips: false,
        completedTripsErrorMessage:
            'Unable to load completed trips. Please try again.',
      );
    }
    notifyListeners();
  }

  String _formatTime(String? value, DateTime date) {
    final time = value?.trim() ?? '';
    if (time.isEmpty) return 'Scheduled';
    if (time.toUpperCase().contains('AM') ||
        time.toUpperCase().contains('PM')) {
      return time;
    }

    try {
      final parts = time.split(':');
      final parsed = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return DateFormat('hh:mm a').format(parsed);
    } catch (_) {
      return time;
    }
  }
}
