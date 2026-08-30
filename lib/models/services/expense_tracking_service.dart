import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../entities/activity.dart';
import '../entities/expense.dart';
import '../entities/expense_item.dart';
import '../entities/whole_trip.dart';
import '../repository/expense_repository.dart';
import '../repository/i_expense_repository.dart';
import '../repository/itinerary_repository.dart';
import '../repository/i_itinerary_repository.dart';
import 'budget_service.dart';
import 'i_budget_service.dart';
import 'i_expense_tracking_service.dart';

class ExpenseTrackingService implements IExpenseTrackingService {
  final IItineraryRepository _itineraryRepository = ItineraryRepository();
  final IBudgetService _budgetService = BudgetService();
  final IExpenseRepository _expenseRepository = ExpenseRepository();

  static const int _maximumReceiptSizeInBytes = 15 * 1024 * 1024;

  /// Checks the receipt rules before the crop tool or OCR is opened.
  @override
  Future<void> validateReceiptImage(String receiptLocalPath) async {
    final imageFile = File(receiptLocalPath);
    final extension = receiptLocalPath.split('.').last.toLowerCase();
    const supportedExtensions = {'jpg', 'jpeg', 'png'};

    if (receiptLocalPath.trim().isEmpty ||
        !supportedExtensions.contains(extension) ||
        !await imageFile.exists() ||
        await imageFile.length() > _maximumReceiptSizeInBytes) {
      throw ArgumentError(
        'Invalid receipt image. Please upload a JPG, JPEG, or PNG image not exceeding 15 MB.',
      );
    }
  }

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

  /// Prefers a receipt heading such as "JUICE STATION" over an address.
  /// The value is still only a suggestion for the tourist to review.
  String? extractMerchantName(String receiptText) {
    final lines = _receiptLines(receiptText);
    final merchantCandidates = <String>[];

    for (final line in lines) {
      final isAllCapName =
          line == line.toUpperCase() &&
          RegExp(r'[A-Z]').hasMatch(line) &&
          !RegExp(r'\d').hasMatch(line) &&
          !_isReceiptLabel(line);
      if (isAllCapName && line.length >= 3 && line.length <= 40) {
        merchantCandidates.add(line);
      }
    }

    if (merchantCandidates.isNotEmpty) {
      merchantCandidates.sort(
        (first, second) => second
            .split(RegExp(r'\s+'))
            .length
            .compareTo(first.split(RegExp(r'\s+')).length),
      );
      return merchantCandidates.first;
    }

    for (final line in lines) {
      final isSummaryLine = _isReceiptLabel(line);

      if (!isSummaryLine && RegExp(r'[a-zA-Z]').hasMatch(line)) {
        return line;
      }
    }

    return null;
  }

  /// Finds a date and time when the receipt contains both in familiar numeric
  /// formats such as 26/08/2026 or 2021/02/25 and 01:45 PM. Returns null if
  /// either is absent or invalid, so the existing picker remains the fallback.
  DateTime? extractReceiptDateTime(String receiptText) {
    final dateMatch = RegExp(
      r'\b(\d{1,4})[/-](\d{1,2})[/-](\d{1,4})\b',
    ).firstMatch(receiptText);
    final timeMatch = RegExp(
      r'\b(\d{1,2})[:.](\d{2})\s*(AM|PM)?\b',
      caseSensitive: false,
    ).firstMatch(receiptText);

    if (dateMatch == null || timeMatch == null) {
      return null;
    }

    final firstDatePart = int.tryParse(dateMatch.group(1)!);
    final month = int.tryParse(dateMatch.group(2)!);
    final thirdDatePart = int.tryParse(dateMatch.group(3)!);
    final isYearFirst = (firstDatePart ?? 0) >= 1000;
    final day = isYearFirst ? thirdDatePart : firstDatePart;
    var year = isYearFirst ? firstDatePart : thirdDatePart;
    var hour = int.tryParse(timeMatch.group(1)!);
    final minute = int.tryParse(timeMatch.group(2)!);
    final period = timeMatch.group(3)?.toUpperCase();

    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null) {
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
    final isInvalidDate =
        dateTime.year != year ||
        dateTime.month != month ||
        dateTime.day != day ||
        dateTime.hour != hour ||
        dateTime.minute != minute;

    return isInvalidDate ? null : dateTime;
  }

  /// Finds the amount on a labelled total line. Some receipt layouts put the
  /// total amount on the next OCR line, so that line is also checked.
  double? extractReceiptTotal(String receiptText) {
    const totalLabels = [
      'grand total',
      'net total',
      'total amount',
      'amount due',
      'total due',
      'total',
    ];

    final lines = _receiptLines(receiptText);
    for (var index = lines.length - 1; index >= 0; index--) {
      final line = lines[index];
      final normalizedLine = line.toLowerCase();
      if (!totalLabels.any(normalizedLine.contains)) {
        continue;
      }

      final amounts = _amountsFromLine(line);

      if (amounts.isNotEmpty) {
        return amounts.last;
      }

      if (index + 1 < lines.length) {
        final followingAmounts = _amountsFromLine(lines[index + 1]);
        if (followingAmounts.isNotEmpty) {
          return followingAmounts.first;
        }
      }
    }

    // OCR sometimes returns the amounts after every label. When a receipt has
    // a TOTAL label but no nearby amount, the final amount is the best total
    // candidate and must still be reviewed by the tourist.
    final hasTotalLabel = lines.any(
      (line) => line.toLowerCase().contains('total'),
    );
    if (hasTotalLabel) {
      final allAmounts = lines.expand(_amountsFromLine).toList();
      if (allAmounts.isNotEmpty) {
        return allAmounts.last;
      }
    }

    return null;
  }

  /// Returns likely purchase lines for review. It supports both one-line item
  /// rows and column-style receipts where an item name, quantity, and price are
  /// returned by OCR as separate lines.
  List<String> extractReceiptItemLines(String receiptText) {
    final lines = _receiptLines(receiptText);
    final itemHeaderIndex = lines.indexWhere(
      (line) => line.toLowerCase().trim() == 'item',
    );
    final priceHeaderIndex = lines.indexWhere(
      (line) => line.toLowerCase().trim() == 'price',
    );

    if (itemHeaderIndex >= 0 && priceHeaderIndex >= 0) {
      final itemName = lines
          .skip(itemHeaderIndex + 1)
          .firstWhere(
            (line) =>
                RegExp(r'[a-zA-Z]').hasMatch(line) &&
                !_isReceiptLabel(line) &&
                !_looksLikeAddress(line),
            orElse: () => '',
          );
      double? price;
      for (final priceLine in lines.skip(priceHeaderIndex + 1)) {
        final amounts = _amountsFromLine(priceLine);
        if (amounts.isNotEmpty) {
          price = amounts.first;
          break;
        }
      }

      if (itemName.isNotEmpty && price != null) {
        return ['$itemName RM${price.toStringAsFixed(2)}'];
      }
    }

    final itemLines = <String>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (_isReceiptLabel(line) || !RegExp(r'[a-zA-Z]').hasMatch(line)) {
        continue;
      }

      if (_amountPattern.hasMatch(line)) {
        itemLines.add(line);
        continue;
      }

      double? price;
      for (final possiblePriceLine in lines.skip(index + 1).take(3)) {
        final amounts = _amountsFromLine(possiblePriceLine);
        if (amounts.isNotEmpty) {
          price = amounts.first;
          break;
        }
      }
      if (price != null && !_looksLikeAddress(line)) {
        itemLines.add('$line RM${price.toStringAsFixed(2)}');
      }
    }

    return itemLines.toSet().toList();
  }

  static final RegExp _amountPattern = RegExp(
    r'(?<!\d)(?:RM\s*)?(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+(?:\.\d{2}))(?!\d)',
    caseSensitive: false,
  );

  List<double> _amountsFromLine(String line) {
    return _amountPattern
        .allMatches(line)
        .map((match) => match.group(1)!.replaceAll(',', ''))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
  }

  bool _isReceiptLabel(String line) {
    final normalizedLine = line.toLowerCase().trim();
    const labels = [
      'total',
      'subtotal',
      'tax',
      'change',
      'cash',
      'receipt',
      'visa',
      'mastercard',
      'sale',
      'item',
      'qty',
      'quantity',
      'price',
      'transaction',
      'tran:',
      'xid:',
      'usa',
    ];
    return labels.any(normalizedLine.contains);
  }

  bool _looksLikeAddress(String line) {
    return RegExp(r'\d').hasMatch(line) ||
        line.toLowerCase().contains('street') ||
        line.toLowerCase().contains('road') ||
        line.toLowerCase().contains('usa');
  }

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

  Future<List<Activity>> getRemainingActivities(
      String tripId,
      DateTime currentDateTime,
      ) async {
    try {
      final activities =
      await _itineraryRepository.fetchAllActivitiesByTrip(
        tripId,
      );

      activities.sort((a, b) {
        final aDateTime = _getActivityStartDateTime(a);
        final bDateTime = _getActivityStartDateTime(b);

        return aDateTime.compareTo(bDateTime);
      });

      return activities.where((activity) {
        final activityStart =
        _getActivityStartDateTime(activity);

        return activityStart.isAfter(currentDateTime);
      }).toList();
    } catch (e) {
      print('Calculating Remaining Activities Error: $e');
      rethrow;
    }
  }

  DateTime _getActivityStartDateTime(Activity activity) {
    final date = activity.date;

    final timeParts = activity.startTime?.split(':');

    final hour = int.parse(timeParts![0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  // zhiqin
  Future<ExpenseProcessingResult> processExpense({
    required String tripId,
    required String currentActivityId,
  }) async {
    debugPrint("process expense");

    // Get current trip
    final currentTrip = await _itineraryRepository.getTrip(tripId);

    // get remaining activities
    final activities = await getRemainingActivities(tripId, DateTime.now());

    // Get ALL confirmed expenses for this activity
    final expenses = await _expenseRepository.getExpensesByActivityId(
      currentActivityId,
    );

    // Calculate total spending for this activity
    double totalActivityExpense = 0.0;

    for (final expense in expenses) {
      totalActivityExpense += expense.totalAmount;
    }

    debugPrint('Total activity expense: RM$totalActivityExpense');

    double totalAllocatedBudget = 0.00;

    for (final activity in activities) {
      totalAllocatedBudget += activity.allocatedBudget;
    }

    final double remainingBudget = currentTrip.remainingBalance ?? 0.00;

    // Get current activity
    final currentActivity = await _itineraryRepository.getCurrentActivity(
      currentActivityId,
    );

    // Get current day
    final currentDay = await _itineraryRepository.getCurrentDay(
      currentActivity.dayTripId,
    );

    // Detect overspend
    final bool isOverspend = await detectOverspend(
      tripId,
      currentActivity,
      totalActivityExpense,
    );

    debugPrint("Is overspend: $isOverspend");

    if (!isOverspend) {
      return ExpenseProcessingResult.withinBudget;
    }

    // Calculate overspent amount
    final double overspentAmount =
        totalActivityExpense - currentActivity.allocatedBudget;

    debugPrint("Overspent amount: $overspentAmount");

    // Update current activity
    final updatedActivity = currentActivity.copyWith(
      overspendAmount: overspentAmount,
      isOverspend: true,
    );

    // Update current day
    final existingCategories =
        currentDay.overspendCategory
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
      overspendAmount: (currentDay.overspendAmount ?? 0.00) + overspentAmount,
      overspendCategory: existingCategories.join(', '),
      isOverspend: true,
    );

    // Save overspend details
    final success = await _itineraryRepository.updateOverspendDetails(
      updatedDay,
      updatedActivity,
    );

    debugPrint("Update overspend details success: $success");

    if (!success) {
      throw Exception('Update overspend details failed: $success');
    }

    // Check critical overspend
    final bool isCritical = await detectCriticalOverspend(
      totalAllocatedBudget,
      remainingBudget,
    );

    debugPrint("Is critical: $isCritical");

    if (isCritical) {
      final success = await _itineraryRepository.updateCriticalDetails(tripId);
      if (success) {
        return ExpenseProcessingResult.critical;
      }
      throw Exception('Update critical details failed: $success');
    }

    // Check overspend threshold
    final bool isAboveThreshold = await calculateOverspendPercentage(
      currentActivity,
      overspentAmount,
    );

    debugPrint("Is above threshold: $isAboveThreshold");

    // Above threshold - trigger recommendation
    if (isAboveThreshold) {
      return ExpenseProcessingResult.exceedsThresholdTriggerRecommendation;
    }

    // Within threshold - reallocate budget
    final updatedActivities = await reallocateBudget(
      tripId,
      currentActivity,
      overspentAmount,
    );

    if (updatedActivities.isEmpty) {
      return ExpenseProcessingResult.reallocatedFailed;
    }

    // Update reallocated activities
    final updateSuccessful = await _itineraryRepository.updateActivities(
      updatedActivities,
    );

    if (!updateSuccessful) {
      return ExpenseProcessingResult.reallocatedFailed;
    }

    // Reallocation successful
    return ExpenseProcessingResult.reallocatedSuccessfully;
  }

  // zhiqin
  Future<bool> detectOverspend(
    String tripId,
    Activity currentActivity,
    double expense,
  ) async {
    if (currentActivity.allocatedBudget < expense) {
      return true;
    }
    return false;
  }

  Future<bool> detectCriticalOverspend(
    double totalAllocatedBudget,
    double remainingBudget,
  ) async {
    if (remainingBudget <= totalAllocatedBudget * 0.2) {
      return true;
    }
    return false;
  }

  // zhiqin
  Future<List<Activity>> reallocateBudget(
    String tripId,
    Activity currentActivity,
    double overspentAmount,
  ) async {
    debugPrint("Reallocating budget...");

    final List<Activity> modifiedActivities = await _budgetService
        .reallocateBudget(tripId, currentActivity, overspentAmount);

    return modifiedActivities;
  }

  // zhiqin
  Future<bool> calculateOverspendPercentage(
    Activity currentActivity,
    double overspentAmount,
  ) async {
    final double allocatedBudget = currentActivity.allocatedBudget;

    double overspendThresholdPercentage;

    if (allocatedBudget <= 100.0) {
      overspendThresholdPercentage = 0.15;
    } else if (allocatedBudget <= 500.0) {
      overspendThresholdPercentage = 0.10;
    } else {
      overspendThresholdPercentage = 0.05;
    }

    final double allowedOverspendLimit =
        allocatedBudget * overspendThresholdPercentage;

    return overspentAmount > allowedOverspendLimit;
  }

  // zhiqin
  Future<double> getExceededAmount(
    String tripId,
    String currentActivityId,
  ) async {
    final activity = await _itineraryRepository.getCurrentActivity(currentActivityId);
    final expenses = await _expenseRepository.getExpensesByActivityId(
      currentActivityId,
    );
    double totalAmount = 0.0;
    for (final expense in expenses) {
      totalAmount += expense.totalAmount;
    }
    return totalAmount - activity.allocatedBudget;
  }
}
