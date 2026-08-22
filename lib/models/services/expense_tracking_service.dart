import 'package:trek/models/services/budget_service.dart';

import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../repository/activity_repository.dart';
import '../repository/itinerary_repository.dart';

enum ExpenseProcessingResult {
  withinBudget,
  reallocatedSuccessfully,
  exceedsThresholdTriggerRecommendation,
}

class ExpenseTrackingService {
  final ItineraryRepository _itineraryRepository = ItineraryRepository();
  final ActivityRepository _activityRepository = ActivityRepository();
  final BudgetService _budgetService = BudgetService();

  Future<ExpenseProcessingResult> processExpense({
    required String tripId,
    required Activity currentActivity,
    required double expense,
  }) async {
    // Detect overspend
    final bool isOverspend = await detectOverspend(tripId, currentActivity, expense);

    if (!isOverspend) {
      return ExpenseProcessingResult.withinBudget;
    }

    final double overspentAmount = expense - currentActivity.allocatedBudget;

    // Check if overspend exceeds defined threshold
    final bool isAboveThreshold = await calculateOverspendPercentage(
      tripId,
      currentActivity,
      overspentAmount,
    );

    if (isAboveThreshold) {
      // Above threshold -> Trigger recommendation flow
      return ExpenseProcessingResult.exceedsThresholdTriggerRecommendation;
    } else {
      // Within threshold -> Reallocate budget among remaining restaurants
      final updatedActivities = await reallocateBudget(
        tripId,
        currentActivity,
        overspentAmount,
      );

      // Update database
      await _activityRepository.updateActivities(updatedActivities);

      return ExpenseProcessingResult.reallocatedSuccessfully;
    }
  }

  Future<bool> detectOverspend(String tripId, Activity currentActivity, double expense) async {
    if (currentActivity.allocatedBudget < expense) {
      return true;
    }
    return false;
  }

  Future<List<Activity>> reallocateBudget(String tripId, Activity currentActivity, double overspendAmount) async {
    List<Activity> modifiedActivities =
    await _budgetService.reallocateBudget(tripId, currentActivity, overspendAmount);
    return modifiedActivities;
  }

  Future<bool> calculateOverspendPercentage(
      String tripId,
      Activity currentActivity,
      double overspentAmount,
      ) async {
    List<Activity> remainingActivities =
    await _activityRepository.fetchRemainingActivity(tripId, currentActivity.activitiesId);

    // Find index of currentActivity inside remainingActivities list
    final int currentIndex = remainingActivities.indexWhere(
          (activity) => activity.activitiesId == currentActivity.activitiesId,
    );

    // Fallback if activity isn't found in remaining list
    if (currentIndex == -1) {
      return false;
    }

    double targetAllocatedBudget = 0.0;
    final bool isLastActivityOfDay =
        currentIndex == remainingActivities.length - 1;

    if (!isLastActivityOfDay) {
      // Not the last activity: calculate remaining allocated budget for the rest of today
      final upcomingTodayActivities = remainingActivities.sublist(currentIndex + 1);
      targetAllocatedBudget = upcomingTodayActivities.fold(
        0.0,
            (sum, item) => sum + item.allocatedBudget,
      );
    } else {
      // Last activity of the day: fetch remaining allocated budget for the next day
      final DateTime currentDate = currentActivity.date;
      final DateTime nextDay = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day + 1,
      );

      final nextDayActivities = remainingActivities.where((activity) {
        return activity.date.year == nextDay.year &&
            activity.date.month == nextDay.month &&
            activity.date.day == nextDay.day;
      }).toList();

      targetAllocatedBudget = nextDayActivities.fold(
        0.0,
            (sum, item) => sum + item.allocatedBudget,
      );
    }

    // Calculate overspend threshold percentage
    double overspendThresholdPercentage;
    if (targetAllocatedBudget <= 100.0) {
      overspendThresholdPercentage = 0.15; // 15%
    } else if (targetAllocatedBudget <= 500.0) {
      overspendThresholdPercentage = 0.10; // 10%
    } else {
      overspendThresholdPercentage = 0.05; // 5%
    }

    // Check if overspend exceeds threshold limit
    final double allowedOverspendLimit =
        targetAllocatedBudget * overspendThresholdPercentage;

    return overspentAmount > allowedOverspendLimit;
  }

}
