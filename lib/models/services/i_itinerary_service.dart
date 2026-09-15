import 'package:Trek/models/entities/day_trip.dart';
import 'package:Trek/models/entities/expense.dart';
import 'package:Trek/models/entities/expense_item.dart';
import 'package:Trek/view_models/ui_state/activity_ui_state.dart';

import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../entities/future_suggestion.dart';
import '../../view_models/ui_state/travel_information_ui_state.dart';

abstract interface class IItineraryService {
  Future<ItineraryGenerationResult> generateItinerary({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    List<String>? wishlist,
    List<String>? constraints,
    List<FutureSuggestion>? futureSuggestions,
    bool strictBudget = false,
    List<TransitPoint>? arrivals,
    List<TransitPoint>? departures,
    List<HotelStay>? hotels,
    bool isForeign = false,
    String? arrivalLocation,
    String? arrivalTime,
    String? departureLocation,
    String? departureTime,
    String? hotelLocation,
    String? hotelCheckInTime,
    String? hotelCheckOutTime,
  });

  Future<Activity> generateAlternativeItinerary({
    required String destination,
    required DateTime slotDate,
    required String startTime,
    required String endTime,
    required String category,
    required List<String> excludedActivity,
    required String existingActivityId,
    required String dayTripId,
    double budgetLimit = 0.0,
    int dayNumber = 1,
    String? preference,
    List<String>? constraints,
    String? previousActivityDestination,
    String? nextActivityDestination,
    bool isFirstDay = false,
    bool isLastDay = false,
    int totalDays = 1,
  });

  Future<Activity> regenerateTransportation({
    required String originPlace,
    required String destinationPlace,
    required String city,
    required String existingActivityId,
    required String dayTripId,
    required DateTime date,
    String? startTime,
    String? endTime,
  });

  Future<List<Activity>> regenerateEmptySlotsFromRemainingPlan({
    required String destination,
    required double remainingBudget,
    required List<Activity> remainingActivities,
    required List<Activity> emptySlots,
    required List<String> excludedPlaces,
    List<String>? uncoveredWishlist,
    String? preference,
    List<String>? constraints,
  });

  Future<bool> saveItinerary(
    List<dynamic> activities, {
    required String destination,
    required String datesText,
    required String budgetText,
  });

  Future<({WholeTrip trip, List<Activity> activities})?> fetchLatestTrip();

  Future<List<Activity>> fetchAllActivitiesByTrip(String tripId);

  Future<bool> endTrip(String id);

  Future<void> updateTripStatus(String tripId, String newStatus);

  Future<List<DayTrip>> getDaysByTripId(String tripId);

  Future<List<Activity>> getRemainingActivities(
    String tripId,
    DateTime currentDateTime,
  );

  Future<List<String>> getAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  });

  Future<List<String>> getAirportAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  });

  Future<List<String>> getHotelAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  });

  Future<List<Activity>> generateBudgetRecoveryItinerary({
    required String tripId,
    required double effectiveRemainingBudget,
    required double currentSpentBudget,
    required double topUpAmount,
    required List<Activity> remainingActivities,
    required String tripDestination,
    String? userCoordinates,
    DateTime? currentDate,
    DateTime? tripEndDate,
  });

  Future<void> saveRevisedItineraryActivities(List<Activity> activities);

  Future<List<WholeTrip>> fetchAllTrip();

  Future<WholeTrip?> fetchLatestTripWithCurrentUserId();

  Future<Map<String, dynamic>> getTripSpentSummary(List<String> activityIds);

  Future<void> deleteWholeTrip(String tripId);
}

abstract interface class ICachedActivity {
  Future<List<Activity>> getActivitiesForTrip(
    String tripId, {
    bool forceRefresh = false,
  });
  Future<void> saveActivitiesLocally(String tripId, List<Activity> activities);
  Future<void> clearLocalActivities(String tripId);
}

abstract interface class IBudgetService {
  Future<WholeTrip> deductRemainingBudget({
    required String tripId,
    required double expenseAmount,
  });

  Future<WholeTrip?> topUpBudget({
    required String tripId,
    required String currentActivityId,
    required double topupAmount,
  });

  // Future<bool> checkBudgetSufficiency({
  //   required WholeTrip trip,
  //   required String currentActivityId,
  //   required double topupAmount,
  // });

  Future<List<Activity>> reallocateBudget(
    String tripId,
    Activity currentActivity,
    double overspendAmount,
  );

  Future<int> calculateSufficientDays(String tripId, String currentActivityId);

  Future<double> reconcileTripOverspend({required String tripId});

  /// Recomputes the trip balance from the recorded expenses
  /// (`total_budget - SUM(expenses)`) and repairs `remaining_balance` when it
  /// has drifted from that authoritative value.
  ///
  /// Unlike the overspend columns, the balance was previously only ever adjusted
  /// incrementally (`deductRemainingBudget` subtracts, `topUpBudget` adds), so an
  /// expense that is later edited or removed left it permanently wrong - and
  /// every remaining-budget decision reads it. Returns the reconciled figures.
  Future<({double totalBudget, double totalSpent, double remainingBalance})>
  reconcileTripBalance({required String tripId});
}

enum ExpenseProcessingResult {
  withinBudget,
  reallocatedSuccessfully,
  reallocatedFailed,
  exceedsThresholdTriggerRecommendation,
  critical,
}

abstract interface class IExpenseTrackingService {
  Future<void> validateReceiptImage(String receiptLocalPath);

  Future<String> readReceiptText(String receiptLocalPath);

  bool isLikelyReceiptText(String receiptText);

  String? extractMerchantName(String receiptText);

  DateTime? extractReceiptDateTime(String receiptText);

  String? extractReceiptCurrency(String receiptText);

  double? extractReceiptTotal(String receiptText);

  double? extractReceiptTax(String receiptText);
  double? extractReceiptDiscount(String receiptText);
  double? extractReceiptRounding(String receiptText);

  List<String> extractReceiptItemLines(String receiptText);

  List<ExpenseItem> buildDraftExpenseItemsFromReceipt({
    required String receiptText,
    String? merchantName,
    DateTime? transactionDateTime,
  });

  Future<Expense> recordExpense({
    required String activitiesId,
    required List<ExpenseItem> expenseItems,
    required String paymentMethod,
    required String currency,
    double taxAmount = 0.0,
    double discountAmount = 0.0,
    double roundingAmount = 0.0,
    String? receiptLocalPath,
  });

  double calculateItemSubtotal(int quantity, double unitPrice);

  double calculateTotalExpense(
    List<ExpenseItem> expenseItems, [
    double taxAmount = 0.0,
    double discountAmount = 0.0,
    double roundingAmount = 0.0,
  ]);

  void validateExpenseItems(List<ExpenseItem> expenseItems);

  void validateTotalAmount(double totalAmount);

  void validateTaxAmount(double taxAmount);
  void validateExpenseAdjustments(double discountAmount, double roundingAmount);

  void validateExpenseWithinRemainingBudget({
    required double totalAmount,
    required double remainingBudget,
  });

  Future<ExpenseProcessingResult> processExpense({
    required String tripId,
    required String currentActivityId,
  });

  Future<double> getExceededAmount(String tripId, String currentActivityId);

  Future<bool> detectOverspend(
    String tripId,
    Activity currentActivity,
    double expense,
  );

  Future<bool> detectCriticalOverspend(
    double totalAllocatedBudget,
    double remainingBudget,
  );

  Future<List<Activity>> reallocateBudget(
    String tripId,
    Activity currentActivity,
    double overspendAmount,
  );

  Future<bool> calculateOverspendPercentage(
    Activity currentActivity,
    double overspentAmount,
  );
}

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
  final String currency;
  final String? paymentMethod;
  final String? receiptImageUrl;
  final DateTime? recordedAt;

  const FinancialExpenseDetail({
    required this.expenseId,
    required this.activityName,
    required this.activityImageUrl,
    required this.activityStartTime,
    required this.amount,
    required this.currency,
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
