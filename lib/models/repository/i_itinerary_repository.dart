import '../entities/activity.dart';
import '../entities/day_trip.dart';
import '../entities/expense.dart';
import '../entities/expense_item.dart';
import '../entities/future_suggestion.dart';
import '../entities/whole_trip.dart';

abstract interface class IItineraryRepository {
  Future<void> insertFullTrip({
    required String destination,
    required String datesText,
    required double totalBudget,
    required double remainingBalance,
    required List<Activity> activities,
  });

  Future<void> updateTripBudget(WholeTrip trip);

  Future<void> terminateTrip(String id, String status);

  Future<List<Activity>> fetchRemainingActivity(
    String tripId,
    String currentActivityId,
  );

  Future<Activity> getCurrentActivity(String id);

  Future<DayTrip> getCurrentDay(String dayId);

  Future<bool> updateOverspendDetails(DayTrip day, Activity activity);

  Future<void> updateDayTopUpBudget(DayTrip day);

  Future<void> updateDayOverspend(DayTrip day);

  Future<bool> updateCriticalDetails(String tripId);

  Future<bool> updateActivities(List<Activity> activities);

  Future<WholeTrip> getTrip(String tripId);

  Future<WholeTrip> getTripByActivityId(String activityId);

  Future<List<DayTrip>> fetchDaysByTripId(String tripId);

  Future<WholeTrip?> getLatestTrip();

  Future<List<Activity>> fetchAllActivitiesByTrip(String tripId);

  Future<void> updateTripStatus(String tripId, String newStatus);

  Future<void> replaceTripActivities({
    required String tripId,
    required List<Activity> newActivities,
  });

  Future<List<WholeTrip>> fetchAllTrip();

  Future<WholeTrip?> fetchLatestTrip();

  Future<void> replaceRemainingActivities({
    required String dayTripId,
    required List<String> oldRemainingActivityIds,
    required List<Activity> newActivities,
  });

  Future<Map<String, dynamic>> fetchSpentSummaryByActivityIds(
    List<String> activityIds,
  );

  Future<void> deleteWholeTrip(String tripId);
}

abstract interface class ISharedPreferencesRepo {
  /// Fetches activities for a trip, using local cache first if available.
  Future<List<Activity>> getActivities(
    String tripId, {
    bool forceRefresh = false,
  });

  /// Saves activities to local storage cache.
  Future<void> saveActivitiesLocally(String tripId, List<Activity> activities);

  /// Clears local cached activities for a specific trip.
  Future<void> clearLocalActivities(String tripId);
}

class DashboardRecommendationRateLimitException implements Exception {
  const DashboardRecommendationRateLimitException();
}

abstract interface class IDashboardRepository {
  Future<WholeTrip?> getCurrentTrip(DateTime date);

  Future<WholeTrip?> getWholeTrip(String tripId);

  Future<DayTrip?> getDayTrip(String tripId, DateTime date);

  Future<List<DayTrip>> getDayTrips(String tripId);

  Future<List<Activity>> getActivities(String dayTripId);

  Future<List<Activity>> getActivitiesForDayTrips(List<String> dayTripIds);

  Future<List<Expense>> getExpenses(List<String> activityIds);

  Future<List<ExpenseItem>> getExpenseItems(String expenseId);

  Future<List<DateTime>> getAvailableDates();

  Future<List<WholeTrip>> getTripsForCurrentUser();

  Future<String> requestGeminiCostSavingTips({
    required String destination,
    required double allocatedBudget,
    required double totalExpense,
    required double remainingBudget,
    required Map<String, double> categoryExpenses,
  });

  Future<String> requestGeminiFutureBudgetRecommendations({
    required String destination,
    required double allocatedBudget,
    required double totalExpense,
    required Map<String, double> categoryExpenses,
  });

  Future<List<FutureSuggestion>> getFutureSuggestions(String tripId);

  Future<void> saveFutureSuggestions(List<FutureSuggestion> suggestions);
}

abstract interface class IExpenseRepository {
  Future<List<Expense>> getExpensesByActivityId(String activityId);

  Future<List<ExpenseItem>> getExpenseItemsByExpenseId(String expenseId);

  Future<Expense> insertExpense(Expense expense);

  Future<void> insertExpenseItems(List<ExpenseItem> expenseItems);

  Future<void> updateReceiptImageUrl({
    required String expenseId,
    required String receiptImageUrl,
  });

  Future<String> uploadReceiptImage({
    required String localImagePath,
    required String expenseId,
  });
}
