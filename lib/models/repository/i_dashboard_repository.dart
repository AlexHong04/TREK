import '../entities/activity.dart';
import '../entities/day_trip.dart';
import '../entities/expense.dart';
import '../entities/expense_item.dart';
import '../entities/future_suggestion.dart';
import '../entities/whole_trip.dart';

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
