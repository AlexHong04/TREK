import '../entities/activity.dart';
import '../entities/expense.dart';
import '../entities/expense_item.dart';

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

  String? extractMerchantName(String receiptText);

  DateTime? extractReceiptDateTime(String receiptText);

  double? extractReceiptTotal(String receiptText);

  List<String> extractReceiptItemLines(String receiptText);

  Future<Expense> recordExpense({
    required String activitiesId,
    required List<ExpenseItem> expenseItems,
    String? paymentMethod,
    String? receiptLocalPath,
  });

  double calculateItemSubtotal(int quantity, double unitPrice);

  double calculateTotalExpense(List<ExpenseItem> expenseItems);

  void validateExpenseItems(List<ExpenseItem> expenseItems);

  void validateTotalAmount(double totalAmount);

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
