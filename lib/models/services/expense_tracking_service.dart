import '../entities/activity.dart';
import '../entities/expense.dart';
import '../entities/expense_item.dart';
import '../entities/whole_trip.dart';
import '../repository/expense_repository.dart';
import '../repository/itinerary_repository.dart';
import 'budget_service.dart';

enum ExpenseProcessingResult {
  withinBudget,
  reallocatedSuccessfully,
  reallocatedFailed,
  exceedsThresholdTriggerRecommendation,
  noAvailableRestaurantsToReallocateBudgetTriggerRecommendation,
}

class ExpenseTrackingService {
  final ItineraryRepository _itineraryRepository = ItineraryRepository();
  final BudgetService _budgetService = BudgetService();
  final ExpenseRepository _expenseRepository = ExpenseRepository();

  /// Validates, calculates, and records one parent expense with its child items.
  Future<Expense> recordExpense({
    required String activitiesId,
    required List<ExpenseItem> expenseItems,
    String? paymentMethod,
    String? receiptLocalPath,
  }) async {
    if (activitiesId.trim().isEmpty) {
      throw ArgumentError('An expense must be linked to a selected activity.');
    }

    validateExpenseItems(expenseItems);

    final itemsWithCalculatedSubtotals = expenseItems
        .map(
          (item) => item.copyWith(
            subtotal: calculateItemSubtotal(item.quantity, item.unitPrice),
          ),
        )
        .toList();

    final totalAmount = calculateTotalExpense(itemsWithCalculatedSubtotals);
    validateTotalAmount(totalAmount);

    final savedExpense = await _expenseRepository.insertExpense(
      Expense(
        activitiesId: activitiesId,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
      ),
    );

    final expenseId = savedExpense.expenseId;
    if (expenseId == null || expenseId.isEmpty) {
      throw Exception('Supabase did not return an expense ID.');
    }

    final itemsWithExpenseId = itemsWithCalculatedSubtotals
        .map((item) => item.copyWith(expenseId: expenseId))
        .toList();

    await _expenseRepository.insertExpenseItems(itemsWithExpenseId);

    if (receiptLocalPath == null || receiptLocalPath.trim().isEmpty) {
      return savedExpense;
    }

    final receiptImageUrl = await _expenseRepository.uploadReceiptImage(
      localImagePath: receiptLocalPath,
      expenseId: expenseId,
    );

    await _expenseRepository.updateReceiptImageUrl(
      expenseId: expenseId,
      receiptImageUrl: receiptImageUrl,
    );

    return savedExpense.copyWith(receiptImageUrl: receiptImageUrl);
  }

  double calculateItemSubtotal(int quantity, double unitPrice) {
    return quantity * unitPrice;
  }

  double calculateTotalExpense(List<ExpenseItem> expenseItems) {
    return expenseItems.fold(0.0, (total, item) => total + item.subtotal);
  }

  void validateExpenseItems(List<ExpenseItem> expenseItems) {
    if (expenseItems.isEmpty) {
      throw ArgumentError('Add at least one expense item.');
    }

    for (final item in expenseItems) {
      if (item.itemName.trim().isEmpty) {
        throw ArgumentError('Item name cannot be empty.');
      }

      if (item.quantity <= 0) {
        throw ArgumentError('Item quantity must be greater than zero.');
      }

      if (item.unitPrice < 0) {
        throw ArgumentError('Item unit price cannot be negative.');
      }
    }
  }

  void validateTotalAmount(double totalAmount) {
    if (totalAmount <= 0 || totalAmount > 999999) {
      throw ArgumentError(
        'Amount must be a positive number within the allowed transaction limit.',
      );
    }
  }

  Future<ExpenseProcessingResult> processExpense({
    required String tripId,
    required String currentActivityId,
    required double expense,
  }) async {
    final currentActivity = await _itineraryRepository.getCurrentActivity(currentActivityId);
    final currentDay = await _itineraryRepository.getCurrentDay(currentActivityId);

    // Detect overspend
    final bool isOverspend = await detectOverspend(tripId, currentActivity, expense);

    if (!isOverspend) {
      return ExpenseProcessingResult.withinBudget;
    }

    final double overspentAmount = expense - currentActivity.allocatedBudget;

    final updatedActivity = currentActivity.copyWith(
      overspendAmount: overspentAmount,
      isOverspend: true,
    );

    final existingCategories = currentDay.overspendCategory
        ?.split(',')
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty)
        .toList() ??
        [];

    final newCategory = currentActivity.activityCategory.trim();

    if (!existingCategories.contains(newCategory)) {
      existingCategories.add(newCategory);
    }

    final updatedDay = currentDay.copyWith(
      overspendAmount:
      (currentDay.overspendAmount ?? 0.00) + overspentAmount,
      overspendCategory: existingCategories.join(', '),
      isOverspend: true,
    );

    await _itineraryRepository.updateDayOverspendDetails(updatedDay);
    await _itineraryRepository.updateOverspendDetails(updatedActivity);

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

      if (updatedActivities == []) {
        return ExpenseProcessingResult.noAvailableRestaurantsToReallocateBudgetTriggerRecommendation;
      }

      // Update database
      final updateSuccessful = await _itineraryRepository.updateActivities(updatedActivities);

      if (updateSuccessful) {
        return ExpenseProcessingResult.reallocatedSuccessfully;
      } else {
        return ExpenseProcessingResult.reallocatedFailed;
      }
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
    await _itineraryRepository.fetchRemainingActivity(tripId, currentActivity.activitiesId);

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
