import '../entities/day_trip.dart';
import '../entities/expense_item.dart';
import '../entities/whole_trip.dart';

class FinancialCategorySummary {
  final String category;
  final double allocatedBudget;
  final double expense;
  final List<FinancialExpenseDetail> expenseDetails;

  const FinancialCategorySummary({
    required this.category,
    required this.allocatedBudget,
    required this.expense,
    this.expenseDetails = const [],
  });
}

class FinancialExpenseDetail {
  final String expenseId;
  final String activityName;
  final String activityImageUrl;
  final String? activityStartTime;
  final double amount;
  final String? paymentMethod;
  final String? receiptImageUrl;
  final DateTime? recordedAt;

  const FinancialExpenseDetail({
    required this.expenseId,
    required this.activityName,
    required this.activityImageUrl,
    required this.activityStartTime,
    required this.amount,
    required this.paymentMethod,
    required this.receiptImageUrl,
    required this.recordedAt,
  });
}

class CurrentDayFinancialSummary {
  final WholeTrip trip;
  final DayTrip dayTrip;
  final List<FinancialCategorySummary> categories;

  const CurrentDayFinancialSummary({
    required this.trip,
    required this.dayTrip,
    required this.categories,
  });
}

class TripCategorySummary {
  final String category;
  final double expense;

  const TripCategorySummary({required this.category, required this.expense});
}

class WholeTripFinancialSummary {
  final WholeTrip trip;
  final double totalExpense;
  final double totalTopUpBudget;
  final List<TripCategorySummary> categories;

  const WholeTripFinancialSummary({
    required this.trip,
    required this.totalExpense,
    required this.totalTopUpBudget,
    required this.categories,
  });
}

class CostSavingTip {
  final String category;
  final String title;
  final String description;

  const CostSavingTip({
    required this.category,
    required this.title,
    required this.description,
  });
}

class CostSavingTipsRateLimitException implements Exception {
  const CostSavingTipsRateLimitException();
}

class FutureBudgetRecommendation {
  final String category;
  final double percentage;

  const FutureBudgetRecommendation({
    required this.category,
    required this.percentage,
  });
}

class FutureBudgetRecommendationsRateLimitException implements Exception {
  const FutureBudgetRecommendationsRateLimitException();
}

abstract interface class IFinancialDashboardService {
  Future<CurrentDayFinancialSummary?> getCurrentDaySummary(DateTime date);

  Future<WholeTripFinancialSummary?> getTripSummary(String tripId);

  Future<List<ExpenseItem>> getExpenseItems(String expenseId);

  Future<List<CostSavingTip>> getCostSavingTips({
    required String destination,
    required double allocatedBudget,
    required double totalExpense,
    required double remainingBudget,
    required Map<String, double> categoryExpenses,
  });

  Future<List<FutureBudgetRecommendation>> getFutureBudgetRecommendations({
    required String destination,
    required double allocatedBudget,
    required double totalExpense,
    required Map<String, double> categoryExpenses,
  });

  Future<List<FutureBudgetRecommendation>> getSavedFutureBudgetRecommendations(
    String tripId,
  );

  bool hasValidFutureRecommendationTotal(Map<String, double> percentages);

  Future<void> saveFutureBudgetRecommendations({
    required String tripId,
    required Map<String, double> percentages,
  });

  Future<List<DateTime>> getAvailableDates();

  Future<List<WholeTrip>> getCompletedTrips();
}
