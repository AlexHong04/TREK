import 'package:flutter/material.dart';

import '../../models/entities/activity.dart';
import '../../models/services/budget_service.dart';
import '../../models/services/expense_tracking_service.dart';
import '../../models/services/itinerary_service.dart';
import '../ui_state/activity_ui_state.dart';

class ActivityViewModel extends ChangeNotifier {
  final ItineraryService _itineraryService = ItineraryService();
  final BudgetService _budgetService = BudgetService();
  final ExpenseTrackingService _expenseTrackingService =
      ExpenseTrackingService();

  ActivityUiState _uiState = const ActivityUiState();

  ActivityUiState get uiState => _uiState;

  ActivityViewModel() {
    initialize();
  }

  Future<void> initialize() async {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final result = await _itineraryService.fetchLatestTrip();

      if (result != null) {
        _uiState = _uiState.copyWith(
          isLoading: false,
          tripId: result.trip.tripId,
          activities: result.activities,
          totalBudget: result.trip.totalBudget,
        );
      } else {
        _uiState = _uiState.copyWith(isLoading: false);
      }
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false);
      debugPrint('Error in ActivityViewModel.initialize: $e');
    }
    notifyListeners();
  }

  Future<void> loadTripItinerary(String tripId) async {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final activities = await _itineraryService.fetchAllActivitiesByTrip(
        tripId,
      );

      _uiState = _uiState.copyWith(isLoading: false, activities: activities);
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false);
      debugPrint('DEBUG: Error in loadTripItinerary: $e');
    }
    notifyListeners();
  }

  void initializeHardcoded() {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    // Mock data matching the UI
    final List<Activity> newActivities = [
      Activity(
        activitiesId: '1',
        dayTripId: 'day1',
        destination: 'Kinkaku-ji Temple',
        description:
            'Marvel at the Zen Buddhist temple whose top two floors are completely covered in gold leaf.',
        activityImgUrl: 'assets/images/placeholder.png',
        // dummy
        date: DateTime(2026, 8, 12, 9, 0),
        allocatedBudget: 25.0,
        overspendAmount: 25.0,
        status: 'planned',
        duration: '60-90 min',
        activityCategory: 'Culture',
        isOverspend: true, // triggers the blue badge in UI
      ),
      Activity(
        activitiesId: '2',
        dayTripId: 'day1',
        destination: 'Traditional Kaiseki Lunch',
        description:
            'Experience a multi-course dinner that balances taste, texture, and appearance in the historic Gion district.',
        activityImgUrl: 'assets/images/placeholder.png',
        // dummy
        date: DateTime(2026, 8, 12, 12, 0),
        allocatedBudget: 25.0,
        overspendAmount: 0.0,
        status: 'planned',
        duration: '60-90 min',
        activityCategory: 'Food',
        isOverspend: false,
      ),
    ];

    _uiState = _uiState.copyWith(
      isLoading: false,
      activities: newActivities,
      totalBudget: 2450.00,
      spentBudget: 2425.00,
      remainingBudget: 25.00,
      overspentBudget: 0.00,
      sufficientDays: 7,
      usedPercentageString: '1% Used',
      // Matching the design text
      usedPercentageValue: 0.01,
    );

    notifyListeners();
  }

  Future<void> endTrip() async {
    final id = _uiState.tripId;

    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final update = await _itineraryService.endTrip(id);

      if (update) {
        _uiState = _uiState.copyWith(isLoading: true, tripId: '');
      }
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false);
    }

    notifyListeners();
  }

  Future<void> topUpBudget(double additionalAmount) async {
    final id = _uiState.tripId;
    final activityId = _uiState.currentActivityId;
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final updatedTrip = await _budgetService.topUpBudget(
        tripId: id,
        currentActivityId: activityId,
        topupAmount: additionalAmount,
      );

      if (updatedTrip != null) {
        final percentage =
            (updatedTrip.remainingBalance ?? 0.0) / updatedTrip.totalBudget;

        final days = await _budgetService.calculateSufficientDays(
          updatedTrip,
          activityId,
        );

        _uiState = _uiState.copyWith(
          isLoading: false,
          totalBudget: updatedTrip.totalBudget,
          remainingBudget: updatedTrip.remainingBalance,
          sufficientDays: days.toInt(),
          usedPercentageValue: percentage,
          usedPercentageString:
              '${(percentage * 100).toStringAsFixed(0)}% Used',
        );
      } else {
        _uiState = _uiState.copyWith(isLoading: false);
      }
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false);
    }

    notifyListeners();
  }

  Future<void> handleExpenseSubmission(
    Activity activity,
    double expense,
  ) async {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    final result = await _expenseTrackingService.processExpense(
      tripId: _uiState.tripId,
      currentActivityId: _uiState.currentActivityId,
      expense: expense,
    );

    switch (result) {
      case ExpenseProcessingResult.withinBudget:
        // Update UI state normally
        break;

      case ExpenseProcessingResult.reallocatedSuccessfully:
        // Show snackbar notifying user that restaurant budgets were reallocated
        // update ui State
        break;

      case ExpenseProcessingResult.reallocatedFailed:
        // Show snackbar notifying user that restaurant budgets were reallocated, but not fully covered the overspend amount
        // update ui State
        break;

      case ExpenseProcessingResult.exceedsThresholdTriggerRecommendation:
        // Open dialog/screen showing top-up or recovery recommendations
        break;

      case ExpenseProcessingResult
          .noAvailableRestaurantsToReallocateBudgetTriggerRecommendation:
        // Open dialog/screen showing top-up or recovery recommendations
        break;
    }

    _uiState = _uiState.copyWith(isLoading: false);
    notifyListeners();
  }
}
