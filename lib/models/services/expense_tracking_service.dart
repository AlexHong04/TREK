import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
}

class ExpenseTrackingService {
  final ItineraryRepository _itineraryRepository = ItineraryRepository();
  final BudgetService _budgetService = BudgetService();
  final ExpenseRepository _expenseRepository = ExpenseRepository();

  /// Reads the visible Latin text from a receipt image stored on the device.
  /// The caller decides how to display or use the extracted text.
  Future<String> readReceiptText(String receiptLocalPath) async {
    if (receiptLocalPath.trim().isEmpty) {
      throw ArgumentError('Choose a receipt image before scanning it.');
    }

    final inputImage = InputImage.fromFilePath(receiptLocalPath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final receiptText = recognizedText.text.trim();

      if (receiptText.isEmpty) {
        throw Exception(
          'Unable to read the receipt. Please try another image or continue with the manual entry.',
        );
      }

      return receiptText;
    } finally {
      await textRecognizer.close();
    }
  }

  /// Uses common receipt wording to find a merchant name. The first useful
  /// text line is the best available guess and must still be reviewed by the
  /// tourist before the expense is saved.
  String? extractMerchantName(String receiptText) {
    final lines = _receiptLines(receiptText);

    for (final line in lines) {
      final normalizedLine = line.toLowerCase();
      final isSummaryLine = normalizedLine.contains('total') ||
          normalizedLine.contains('subtotal') ||
          normalizedLine.contains('tax') ||
          normalizedLine.contains('change') ||
          normalizedLine.contains('cash') ||
          normalizedLine.contains('receipt');

      if (!isSummaryLine && RegExp(r'[a-zA-Z]').hasMatch(line)) {
        return line;
      }
    }

    return null;
  }

  /// Finds a date and time when the receipt contains both in familiar numeric
  /// formats such as 26/08/2026 and 01:45 PM. Returns null if either is absent
  /// or invalid, so the existing date/time picker remains the fallback.
  DateTime? extractReceiptDateTime(String receiptText) {
    final dateMatch = RegExp(
      r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b',
    ).firstMatch(receiptText);
    final timeMatch = RegExp(
      r'\b(\d{1,2})[:.](\d{2})\s*(AM|PM)?\b',
      caseSensitive: false,
    ).firstMatch(receiptText);

    if (dateMatch == null || timeMatch == null) {
      return null;
    }

    final day = int.tryParse(dateMatch.group(1)!);
    final month = int.tryParse(dateMatch.group(2)!);
    var year = int.tryParse(dateMatch.group(3)!);
    var hour = int.tryParse(timeMatch.group(1)!);
    final minute = int.tryParse(timeMatch.group(2)!);
    final period = timeMatch.group(3)?.toUpperCase();

    if (day == null || month == null || year == null || hour == null || minute == null) {
      return null;
    }

    if (year < 100) {
      year += 2000;
    }

    if (period == 'PM' && hour < 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    final dateTime = DateTime(year, month, day, hour, minute);
    final isInvalidDate = dateTime.year != year ||
        dateTime.month != month ||
        dateTime.day != day ||
        dateTime.hour != hour ||
        dateTime.minute != minute;

    return isInvalidDate ? null : dateTime;
  }

  /// Finds the amount on a labelled total line, for example "TOTAL RM 12.50".
  /// It never uses an unlabelled price as the total because that could be an
  /// individual item price.
  double? extractReceiptTotal(String receiptText) {
    const totalLabels = [
      'grand total',
      'net total',
      'total amount',
      'amount due',
      'total due',
      'total',
    ];

    for (final line in _receiptLines(receiptText).reversed) {
      final normalizedLine = line.toLowerCase();
      if (!totalLabels.any(normalizedLine.contains)) {
        continue;
      }

      final amounts = _amountPattern
          .allMatches(line)
          .map((match) => match.group(1)!.replaceAll(',', ''))
          .map(double.tryParse)
          .whereType<double>()
          .toList();

      if (amounts.isNotEmpty) {
        return amounts.last;
      }
    }

    return null;
  }

  /// Returns likely purchase lines for review. They are deliberately returned
  /// as text because receipt layouts do not reliably expose quantity and price
  /// in one universal format.
  List<String> extractReceiptItemLines(String receiptText) {
    return _receiptLines(receiptText).where((line) {
      final normalizedLine = line.toLowerCase();
      final isSummaryLine = normalizedLine.contains('total') ||
          normalizedLine.contains('subtotal') ||
          normalizedLine.contains('tax') ||
          normalizedLine.contains('change') ||
          normalizedLine.contains('cash') ||
          normalizedLine.contains('visa') ||
          normalizedLine.contains('mastercard');

      return !isSummaryLine &&
          RegExp(r'[a-zA-Z]').hasMatch(line) &&
          _amountPattern.hasMatch(line);
    }).toList();
  }

  static final RegExp _amountPattern = RegExp(
    r'(?<!\d)(?:RM\s*)?(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+(?:\.\d{2}))(?!\d)',
    caseSensitive: false,
  );

  List<String> _receiptLines(String receiptText) {
    return receiptText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

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

  // zhiqin
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
        return ExpenseProcessingResult.reallocatedFailed;
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

  // zhiqin
  Future<bool> detectOverspend(String tripId, Activity currentActivity, double expense) async {
    if (currentActivity.allocatedBudget < expense) {
      return true;
    }
    return false;
  }

  // zhiqin
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
